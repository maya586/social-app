package handler

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/example/social-app/server/internal/model"
	"github.com/example/social-app/server/internal/monitor"
	"github.com/example/social-app/server/internal/repository"
	"github.com/example/social-app/server/internal/service"
	"github.com/example/social-app/server/pkg/response"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type AdminHandler struct {
	adminService  *service.AdminService
	adminRepo     *repository.AdminRepo
	userRepo      *repository.UserRepo
	systemMonitor *monitor.SystemMonitor
}

func NewAdminHandler(adminService *service.AdminService, adminRepo *repository.AdminRepo, userRepo *repository.UserRepo, systemMonitor *monitor.SystemMonitor) *AdminHandler {
	return &AdminHandler{
		adminService:  adminService,
		adminRepo:     adminRepo,
		userRepo:      userRepo,
		systemMonitor: systemMonitor,
	}
}

func (h *AdminHandler) Login(c *gin.Context) {
	var input service.AdminLoginInput
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Invalid request parameters")
		return
	}

	result, err := h.adminService.Login(&input)
	if err != nil {
		switch err {
		case service.ErrAdminNotFound, service.ErrInvalidAdminPassword:
			response.Error(c, 401, "AUTH_INVALID_CREDENTIALS", "Invalid username or password")
		default:
			response.InternalError(c, "Failed to login")
		}
		return
	}

	response.Success(c, result)
}

func (h *AdminHandler) Logout(c *gin.Context) {
	authHeader := c.GetHeader("Authorization")
	if authHeader == "" {
		response.Success(c, nil)
		return
	}

	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) != 2 || parts[0] != "Bearer" {
		response.Success(c, nil)
		return
	}

	if err := h.adminService.Logout(parts[1]); err != nil {
		response.InternalError(c, "Failed to logout")
		return
	}

	response.Success(c, nil)
}

func (h *AdminHandler) GetProfile(c *gin.Context) {
	adminID, exists := c.Get("admin_id")
	if !exists {
		response.Unauthorized(c, "Admin not found in context")
		return
	}

	uid, ok := adminID.(uuid.UUID)
	if !ok {
		response.InternalError(c, "Invalid admin ID type")
		return
	}

	admin, err := h.adminRepo.FindByID(uid)
	if err != nil {
		response.NotFound(c, "Admin not found")
		return
	}

	response.Success(c, admin)
}

func (h *AdminHandler) GetDashboard(c *gin.Context) {
	stats, err := h.adminService.GetDashboardStats()
	if err != nil {
		response.InternalError(c, "Failed to get dashboard stats")
		return
	}

	response.Success(c, stats)
}

func (h *AdminHandler) GetMonitor(c *gin.Context) {
	data := h.systemMonitor.GetMonitorData()
	response.Success(c, data)
}

func (h *AdminHandler) StreamMonitor(c *gin.Context) {
	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")
	c.Header("Access-Control-Allow-Origin", "*")

	flusher, ok := c.Writer.(http.Flusher)
	if !ok {
		response.InternalError(c, "Streaming unsupported")
		return
	}

	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-c.Request.Context().Done():
			return
		case <-ticker.C:
			data := h.systemMonitor.GetMonitorData()
			fmt.Fprintf(c.Writer, "data: {\"server\":{\"cpu_percent\":%.2f,\"memory_percent\":%.2f,\"disk_percent\":%.2f,\"network_in_bytes\":%d,\"network_out_bytes\":%d},\"api\":{\"requests_per_second\":%.2f,\"avg_response_time_ms\":%.2f,\"error_rate\":%.2f},\"realtime\":{\"websocket_connections\":%d,\"online_users\":%d,\"active_call_rooms\":%d}}\n\n",
				data.Server.CPUPercent,
				data.Server.MemoryPercent,
				data.Server.DiskPercent,
				data.Server.NetworkInBytes,
				data.Server.NetworkOutBytes,
				data.API.RequestsPerSecond,
				data.API.AvgResponseTimeMs,
				data.API.ErrorRate,
				data.Realtime.WebSocketConnections,
				data.Realtime.OnlineUsers,
				data.Realtime.ActiveCallRooms,
			)
			flusher.Flush()
		}
	}
}

func (h *AdminHandler) GetUsers(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	status := c.Query("status")
	keyword := c.Query("keyword")

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}

	filter := &repository.UserListFilter{
		Status:   status,
		Keyword:  keyword,
		Page:     page,
		PageSize: pageSize,
	}

	users, total, err := h.userRepo.ListUsers(filter)
	if err != nil {
		response.InternalError(c, "Failed to get users")
		return
	}

	response.Success(c, gin.H{
		"users":      users,
		"total":      total,
		"page":       page,
		"page_size":  pageSize,
		"total_page": (total + int64(pageSize) - 1) / int64(pageSize),
	})
}

func (h *AdminHandler) GetUser(c *gin.Context) {
	userIDStr := c.Param("id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		response.BadRequest(c, "Invalid user ID")
		return
	}

	user, err := h.userRepo.FindByID(userID)
	if err != nil {
		response.NotFound(c, "User not found")
		return
	}

	response.Success(c, user)
}

func (h *AdminHandler) UpdateUserStatus(c *gin.Context) {
	userIDStr := c.Param("id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		response.BadRequest(c, "Invalid user ID")
		return
	}

	var input struct {
		Status string `json:"status" binding:"required"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Invalid request parameters")
		return
	}

	status := model.UserStatus(input.Status)
	if status != model.UserStatusActive && status != model.UserStatusInactive && status != model.UserStatusBanned {
		response.BadRequest(c, "Invalid status value")
		return
	}

	if err := h.userRepo.UpdateStatus(userID, status); err != nil {
		response.InternalError(c, "Failed to update user status")
		return
	}

	response.Success(c, gin.H{"status": status})
}

func (h *AdminHandler) GetUserChats(c *gin.Context) {
	userIDStr := c.Param("id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		response.BadRequest(c, "Invalid user ID")
		return
	}

	_, err = h.userRepo.FindByID(userID)
	if err != nil {
		response.NotFound(c, "User not found")
		return
	}

	stats, err := h.adminRepo.GetUserChatStats(userIDStr)
	if err != nil {
		response.InternalError(c, "Failed to get user chat stats")
		return
	}

	conversations, err := h.adminRepo.GetUserConversations(userIDStr)
	if err != nil {
		response.InternalError(c, "Failed to get user conversations")
		return
	}

	response.Success(c, gin.H{
		"stats":         stats,
		"conversations": conversations,
	})
}

func (h *AdminHandler) GetConversationMessages(c *gin.Context) {
	conversationID := c.Param("id")
	_, err := uuid.Parse(conversationID)
	if err != nil {
		response.BadRequest(c, "Invalid conversation ID")
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "50"))

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 50
	}

	messages, total, err := h.adminRepo.GetConversationMessages(conversationID, page, pageSize)
	if err != nil {
		response.InternalError(c, "Failed to get messages")
		return
	}

	response.Success(c, gin.H{
		"messages":   messages,
		"total":      total,
		"page":       page,
		"page_size":  pageSize,
		"total_page": (total + int64(pageSize) - 1) / int64(pageSize),
	})
}

func (h *AdminHandler) GetConfigs(c *gin.Context) {
	configs, err := h.adminRepo.GetAllConfigs()
	if err != nil {
		response.InternalError(c, "Failed to get configs")
		return
	}

	response.Success(c, configs)
}

func (h *AdminHandler) UpdateConfig(c *gin.Context) {
	key := c.Param("key")
	if key == "" {
		response.BadRequest(c, "Config key is required")
		return
	}

	var input struct {
		Value string `json:"value" binding:"required"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Invalid request parameters")
		return
	}

	if err := h.adminRepo.SetConfig(key, input.Value); err != nil {
		response.InternalError(c, "Failed to update config")
		return
	}

	response.Success(c, gin.H{"key": key, "value": input.Value})
}
