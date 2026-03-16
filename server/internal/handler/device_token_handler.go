package handler

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/example/social-app/server/internal/middleware"
	"github.com/example/social-app/server/internal/model"
	"github.com/example/social-app/server/internal/repository"
	"github.com/example/social-app/server/pkg/response"
)

type DeviceTokenHandler struct {
	repo *repository.DeviceTokenRepo
}

func NewDeviceTokenHandler() *DeviceTokenHandler {
	return &DeviceTokenHandler{
		repo: repository.NewDeviceTokenRepo(),
	}
}

type RegisterDeviceTokenInput struct {
	Token    string             `json:"token" binding:"required"`
	Platform model.DevicePlatform `json:"platform" binding:"required"`
	DeviceID string             `json:"device_id"`
}

// RegisterDeviceToken godoc
// @Summary 注册设备令牌
// @Description 注册用户设备的推送通知令牌
// @Tags 推送通知
// @Security BearerAuth
// @Accept json
// @Produce json
// @Param request body RegisterDeviceTokenInput true "设备令牌信息"
// @Success 200 {object} map[string]interface{} "注册成功"
// @Failure 400 {object} map[string]string "参数错误"
// @Router /devices/token [post]
func (h *DeviceTokenHandler) RegisterDeviceToken(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	
	var input RegisterDeviceTokenInput
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Invalid request")
		return
	}
	
	existingToken, _ := h.repo.FindByToken(input.Token)
	if existingToken != nil && existingToken.ID != uuid.Nil {
		if existingToken.UserID != userID {
			response.Error(c, 403, "TOKEN_OWNED_BY_OTHER", "Token belongs to another user")
			return
		}
		existingToken.IsActive = true
		existingToken.Platform = input.Platform
		if err := h.repo.Update(existingToken); err != nil {
			response.InternalError(c, "Failed to update device token")
			return
		}
		response.Success(c, existingToken)
		return
	}
	
	deviceToken := &model.DeviceToken{
		UserID:   userID,
		Token:    input.Token,
		Platform: input.Platform,
		DeviceID: input.DeviceID,
		IsActive: true,
	}
	
	if err := h.repo.Create(deviceToken); err != nil {
		response.InternalError(c, "Failed to register device token")
		return
	}
	
	response.Created(c, deviceToken)
}

// UnregisterDeviceToken godoc
// @Summary 注销设备令牌
// @Description 注销用户设备的推送通知令牌
// @Tags 推送通知
// @Security BearerAuth
// @Produce json
// @Param token query string true "设备令牌"
// @Success 200 {object} map[string]interface{} "注销成功"
// @Failure 400 {object} map[string]string "参数错误"
// @Router /devices/token [delete]
func (h *DeviceTokenHandler) UnregisterDeviceToken(c *gin.Context) {
	token := c.Query("token")
	if token == "" {
		response.BadRequest(c, "Token is required")
		return
	}
	
	if err := h.repo.DeleteByToken(token); err != nil {
		response.InternalError(c, "Failed to unregister device token")
		return
	}
	
	response.Success(c, nil)
}