# Admin Dashboard 实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 开发服务端监控管理应用，包含管理员登录、仪表盘、用户管理、系统监控、系统设置功能

**Architecture:** 服务端扩展Go API提供管理接口，Flutter客户端实现Windows桌面应用，使用Apple风格玻璃拟态UI

**Tech Stack:** Go + Gin (服务端), Flutter (客户端), PostgreSQL, Redis, fl_chart, flutter_riverpod

---

## 文件结构

### 服务端新增文件
```
server/
├── internal/
│   ├── model/
│   │   └── admin.go              # Admin模型
│   ├── repository/
│   │   └── admin_repo.go         # Admin数据访问
│   ├── service/
│   │   └── admin_service.go      # 管理员业务逻辑
│   ├── handler/
│   │   └── admin_handler.go      # 管理API处理器
│   └── monitor/
│       └── system_monitor.go     # 系统监控服务
```

### 客户端新增文件
```
admin-app/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── theme/admin_theme.dart
│   │   ├── network/admin_api_client.dart
│   │   ├── storage/admin_token_storage.dart
│   │   └── state/admin_auth_provider.dart
│   ├── features/
│   │   ├── auth/
│   │   ├── dashboard/
│   │   ├── users/
│   │   ├── monitor/
│   │   └── settings/
│   └── shared/widgets/
└── pubspec.yaml
```

---

## Chunk 1: 服务端 - 数据库模型和迁移

### Task 1: 创建Admin模型

**Files:**
- Create: `server/internal/model/admin.go`

- [ ] **Step 1: 创建Admin模型**

```go
package model

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Admin struct {
	ID           uuid.UUID  `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	Username     string     `gorm:"uniqueIndex;size:50;not null" json:"username"`
	PasswordHash string     `gorm:"size:255;not null" json:"-"`
	Nickname     string     `gorm:"size:50" json:"nickname"`
	Role         string     `gorm:"size:20;default:'admin'" json:"role"`
	LastLoginAt  *time.Time `json:"last_login_at"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
}

func (a *Admin) BeforeCreate(tx *gorm.DB) error {
	if a.ID == uuid.Nil {
		a.ID = uuid.New()
	}
	return nil
}
```

- [ ] **Step 2: 创建SystemConfig模型**

在 `server/internal/model/admin.go` 添加:

```go
type SystemConfig struct {
	Key         string     `gorm:"primaryKey;size:100" json:"key"`
	Value       string     `gorm:"type:text;not null" json:"value"`
	Description string     `gorm:"size:255" json:"description"`
	UpdatedAt   time.Time  `json:"updated_at"`
}
```

- [ ] **Step 3: 更新数据库迁移**

修改 `server/internal/database/database.go`，在Migrate函数中添加:

```go
if err := db.AutoMigrate(&model.Admin{}, &model.SystemConfig{}); err != nil {
    return err
}
```

- [ ] **Step 4: 创建种子数据脚本**

创建 `server/scripts/seed_admin.go`:

```go
package main

import (
	"log"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"os"
)

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "host=localhost user=postgres password=postgres dbname=social_app port=5432 sslmode=disable"
	}

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	password := "admin123"
	if len(os.Args) > 1 {
		password = os.Args[1]
	}

	hashedPassword, _ := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)

	result := db.Exec(`
		INSERT INTO admins (id, username, password_hash, nickname, role, created_at, updated_at)
		VALUES (gen_random_uuid(), 'admin', ?, 'Administrator', 'admin', NOW(), NOW())
		ON CONFLICT (username) DO NOTHING
	`, string(hashedPassword))

	if result.Error != nil {
		log.Println("Seed error:", result.Error)
	} else {
		log.Println("Admin user created/exists. Username: admin, Password:", password)
	}

	result = db.Exec(`
		INSERT INTO system_configs (key, value, description, updated_at)
		VALUES ('allow_registration', 'true', '是否允许新用户注册', NOW())
		ON CONFLICT (key) DO NOTHING
	`)

	if result.Error != nil {
		log.Println("Config seed error:", result.Error)
	} else {
		log.Println("System configs seeded")
	}
}
```

- [ ] **Step 5: 提交**

```bash
git add server/internal/model/admin.go server/internal/database/database.go server/scripts/seed_admin.go
git commit -m "feat(server): add Admin and SystemConfig models with seed script"
```

---

### Task 2: 创建Admin Repository

**Files:**
- Create: `server/internal/repository/admin_repo.go`

- [ ] **Step 1: 创建AdminRepo**

```go
package repository

import (
	"time"

	"github.com/example/social-app/server/internal/database"
	"github.com/example/social-app/server/internal/model"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type AdminRepo struct {
	db *gorm.DB
}

func NewAdminRepo() *AdminRepo {
	return &AdminRepo{
		db: database.DB,
	}
}

func (r *AdminRepo) FindByUsername(username string) (*model.Admin, error) {
	var admin model.Admin
	err := r.db.Where("username = ?", username).First(&admin).Error
	if err != nil {
		return nil, err
	}
	return &admin, nil
}

func (r *AdminRepo) FindByID(id uuid.UUID) (*model.Admin, error) {
	var admin model.Admin
	err := r.db.First(&admin, id).Error
	if err != nil {
		return nil, err
	}
	return &admin, nil
}

func (r *AdminRepo) UpdateLastLogin(id uuid.UUID) error {
	return r.db.Model(&model.Admin{}).Where("id = ?", id).Update("last_login_at", gorm.Expr("NOW()")).Error
}

func (r *AdminRepo) GetConfig(key string) (*model.SystemConfig, error) {
	var config model.SystemConfig
	err := r.db.First(&config, key).Error
	if err != nil {
		return nil, err
	}
	return &config, nil
}

func (r *AdminRepo) SetConfig(key, value string) error {
	return r.db.Model(&model.SystemConfig{}).Where("key = ?", key).Update("value", value).Error
}

func (r *AdminRepo) GetAllConfigs() ([]model.SystemConfig, error) {
	var configs []model.SystemConfig
	err := r.db.Find(&configs).Error
	return configs, err
}
```

- [ ] **Step 2: 添加用户统计查询方法**

```go
func (r *AdminRepo) GetUserStats() (totalUsers int64, todayNewUsers int64, onlineUsers int64, err error) {
	err = r.db.Model(&model.User{}).Count(&totalUsers).Error
	if err != nil {
		return
	}

	err = r.db.Model(&model.User{}).Where("created_at >= CURRENT_DATE").Count(&todayNewUsers).Error
	if err != nil {
		return
	}

	return totalUsers, todayNewUsers, 0, nil
}

func (r *AdminRepo) GetMessageStats() (totalMessages int64, todayMessages int64, err error) {
	err = r.db.Model(&model.Message{}).Count(&totalMessages).Error
	if err != nil {
		return
	}

	err = r.db.Model(&model.Message{}).Where("created_at >= CURRENT_DATE").Count(&todayMessages).Error
	return totalMessages, todayMessages, err
}

func (r *AdminRepo) GetUserTrend(days int) ([]int64, error) {
	var trends []int64
	for i := days - 1; i >= 0; i-- {
		var count int64
		date := time.Now().AddDate(0, 0, -i).Format("2006-01-02")
		err := r.db.Model(&model.User{}).
			Where("DATE(created_at) = ?", date).
			Count(&count).Error
		if err != nil {
			return nil, err
		}
		trends = append(trends, count)
	}
	return trends, nil
}

func (r *AdminRepo) GetMessageTrend(days int) ([]int64, error) {
	var trends []int64
	for i := days - 1; i >= 0; i-- {
		var count int64
		date := time.Now().AddDate(0, 0, -i).Format("2006-01-02")
		err := r.db.Model(&model.Message{}).
			Where("DATE(created_at) = ?", date).
			Count(&count).Error
		if err != nil {
			return nil, err
		}
		trends = append(trends, count)
	}
	return trends, nil
}

func (r *AdminRepo) GetUserChatStats(userID string) (map[string]interface{}, error) {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, err
	}

	stats := make(map[string]interface{})

	var sentCount int64
	r.db.Model(&model.Message{}).Where("sender_id = ?", uid).Count(&sentCount)
	stats["sent_messages"] = sentCount

	var receivedCount int64
	r.db.Model(&model.Message{}).
		Joins("JOIN conversation_members cm ON messages.conversation_id = cm.conversation_id").
		Where("cm.user_id = ? AND messages.sender_id != ?", uid, uid).
		Count(&receivedCount)
	stats["received_messages"] = receivedCount

	var convCount int64
	r.db.Model(&model.ConversationMember{}).Where("user_id = ?", uid).Count(&convCount)
	stats["conversations"] = convCount

	var friendCount int64
	r.db.Model(&model.Contact{}).Where("user_id = ? AND status = ?", uid, "accepted").Count(&friendCount)
	stats["friends"] = friendCount

	typeDist := make(map[string]int64)
	var textCount, imageCount, voiceCount, fileCount int64
	r.db.Model(&model.Message{}).Where("sender_id = ? AND type = ?", uid, "text").Count(&textCount)
	r.db.Model(&model.Message{}).Where("sender_id = ? AND type = ?", uid, "image").Count(&imageCount)
	r.db.Model(&model.Message{}).Where("sender_id = ? AND type = ?", uid, "voice").Count(&voiceCount)
	r.db.Model(&model.Message{}).Where("sender_id = ? AND type = ?", uid, "file").Count(&fileCount)
	typeDist["text"] = textCount
	typeDist["image"] = imageCount
	typeDist["voice"] = voiceCount
	typeDist["file"] = fileCount
	stats["type_distribution"] = typeDist

	return stats, nil
}

func (r *AdminRepo) GetUserConversations(userID string) ([]map[string]interface{}, error) {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, err
	}

	var members []model.ConversationMember
	r.db.Where("user_id = ?", uid).Find(&members)

	var result []map[string]interface{}
	for _, member := range members {
		var msgCount int64
		r.db.Model(&model.Message{}).Where("conversation_id = ?", member.ConversationID).Count(&msgCount)

		var lastMsg model.Message
		r.db.Where("conversation_id = ?", member.ConversationID).Order("created_at desc").First(&lastMsg)

		result = append(result, map[string]interface{}{
			"id":            member.ConversationID,
			"type":          "private",
			"message_count": msgCount,
			"last_message":  lastMsg.Content,
		})
	}

	return result, nil
}

func (r *AdminRepo) GetConversationMessages(conversationID string, page, pageSize int) ([]model.Message, int64, error) {
	var messages []model.Message
	var total int64

	cid, err := uuid.Parse(conversationID)
	if err != nil {
		return nil, 0, err
	}

	r.db.Model(&model.Message{}).Where("conversation_id = ?", cid).Count(&total)

	offset := (page - 1) * pageSize
	err = r.db.Where("conversation_id = ?", cid).
		Order("created_at desc").
		Offset(offset).Limit(pageSize).
		Find(&messages).Error

	return messages, total, err
}
```

- [ ] **Step 3: 提交**

```bash
git add server/internal/repository/admin_repo.go
git commit -m "feat(server): add AdminRepo with user stats queries"
```

---

### Task 3: 创建Admin Service

**Files:**
- Create: `server/internal/service/admin_service.go`

- [ ] **Step 1: 创建AdminService结构体**

```go
package service

import (
	"errors"
	"time"

	"github.com/example/social-app/server/internal/cache"
	"github.com/example/social-app/server/internal/model"
	"github.com/example/social-app/server/internal/repository"
	"github.com/example/social-app/server/pkg/jwt"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrAdminNotFound     = errors.New("admin not found")
	ErrInvalidPassword   = errors.New("invalid password")
	ErrAdminTokenInvalid = errors.New("invalid admin token")
)

type AdminService struct {
	adminRepo  *repository.AdminRepo
	userRepo   *repository.UserRepo
	jwtSecret  string
	tokenExp   int
}

func NewAdminService(adminRepo *repository.AdminRepo, userRepo *repository.UserRepo, jwtSecret string, tokenExp int) *AdminService {
	return &AdminService{
		adminRepo: adminRepo,
		userRepo:  userRepo,
		jwtSecret: jwtSecret,
		tokenExp:  tokenExp,
	}
}

type AdminLoginInput struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type AdminAuthResponse struct {
	AccessToken  string       `json:"access_token"`
	RefreshToken string       `json:"refresh_token"`
	ExpiresIn    int          `json:"expires_in"`
	Admin        *model.Admin `json:"admin"`
}
```

- [ ] **Step 2: 实现登录逻辑**

```go
func (s *AdminService) Login(input *AdminLoginInput) (*AdminAuthResponse, error) {
	admin, err := s.adminRepo.FindByUsername(input.Username)
	if err != nil {
		return nil, ErrAdminNotFound
	}

	if err := bcrypt.CompareHashAndPassword([]byte(admin.PasswordHash), []byte(input.Password)); err != nil {
		return nil, ErrInvalidPassword
	}

	_ = s.adminRepo.UpdateLastLogin(admin.ID)

	return s.generateTokens(admin)
}

func (s *AdminService) generateTokens(admin *model.Admin) (*AdminAuthResponse, error) {
	accessToken, err := jwt.GenerateToken(admin.ID, admin.Username, s.jwtSecret, time.Duration(s.tokenExp)*time.Second)
	if err != nil {
		return nil, err
	}

	refreshToken, err := jwt.GenerateToken(admin.ID, admin.Username, s.jwtSecret, time.Duration(s.tokenExp*7)*time.Second)
	if err != nil {
		return nil, err
	}

	return &AdminAuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    s.tokenExp,
		Admin:        admin,
	}, nil
}

func (s *AdminService) ValidateToken(tokenString string) (*jwt.Claims, error) {
	claims, err := jwt.ParseToken(tokenString, s.jwtSecret)
	if err != nil {
		return nil, err
	}

	adminID, err := uuid.Parse(claims.UserID.String())
	if err != nil {
		return nil, ErrAdminTokenInvalid
	}

	_, err = s.adminRepo.FindByID(adminID)
	if err != nil {
		return nil, ErrAdminTokenInvalid
	}

	return claims, nil
}

func (s *AdminService) Logout(tokenString string) error {
	return cache.RDB.Set(nil, "admin_blacklist:"+tokenString, "1", time.Duration(s.tokenExp)*time.Second).Err()
}
```

- [ ] **Step 3: 实现仪表盘服务**

```go
type DashboardStats struct {
	TotalUsers        int64   `json:"total_users"`
	TodayNewUsers     int64   `json:"today_new_users"`
	OnlineUsers       int64   `json:"online_users"`
	TotalMessages     int64   `json:"total_messages"`
	TodayMessages     int64   `json:"today_messages"`
	ActiveConversations int64 `json:"active_conversations"`
	UserTrend         []int64 `json:"user_trend"`
	MessageTrend      []int64 `json:"message_trend"`
}

func (s *AdminService) GetDashboardStats() (*DashboardStats, error) {
	stats := &DashboardStats{}

	var err error
	stats.TotalUsers, stats.TodayNewUsers, stats.OnlineUsers, err = s.adminRepo.GetUserStats()
	if err != nil {
		return nil, err
	}

	stats.TotalMessages, stats.TodayMessages, err = s.adminRepo.GetMessageStats()
	if err != nil {
		return nil, err
	}

	stats.UserTrend, err = s.adminRepo.GetUserTrend(7)
	if err != nil {
		stats.UserTrend = make([]int64, 7)
	}

	stats.MessageTrend, err = s.adminRepo.GetMessageTrend(7)
	if err != nil {
		stats.MessageTrend = make([]int64, 7)
	}

	stats.ActiveConversations = stats.OnlineUsers / 2

	return stats, nil
}
```

- [ ] **Step 4: 提交**

```bash
git add server/internal/service/admin_service.go
git commit -m "feat(server): add AdminService with login and dashboard stats"
```

---

## Chunk 2: 服务端 - 系统监控

### Task 4: 创建系统监控服务

**Files:**
- Create: `server/internal/monitor/system_monitor.go`

- [ ] **Step 1: 安装gopsutil依赖**

```bash
cd server && go get github.com/shirou/gopsutil/v3/cpu github.com/shirou/gopsutil/v3/mem github.com/shirou/gopsutil/v3/disk github.com/shirou/gopsutil/v3/net
```

- [ ] **Step 2: 创建监控结构体**

```go
package monitor

import (
	"runtime"
	"time"

	"github.com/example/social-app/server/internal/websocket"
	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/shirou/gopsutil/v3/net"
)

type ServerStats struct {
	CPUPercent     float64 `json:"cpu_percent"`
	MemoryPercent  float64 `json:"memory_percent"`
	DiskPercent    float64 `json:"disk_percent"`
	NetworkInBytes uint64  `json:"network_in_bytes"`
	NetworkOutBytes uint64 `json:"network_out_bytes"`
}

type APIStats struct {
	RequestsPerSecond  float64 `json:"requests_per_second"`
	AvgResponseTimeMs  float64 `json:"avg_response_time_ms"`
	ErrorRate          float64 `json:"error_rate"`
}

type RealtimeStats struct {
	WebSocketConnections int `json:"websocket_connections"`
	OnlineUsers          int `json:"online_users"`
	ActiveCallRooms      int `json:"active_call_rooms"`
}

type MonitorData struct {
	Server   ServerStats   `json:"server"`
	API      APIStats      `json:"api"`
	Realtime RealtimeStats `json:"realtime"`
}

type SystemMonitor struct {
	hub              *websocket.Hub
	lastNetIO        net.IOCountersStat
	lastNetIOTime    time.Time
	requestCount     int64
	errorCount       int64
	totalResponseMs  int64
}

func NewSystemMonitor(hub *websocket.Hub) *SystemMonitor {
	return &SystemMonitor{hub: hub}
}
```

- [ ] **Step 3: 实现监控方法**

```go
func (m *SystemMonitor) GetMonitorData() *MonitorData {
	data := &MonitorData{}

	data.Server = m.getServerStats()
	data.API = m.getAPIStats()
	data.Realtime = m.getRealtimeStats()

	return data
}

func (m *SystemMonitor) getServerStats() ServerStats {
	stats := ServerStats{}

	if percent, err := cpu.Percent(time.Second, false); err == nil && len(percent) > 0 {
		stats.CPUPercent = percent[0]
	}

	if vm, err := mem.VirtualMemory(); err == nil {
		stats.MemoryPercent = vm.UsedPercent
	}

	if usage, err := disk.Usage("/"); err == nil {
		stats.DiskPercent = usage.UsedPercent
	}
	if runtime.GOOS == "windows" {
		if usage, err := disk.Usage("C:"); err == nil {
			stats.DiskPercent = usage.UsedPercent
		}
	}

	if netIO, err := net.IOCounters(false); err == nil && len(netIO) > 0 {
		now := time.Now()
		stats.NetworkInBytes = netIO[0].BytesRecv
		stats.NetworkOutBytes = netIO[0].BytesSent
		m.lastNetIO = netIO[0]
		m.lastNetIOTime = now
	}

	return stats
}

func (m *SystemMonitor) getAPIStats() APIStats {
	stats := APIStats{}

	if m.requestCount > 0 {
		stats.RequestsPerSecond = float64(m.requestCount) / 60.0
		stats.AvgResponseTimeMs = float64(m.totalResponseMs) / float64(m.requestCount)
		stats.ErrorRate = float64(m.errorCount) / float64(m.requestCount)
	}

	return stats
}

func (m *SystemMonitor) getRealtimeStats() RealtimeStats {
	stats := RealtimeStats{}

	if m.hub != nil {
		stats.WebSocketConnections = m.hub.GetConnectionCount()
		stats.OnlineUsers = m.hub.GetOnlineUserCount()
		stats.ActiveCallRooms = m.hub.GetActiveRoomCount()
	}

	return stats
}

func (m *SystemMonitor) RecordRequest(responseMs int64, isError bool) {
	m.requestCount++
	m.totalResponseMs += responseMs
	if isError {
		m.errorCount++
	}
}

func (m *SystemMonitor) ResetCounters() {
	m.requestCount = 0
	m.errorCount = 0
	m.totalResponseMs = 0
}
```

- [ ] **Step 4: 在Hub中添加计数方法**

修改 `server/internal/websocket/hub.go`:

```go
func (h *Hub) GetConnectionCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

func (h *Hub) GetOnlineUserCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.userClients)
}

func (h *Hub) GetActiveRoomCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.rooms)
}
```

- [ ] **Step 5: 提交**

```bash
git add server/internal/monitor/system_monitor.go server/internal/websocket/hub.go
git commit -m "feat(server): add SystemMonitor for CPU/memory/disk/network stats"
```

---

## Chunk 3: 服务端 - API处理器

### Task 5: 创建Admin Handler

**Files:**
- Create: `server/internal/handler/admin_handler.go`

- [ ] **Step 1: 创建Handler结构体和登录方法**

```go
package handler

import (
	"strings"
	"time"

	"github.com/example/social-app/server/internal/monitor"
	"github.com/example/social-app/server/internal/repository"
	"github.com/example/social-app/server/internal/service"
	"github.com/example/social-app/server/pkg/response"
	"github.com/gin-gonic/gin"
)

type AdminHandler struct {
	adminService   *service.AdminService
	adminRepo      *repository.AdminRepo
	userRepo       *repository.UserRepo
	systemMonitor  *monitor.SystemMonitor
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
		case service.ErrAdminNotFound, service.ErrInvalidPassword:
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
	if len(parts) == 2 && parts[0] == "Bearer" {
		_ = h.adminService.Logout(parts[1])
	}

	response.Success(c, nil)
}

func (h *AdminHandler) GetProfile(c *gin.Context) {
	adminID, exists := c.Get("admin_id")
	if !exists {
		response.Unauthorized(c, "Unauthorized")
		return
	}

	uid, ok := adminID.(uuid.UUID)
	if !ok {
		response.Unauthorized(c, "Invalid admin ID")
		return
	}

	admin, err := h.adminRepo.FindByID(uid)
	if err != nil {
		response.Error(c, 404, "ADMIN_NOT_FOUND", "Admin not found")
		return
	}

	response.Success(c, admin)
}
```

- [ ] **Step 2: 实现仪表盘API**

```go
func (h *AdminHandler) GetDashboard(c *gin.Context) {
	stats, err := h.adminService.GetDashboardStats()
	if err != nil {
		response.InternalError(c, "Failed to get dashboard stats")
		return
	}

	response.Success(c, stats)
}
```

- [ ] **Step 3: 实现监控API**

```go
func (h *AdminHandler) GetMonitor(c *gin.Context) {
	data := h.systemMonitor.GetMonitorData()
	response.Success(c, data)
}

func (h *AdminHandler) StreamMonitor(c *gin.Context) {
	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")

	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-c.Done():
			return
		case <-ticker.C:
			data := h.systemMonitor.GetMonitorData()
			c.SSEvent("monitor", data)
			c.Writer.Flush()
		}
	}
}
```

- [ ] **Step 4: 实现用户管理API**

```go
type UserListQuery struct {
	Page      int    `form:"page" binding:"min=1"`
	PageSize  int    `form:"page_size" binding:"min=1,max=100"`
	Keyword   string `form:"keyword"`
	Status    string `form:"status"`
	SortBy    string `form:"sort_by"`
	SortOrder string `form:"sort_order"`
}

func (h *AdminHandler) GetUsers(c *gin.Context) {
	var query UserListQuery
	if err := c.ShouldBindQuery(&query); err != nil {
		query.Page = 1
		query.PageSize = 20
	}

	users, total, err := h.userRepo.ListUsers(query.Page, query.PageSize, query.Keyword, query.Status, query.SortBy, query.SortOrder)
	if err != nil {
		response.InternalError(c, "Failed to get users")
		return
	}

	response.Success(c, gin.H{
		"users":     users,
		"total":     total,
		"page":      query.Page,
		"page_size": query.PageSize,
	})
}

func (h *AdminHandler) GetUser(c *gin.Context) {
	userID := c.Param("id")
	user, err := h.userRepo.FindByIDParsed(userID)
	if err != nil {
		response.Error(c, 404, "USER_NOT_FOUND", "User not found")
		return
	}

	response.Success(c, user)
}

func (h *AdminHandler) UpdateUserStatus(c *gin.Context) {
	userID := c.Param("id")
	var input struct {
		Status string `json:"status" binding:"required,oneof=active banned"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Invalid status")
		return
	}

	if err := h.userRepo.UpdateStatus(userID, input.Status); err != nil {
		response.InternalError(c, "Failed to update user status")
		return
	}

	response.Success(c, gin.H{"status": input.Status})
}

func (h *AdminHandler) GetUserChats(c *gin.Context) {
	userID := c.Param("id")

	stats, err := h.adminRepo.GetUserChatStats(userID)
	if err != nil {
		response.InternalError(c, "Failed to get user chat stats")
		return
	}

	conversations, err := h.adminRepo.GetUserConversations(userID)
	if err != nil {
		conversations = []interface{}{}
	}

	response.Success(c, gin.H{
		"user":                     gin.H{"id": userID},
		"stats":                    stats,
		"message_type_distribution": stats["type_distribution"],
		"conversations":            conversations,
	})
}

func (h *AdminHandler) GetConversationMessages(c *gin.Context) {
	conversationID := c.Param("id")
	page := 1
	pageSize := 50

	messages, total, err := h.adminRepo.GetConversationMessages(conversationID, page, pageSize)
	if err != nil {
		response.InternalError(c, "Failed to get messages")
		return
	}

	response.Success(c, gin.H{
		"messages":  messages,
		"total":     total,
		"page":      page,
		"page_size": pageSize,
	})
}
```

- [ ] **Step 5: 实现系统配置API**

```go
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
	var input struct {
		Value string `json:"value" binding:"required"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Value required")
		return
	}

	if err := h.adminRepo.SetConfig(key, input.Value); err != nil {
		response.InternalError(c, "Failed to update config")
		return
	}

	if key == "allow_registration" {
	}

	response.Success(c, gin.H{"key": key, "value": input.Value})
}
```

- [ ] **Step 6: 提交**

```bash
git add server/internal/handler/admin_handler.go
git commit -m "feat(server): add AdminHandler with all admin APIs"
```

---

### Task 6: 更新路由和主函数

**Files:**
- Modify: `server/internal/router/router.go`
- Modify: `server/cmd/server/main.go`

- [ ] **Step 1: 添加Admin路由**

在 `server/internal/router/router.go` 的 Setup 函数中添加:

```go
func Setup(r *gin.Engine, authService *service.AuthService, authHandler *handler.AuthHandler,
	contactHandler *handler.ContactHandler, messageHandler *handler.MessageHandler,
	fileHandler *handler.FileHandler, callHandler *handler.CallHandler,
	userHandler *handler.UserHandler, wsHandler *handler.WSHandler,
	adminHandler *handler.AdminHandler, adminService *service.AdminService) {

	r.Use(middleware.CORS())

	api := r.Group("/api/v1")
	{
		auth := api.Group("/auth")
		auth.Use(middleware.RateLimit(10, time.Minute))
		{
			auth.POST("/register", authHandler.Register)
			auth.POST("/login", authHandler.Login)
			auth.POST("/logout", middleware.AuthMiddleware(authService), authHandler.Logout)
			auth.POST("/refresh-token", authHandler.RefreshToken)
		}

		files := api.Group("/files")
		{
			files.GET("/*id", fileHandler.Download)
		}

		admin := api.Group("/admin")
		{
			admin.POST("/login", adminHandler.Login)
		}

		adminProtected := api.Group("/admin")
		adminProtected.Use(middleware.AdminAuthMiddleware(adminService))
		{
			adminProtected.POST("/logout", adminHandler.Logout)
			adminProtected.GET("/profile", adminHandler.GetProfile)
			adminProtected.GET("/dashboard", adminHandler.GetDashboard)
			adminProtected.GET("/monitor", adminHandler.GetMonitor)
			adminProtected.GET("/monitor/stream", adminHandler.StreamMonitor)
			adminProtected.GET("/users", adminHandler.GetUsers)
			adminProtected.GET("/users/:id", adminHandler.GetUser)
			adminProtected.PUT("/users/:id/status", adminHandler.UpdateUserStatus)
			adminProtected.GET("/users/:id/chats", adminHandler.GetUserChats)
			adminProtected.GET("/conversations/:id/messages", adminHandler.GetConversationMessages)
			adminProtected.GET("/configs", adminHandler.GetConfigs)
			adminProtected.PUT("/configs/:key", adminHandler.UpdateConfig)
		}

		protected := api.Group("")
		protected.Use(middleware.AuthMiddleware(authService))
		protected.Use(middleware.UserRateLimit(300, time.Minute))
		{
			// ... existing protected routes ...
		}
	}

	r.GET("/ws", wsHandler.HandleWebSocket)
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})
	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))
}
```

- [ ] **Step 2: 创建Admin认证中间件**

创建 `server/internal/middleware/admin_auth.go`:

```go
package middleware

import (
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/example/social-app/server/internal/service"
	"github.com/example/social-app/server/pkg/response"
)

func AdminAuthMiddleware(adminService *service.AdminService) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			response.Unauthorized(c, "Authorization header required")
			c.Abort()
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" {
			response.Unauthorized(c, "Invalid authorization header")
			c.Abort()
			return
		}

		claims, err := adminService.ValidateToken(parts[1])
		if err != nil {
			response.Unauthorized(c, "Invalid or expired token")
			c.Abort()
			return
		}

		c.Set("admin_id", claims.UserID)
		c.Set("admin_username", claims.Phone)
		c.Next()
	}
}
```

- [ ] **Step 3: 更新main.go**

修改 `server/cmd/server/main.go`:

```go
package main

import (
	"log"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"

	_ "github.com/example/social-app/server/docs"
	"github.com/example/social-app/server/internal/cache"
	"github.com/example/social-app/server/internal/config"
	"github.com/example/social-app/server/internal/database"
	"github.com/example/social-app/server/internal/handler"
	"github.com/example/social-app/server/internal/monitor"
	"github.com/example/social-app/server/internal/repository"
	"github.com/example/social-app/server/internal/router"
	"github.com/example/social-app/server/internal/service"
	"github.com/example/social-app/server/internal/storage"
	"github.com/example/social-app/server/internal/webrtc"
	"github.com/example/social-app/server/internal/websocket"
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	cfg := config.Load()

	if err := database.Connect(&cfg.Database); err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	if err := database.Migrate(); err != nil {
		log.Fatal("Failed to migrate database:", err)
	}

	if err := cache.Connect(&cfg.Redis); err != nil {
		log.Fatal("Failed to connect to redis:", err)
	}

	if err := storage.InitMinio(&cfg.Minio); err != nil {
		log.Println("Warning: Failed to connect to MinIO:", err)
	}

	_ = webrtc.GetSFU()

	userRepo := repository.NewUserRepo()
	contactRepo := repository.NewContactRepo()
	conversationRepo := repository.NewConversationRepo()
	messageRepo := repository.NewMessageRepo()
	adminRepo := repository.NewAdminRepo()

	authService := service.NewAuthService(userRepo, cfg.JWT.Secret, int(cfg.JWT.ExpireTime.Seconds()))
	contactService := service.NewContactService(contactRepo, userRepo)
	messageService := service.NewMessageService(messageRepo, conversationRepo)
	adminService := service.NewAdminService(adminRepo, userRepo, cfg.JWT.Secret, int(cfg.JWT.ExpireTime.Seconds()))

	hub := websocket.NewHub()
	go hub.Run()

	systemMonitor := monitor.NewSystemMonitor(hub)

	authHandler := handler.NewAuthHandler(authService)
	contactHandler := handler.NewContactHandler(contactService)
	messageHandler := handler.NewMessageHandler(messageService)
	fileHandler := handler.NewFileHandler()
	callHandler := handler.NewCallHandler(hub)
	userHandler := handler.NewUserHandler(userRepo)
	wsHandler := handler.NewWSHandler(hub)
	adminHandler := handler.NewAdminHandler(adminService, adminRepo, userRepo, systemMonitor)

	messageHandler.SetHub(hub)

	r := gin.Default()
	router.Setup(r, authService, authHandler, contactHandler, messageHandler, fileHandler, callHandler, userHandler, wsHandler, adminHandler, adminService)

	log.Printf("Server starting on port %s", cfg.Server.Port)
	if err := r.Run(":" + cfg.Server.Port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
```

- [ ] **Step 4: 提交**

```bash
git add server/internal/router/router.go server/internal/middleware/admin_auth.go server/cmd/server/main.go
git commit -m "feat(server): integrate admin routes and update main.go"
```

---

## Chunk 4: 客户端 - 项目初始化

### Task 7: 创建Flutter项目

**Files:**
- Create: `admin-app/` 目录结构

- [ ] **Step 1: 创建Flutter项目**

```bash
cd C:/temp/social-app
flutter create --org com.socialapp --project-name admin_app admin-app
cd admin-app
```

- [ ] **Step 2: 更新pubspec.yaml**

```yaml
name: admin_app
description: Social App Admin Dashboard

publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3
  dio: ^5.4.0
  shared_preferences: ^2.2.2
  fl_chart: ^0.66.0
  intl: ^0.19.0
  uuid: ^4.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  riverpod_generator: ^2.3.9
  build_runner: ^2.4.8

flutter:
  uses-material-design: true
```

- [ ] **Step 3: 获取依赖**

```bash
flutter pub get
```

- [ ] **Step 4: 提交**

```bash
git add admin-app/
git commit -m "feat(client): initialize Flutter admin app project"
```

---

### Task 8: 创建主题和共享组件

**Files:**
- Create: `admin-app/lib/core/theme/admin_theme.dart`
- Create: `admin-app/lib/shared/widgets/glass_container.dart`
- Create: `admin-app/lib/shared/widgets/stat_card.dart`

- [ ] **Step 1: 创建主题文件**

```dart
// lib/core/theme/admin_theme.dart
import 'package:flutter/material.dart';

class AdminTheme {
  static const Color primaryColor = Color(0xFF6366F1);
  static const Color secondaryColor = Color(0xFF8B5CF6);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color backgroundColor = Color(0xFF0F172A);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color cardColor = Color(0xFF334155);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0F172A)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
      ),
      cardTheme: CardTheme(
        color: cardColor.withOpacity(0.5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 创建GlassContainer组件**

```dart
// lib/shared/widgets/glass_container.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/admin_theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final double opacity;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.blur = 10,
    this.opacity = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 创建StatCard组件**

```dart
// lib/shared/widgets/stat_card.dart
import 'package:flutter/material.dart';
import '../../core/theme/admin_theme.dart';
import 'glass_container.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (color ?? AdminTheme.primaryColor).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color ?? AdminTheme.primaryColor,
                  size: 24,
                ),
              ),
              const Spacer(),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 提交**

```bash
git add admin-app/lib/core/theme/ admin-app/lib/shared/widgets/
git commit -m "feat(client): add theme and shared widgets"
```

---

## Chunk 5: 客户端 - 认证和API

### Task 9: 创建API客户端和认证

**Files:**
- Create: `admin-app/lib/core/network/admin_api_client.dart`
- Create: `admin-app/lib/core/storage/admin_token_storage.dart`
- Create: `admin-app/lib/core/state/admin_auth_provider.dart`
- Create: `admin-app/lib/features/auth/data/admin_auth_repository.dart`
- Create: `admin-app/lib/features/auth/presentation/login_page.dart`

- [ ] **Step 1: 创建Token存储**

```dart
// lib/core/storage/admin_token_storage.dart
import 'package:shared_preferences/shared_preferences.dart';

class AdminTokenStorage {
  static const _accessTokenKey = 'admin_access_token';
  static const _refreshTokenKey = 'admin_refresh_token';
  static const _adminIdKey = 'admin_id';

  Future<void> saveTokens(String accessToken, String refreshToken, String adminId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    await prefs.setString(_adminIdKey, adminId);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<String?> getAdminId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_adminIdKey);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_adminIdKey);
  }

  Future<bool> hasToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
```

- [ ] **Step 2: 创建API客户端**

```dart
// lib/core/network/admin_api_client.dart
import 'package:dio/dio.dart';
import '../storage/admin_token_storage.dart';

class AdminApiClient {
  static const String baseUrl = 'http://23.95.170.176:8080/api/v1';
  
  late final Dio _dio;
  final AdminTokenStorage _tokenStorage = AdminTokenStorage();

  AdminApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.path != '/admin/login') {
          final token = await _tokenStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _tokenStorage.clearTokens();
        }
        return handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;
}
```

- [ ] **Step 3: 创建认证Provider**

```dart
// lib/core/state/admin_auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/admin_api_client.dart';
import '../storage/admin_token_storage.dart';

class AdminAuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? adminId;
  final String? nickname;
  final String? error;

  AdminAuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.adminId,
    this.nickname,
    this.error,
  });

  AdminAuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? adminId,
    String? nickname,
    String? error,
  }) {
    return AdminAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      adminId: adminId ?? this.adminId,
      nickname: nickname ?? this.nickname,
      error: error,
    );
  }
}

class AdminAuthNotifier extends StateNotifier<AdminAuthState> {
  final AdminTokenStorage _tokenStorage = AdminTokenStorage();
  final AdminApiClient _apiClient = AdminApiClient();

  AdminAuthNotifier() : super(AdminAuthState()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true);
    final hasToken = await _tokenStorage.hasToken();
    state = state.copyWith(
      isAuthenticated: hasToken,
      isLoading: false,
    );
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.dio.post('/admin/login', data: {
        'username': username,
        'password': password,
      });

      final data = response.data['data'];
      await _tokenStorage.saveTokens(
        data['access_token'],
        data['refresh_token'],
        data['admin']['id'],
      );

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        adminId: data['admin']['id'],
        nickname: data['admin']['nickname'],
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '用户名或密码错误',
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post('/admin/logout');
    } catch (_) {}
    await _tokenStorage.clearTokens();
    state = AdminAuthState();
  }
}

final adminAuthProvider = StateNotifierProvider<AdminAuthNotifier, AdminAuthState>(
  (ref) => AdminAuthNotifier(),
);
```

- [ ] **Step 4: 创建登录页面**

```dart
// lib/features/auth/presentation/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../core/state/admin_auth_provider.dart';
import '../../../shared/widgets/glass_container.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(adminAuthProvider.notifier).login(
      _usernameController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(adminAuthProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AdminTheme.backgroundGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: GlassContainer(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: AdminTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.admin_panel_settings, size: 48, color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '管理后台',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '请登录以继续',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _usernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '用户名',
                          prefixIcon: const Icon(Icons.person, color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入用户名';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.white),
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: '密码',
                          prefixIcon: const Icon(Icons.lock, color: Colors.white54),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入密码';
                          }
                          return null;
                        },
                      ),
                      if (authState.error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          authState.error!,
                          style: const TextStyle(color: AdminTheme.errorColor),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: authState.isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: authState.isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('登录', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 提交**

```bash
git add admin-app/lib/core/ admin-app/lib/features/auth/
git commit -m "feat(client): add auth provider and login page"
```

---

## Chunk 6: 客户端 - 主框架和仪表盘

### Task 10: 创建主框架和仪表盘

**Files:**
- Create: `admin-app/lib/main.dart`
- Create: `admin-app/lib/app.dart`
- Create: `admin-app/lib/features/dashboard/data/dashboard_repository.dart`
- Create: `admin-app/lib/features/dashboard/presentation/dashboard_page.dart`

- [ ] **Step 1: 创建main.dart**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  runApp(const ProviderScope(child: AdminApp()));
}
```

- [ ] **Step 2: 创建app.dart**

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/admin_theme.dart';
import 'core/state/admin_auth_provider.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/dashboard/presentation/dashboard_page.dart';

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(adminAuthProvider);

    return MaterialApp(
      title: '管理后台',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.darkTheme,
      home: authState.isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : authState.isAuthenticated
              ? const MainShell()
              : const LoginPage(),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  final _pages = const [
    DashboardPage(),
    UsersPage(),
    MonitorPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AdminTheme.backgroundGradient),
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.transparent,
              selectedIconTheme: const IconThemeData(color: AdminTheme.primaryColor),
              selectedLabelTextStyle: const TextStyle(color: AdminTheme.primaryColor),
              unselectedIconTheme: IconThemeData(color: Colors.white.withOpacity(0.5)),
              unselectedLabelTextStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('仪表盘'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('用户'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.monitor_heart_outlined),
                  selectedIcon: Icon(Icons.monitor_heart),
                  label: Text('监控'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('设置'),
                ),
              ],
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white54),
                      onPressed: () {
                        ref.read(adminAuthProvider.notifier).logout();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: _pages[_selectedIndex]),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 创建仪表盘Repository**

```dart
// lib/features/dashboard/data/dashboard_repository.dart
import '../../../core/network/admin_api_client.dart';

class DashboardRepository {
  final _apiClient = AdminApiClient();

  Future<Map<String, dynamic>> getStats() async {
    final response = await _apiClient.dio.get('/admin/dashboard');
    return response.data['data'];
  }
}

final dashboardRepositoryProvider = Provider((ref) => DashboardRepository());

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(dashboardRepositoryProvider).getStats();
});
```

- [ ] **Step 4: 创建仪表盘页面**

```dart
// lib/features/dashboard/presentation/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/stat_card.dart';
import '../data/dashboard_repository.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: statsAsync.when(
        data: (stats) => _buildContent(context, ref, stats),
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (error, _) => Center(
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AdminTheme.errorColor, size: 48),
                const SizedBox(height: 16),
                Text('加载失败: $error', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(dashboardStatsProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Map<String, dynamic> stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('仪表盘', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              StatCard(
                title: '总用户',
                value: _formatNumber(stats['total_users'] ?? 0),
                icon: Icons.people,
                color: AdminTheme.primaryColor,
              ),
              StatCard(
                title: '今日注册',
                value: '${stats['today_new_users'] ?? 0}',
                icon: Icons.person_add,
                color: AdminTheme.successColor,
              ),
              StatCard(
                title: '在线用户',
                value: '${stats['online_users'] ?? 0}',
                icon: Icons.circle,
                color: AdminTheme.successColor,
              ),
              StatCard(
                title: '总消息',
                value: _formatNumber(stats['total_messages'] ?? 0),
                icon: Icons.message,
                color: AdminTheme.secondaryColor,
              ),
              StatCard(
                title: '今日消息',
                value: '${stats['today_messages'] ?? 0}',
                icon: Icons.chat_bubble,
                color: AdminTheme.warningColor,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('用户增长趋势', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 200,
                        child: _buildLineChart(
                          List<int>.from(stats['user_trend'] ?? []),
                          AdminTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('消息发送趋势', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 200,
                        child: _buildLineChart(
                          List<int>.from(stats['message_trend'] ?? []),
                          AdminTheme.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<int> data, Color color) {
    if (data.isEmpty) {
      return const Center(child: Text('暂无数据', style: TextStyle(color: Colors.white54)));
    }

    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList();
    final maxY = data.reduce((a, b) => a > b ? a : b).toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withOpacity(0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
                if (value.toInt() < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      days[value.toInt()],
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.1),
            ),
          ),
        ],
        minY: 0,
        maxY: maxY * 1.2,
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(1)}万';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
```

- [ ] **Step 5: 提交**

```bash
git add admin-app/lib/main.dart admin-app/lib/app.dart admin-app/lib/features/dashboard/
git commit -m "feat(client): add main shell and dashboard page"
```

---

## Chunk 7: 客户端 - 用户管理

### Task 11: 创建用户管理页面

**Files:**
- Create: `admin-app/lib/features/users/data/users_repository.dart`
- Create: `admin-app/lib/features/users/domain/admin_user.dart`
- Create: `admin-app/lib/features/users/presentation/users_page.dart`
- Create: `admin-app/lib/features/users/presentation/user_detail_page.dart`

由于代码量较大，这里只展示关键文件，实际实现时需要完整编写。

- [ ] **Step 1: 创建UsersRepository**

```dart
// lib/features/users/data/users_repository.dart
import '../../../core/network/admin_api_client.dart';

class UsersRepository {
  final _apiClient = AdminApiClient();

  Future<Map<String, dynamic>> getUsers({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (keyword != null && keyword.isNotEmpty) {
      queryParams['keyword'] = keyword;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await _apiClient.dio.get('/admin/users', queryParameters: queryParams);
    return response.data['data'];
  }

  Future<Map<String, dynamic>> getUser(String userId) async {
    final response = await _apiClient.dio.get('/admin/users/$userId');
    return response.data['data'];
  }

  Future<void> updateUserStatus(String userId, String status) async {
    await _apiClient.dio.put('/admin/users/$userId/status', data: {'status': status});
  }

  Future<Map<String, dynamic>> getUserChats(String userId) async {
    final response = await _apiClient.dio.get('/admin/users/$userId/chats');
    return response.data['data'];
  }

  Future<Map<String, dynamic>> getConversationMessages(String conversationId, {int page = 1}) async {
    final response = await _apiClient.dio.get(
      '/admin/conversations/$conversationId/messages',
      queryParameters: {'page': page},
    );
    return response.data['data'];
  }
}
```

- [ ] **Step 2: 创建用户列表页面**

```dart
// lib/features/users/presentation/users_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../shared/widgets/glass_container.dart';
import '../data/users_repository.dart';
import 'user_detail_page.dart';

final usersRepositoryProvider = Provider((ref) => UsersRepository());

final usersProvider = FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>((ref, params) async {
  return ref.read(usersRepositoryProvider).getUsers(
    page: params['page'] ?? 1,
    pageSize: params['pageSize'] ?? 20,
    keyword: params['keyword'],
    status: params['status'],
  );
});

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final _searchController = TextEditingController();
  int _currentPage = 1;
  String? _statusFilter;
  String? _keyword;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    setState(() {
      _keyword = _searchController.text.trim();
      _currentPage = 1;
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _keyword = null;
      _statusFilter = null;
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final params = {
      'page': _currentPage,
      'pageSize': 20,
      'keyword': _keyword,
      'status': _statusFilter,
    };
    final usersAsync = ref.watch(usersProvider(params));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Text('用户管理', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(width: 32),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '搜索用户...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white54),
                        onPressed: _search,
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _statusFilter,
                  hint: const Text('状态', style: TextStyle(color: Colors.white54)),
                  dropdownColor: AdminTheme.surfaceColor,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('全部')),
                    DropdownMenuItem(value: 'active', child: Text('正常')),
                    DropdownMenuItem(value: 'banned', child: Text('禁用')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value;
                      _currentPage = 1;
                    });
                  },
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('清除', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
          Expanded(
            child: usersAsync.when(
              data: (data) {
                final users = data['users'] as List;
                final total = data['total'] as int;
                final totalPages = (total / 20).ceil();

                return Column(
                  children: [
                    Expanded(
                      child: users.isEmpty
                          ? Center(
                              child: GlassContainer(
                                padding: const EdgeInsets.all(32),
                                child: const Text('暂无用户数据', style: TextStyle(color: Colors.white54)),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                final user = users[index];
                                return _UserTile(
                                  user: user,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => UserDetailPage(userId: user['id']),
                                      ),
                                    );
                                  },
                                  onToggleStatus: () async {
                                    final newStatus = user['status'] == 'active' ? 'banned' : 'active';
                                    await ref.read(usersRepositoryProvider).updateUserStatus(user['id'], newStatus);
                                    ref.invalidate(usersProvider);
                                  },
                                );
                              },
                            ),
                    ),
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, color: Colors.white54),
                              onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                            ),
                            Text('$_currentPage / $totalPages', style: const TextStyle(color: Colors.white)),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, color: Colors.white54),
                              onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
              error: (error, _) => Center(
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AdminTheme.errorColor, size: 48),
                      const SizedBox(height: 16),
                      Text('加载失败: $error', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(usersProvider),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;

  const _UserTile({
    required this.user,
    required this.onTap,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final status = user['status'] as String? ?? 'active';
    final isActive = status == 'active';
    final createdAt = DateTime.tryParse(user['created_at'] ?? '') ?? DateTime.now();

    return GlassContainer(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? AdminTheme.primaryColor : Colors.grey,
          child: Text(
            (user['nickname'] ?? '?')[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          user['nickname'] ?? '未知',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${user['phone'] ?? ''} · ${DateFormat('yyyy-MM-dd').format(createdAt)}',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? AdminTheme.successColor.withOpacity(0.2) : AdminTheme.errorColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? '正常' : '禁用',
                style: TextStyle(color: isActive ? AdminTheme.successColor : AdminTheme.errorColor, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onToggleStatus,
              style: TextButton.styleFrom(
                foregroundColor: isActive ? AdminTheme.errorColor : AdminTheme.successColor,
              ),
              child: Text(isActive ? '禁用' : '启用'),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white54),
              onPressed: onTap,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
```

- [ ] **Step 3: 创建用户详情页面**

```dart
// lib/features/users/presentation/user_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/stat_card.dart';
import '../data/users_repository.dart';

final userDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  final repo = ref.read(usersRepositoryProvider);
  final user = await repo.getUser(userId);
  final chats = await repo.getUserChats(userId);
  return {'user': user, 'chats': chats};
});

class UserDetailPage extends ConsumerStatefulWidget {
  final String userId;

  const UserDetailPage({super.key, required this.userId});

  @override
  ConsumerState<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends ConsumerState<UserDetailPage> {
  String? _expandedConversationId;

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(userDetailProvider(widget.userId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('用户详情', style: TextStyle(color: Colors.white)),
      ),
      body: dataAsync.when(
        data: (data) {
          final user = data['user'] as Map<String, dynamic>;
          final chats = data['chats'] as Map<String, dynamic>;
          final stats = chats['stats'] as Map<String, dynamic>? ?? {};
          final conversations = chats['conversations'] as List? ?? [];
          final isActive = (user['status'] as String? ?? 'active') == 'active';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AdminTheme.primaryColor,
                        child: Text(
                          (user['nickname'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['nickname'] ?? '未知',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text('手机: ${user['phone'] ?? '未设置'}', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('状态: ', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isActive ? AdminTheme.successColor.withOpacity(0.2) : AdminTheme.errorColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isActive ? '正常' : '禁用',
                                    style: TextStyle(color: isActive ? AdminTheme.successColor : AdminTheme.errorColor, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final newStatus = isActive ? 'banned' : 'active';
                          await ref.read(usersRepositoryProvider).updateUserStatus(widget.userId, newStatus);
                          ref.invalidate(userDetailProvider);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isActive ? AdminTheme.errorColor : AdminTheme.successColor,
                        ),
                        child: Text(isActive ? '禁用用户' : '启用用户'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    StatCard(
                      title: '发送消息',
                      value: '${stats['sent_messages'] ?? 0}',
                      icon: Icons.send,
                      color: AdminTheme.primaryColor,
                    ),
                    StatCard(
                      title: '接收消息',
                      value: '${stats['received_messages'] ?? 0}',
                      icon: Icons.inbox,
                      color: AdminTheme.secondaryColor,
                    ),
                    StatCard(
                      title: '会话数',
                      value: '${stats['conversations'] ?? 0}',
                      icon: Icons.chat,
                      color: AdminTheme.successColor,
                    ),
                    StatCard(
                      title: '好友数',
                      value: '${stats['friends'] ?? 0}',
                      icon: Icons.people,
                      color: AdminTheme.warningColor,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('会话列表', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (conversations.isEmpty)
                  GlassContainer(
                    padding: const EdgeInsets.all(24),
                    child: const Center(child: Text('该用户暂无会话', style: TextStyle(color: Colors.white54))),
                  )
                else
                  ...conversations.map((conv) {
                    final convMap = conv as Map<String, dynamic>;
                    final convId = convMap['id'] as String;
                    final isExpanded = _expandedConversationId == convId;

                    return Column(
                      children: [
                        GlassContainer(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AdminTheme.secondaryColor,
                              child: const Icon(Icons.chat, color: Colors.white),
                            ),
                            title: Text(
                              convMap['other_user_nickname'] ?? '未知会话',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${convMap['message_count'] ?? 0} 条消息',
                              style: TextStyle(color: Colors.white.withOpacity(0.7)),
                            ),
                            trailing: TextButton(
                              onPressed: () {
                                setState(() {
                                  _expandedConversationId = isExpanded ? null : convId;
                                });
                              },
                              child: Text(isExpanded ? '收起' : '查看消息'),
                            ),
                          ),
                        ),
                        if (isExpanded)
                          _MessageList(conversationId: convId),
                      ],
                    );
                  }),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (error, _) => Center(
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            child: Text('加载失败: $error', style: const TextStyle(color: Colors.white70)),
          ),
        ),
      ),
    );
  }
}

class _MessageList extends ConsumerStatefulWidget {
  final String conversationId;

  const _MessageList({required this.conversationId});

  @override
  ConsumerState<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<_MessageList> {
  late Future<Map<String, dynamic>> _messagesFuture;

  @override
  void initState() {
    super.initState();
    _messagesFuture = ref.read(usersRepositoryProvider).getConversationMessages(widget.conversationId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _messagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('加载失败: ${snapshot.error}', style: const TextStyle(color: Colors.white54)),
          );
        }

        final messages = snapshot.data?['messages'] as List? ?? [];
        if (messages.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('暂无消息记录', style: TextStyle(color: Colors.white54)),
          );
        }

        return GlassContainer(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('消息记录', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...messages.take(20).map((msg) {
                final msgMap = msg as Map<String, dynamic>;
                final createdAt = DateTime.tryParse(msgMap['created_at'] ?? '') ?? DateTime.now();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(createdAt),
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            msgMap['content'] ?? '[${msgMap['type'] ?? 'media'}]',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (messages.length > 20)
                Text('... 还有 ${messages.length - 20} 条消息', style: TextStyle(color: Colors.white.withOpacity(0.5))),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: 提交**

```bash
git add admin-app/lib/features/users/
git commit -m "feat(client): add users management pages"
```

---

## Chunk 8: 客户端 - 系统监控和设置

### Task 12: 创建系统监控页面

**Files:**
- Create: `admin-app/lib/features/monitor/data/monitor_repository.dart`
- Create: `admin-app/lib/features/monitor/presentation/monitor_page.dart`

- [ ] **Step 1: 创建MonitorRepository**

```dart
// lib/features/monitor/data/monitor_repository.dart
import '../../../core/network/admin_api_client.dart';

class MonitorRepository {
  final _apiClient = AdminApiClient();

  Future<Map<String, dynamic>> getMonitorData() async {
    final response = await _apiClient.dio.get('/admin/monitor');
    return response.data['data'];
  }
}
```

- [ ] **Step 2: 创建监控页面**

```dart
// lib/features/monitor/presentation/monitor_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../shared/widgets/glass_container.dart';
import '../data/monitor_repository.dart';

final monitorRepositoryProvider = Provider((ref) => MonitorRepository());

final monitorProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(monitorRepositoryProvider).getMonitorData();
});

class MonitorPage extends ConsumerStatefulWidget {
  const MonitorPage({super.key});

  @override
  ConsumerState<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends ConsumerState<MonitorPage> {
  Timer? _refreshTimer;
  Map<String, dynamic>? _lastData;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      ref.invalidate(monitorProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(monitorProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: dataAsync.when(
        data: (data) {
          _lastData = data;
          _lastUpdate = DateTime.now();
          return _buildContent(data);
        },
        loading: () {
          if (_lastData != null) {
            return _buildContent(_lastData!);
          }
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        },
        error: (error, _) => Center(
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AdminTheme.errorColor, size: 48),
                const SizedBox(height: 16),
                Text('连接失败: $error', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(monitorProvider),
                  child: const Text('重新连接'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    final server = data['server'] as Map<String, dynamic>? ?? {};
    final api = data['api'] as Map<String, dynamic>? ?? {};
    final realtime = data['realtime'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('系统监控', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_lastUpdate != null)
                Text(
                  '上次更新: ${TimeOfDay.fromDateTime(_lastUpdate!).format(context)}',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('服务器资源', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _GaugeCard(title: 'CPU', value: (server['cpu_percent'] ?? 0).toDouble(), color: AdminTheme.primaryColor)),
              const SizedBox(width: 16),
              Expanded(child: _GaugeCard(title: '内存', value: (server['memory_percent'] ?? 0).toDouble(), color: AdminTheme.secondaryColor)),
              const SizedBox(width: 16),
              Expanded(child: _GaugeCard(title: '磁盘', value: (server['disk_percent'] ?? 0).toDouble(), color: AdminTheme.warningColor)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('API 性能', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          GlassContainer(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ApiStat(title: '请求/秒', value: '${(api['requests_per_second'] ?? 0).toStringAsFixed(1)}'),
                _ApiStat(title: '平均响应', value: '${(api['avg_response_time_ms'] ?? 0).toStringAsFixed(0)} ms'),
                _ApiStat(title: '错误率', value: '${((api['error_rate'] ?? 0) * 100).toStringAsFixed(2)}%'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('实时连接', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.cable, color: AdminTheme.primaryColor, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        '${realtime['websocket_connections'] ?? 0}',
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      Text('WebSocket 连接', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.people, color: AdminTheme.successColor, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        '${realtime['online_users'] ?? 0}',
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      Text('在线用户', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.video_call, color: AdminTheme.secondaryColor, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        '${realtime['active_call_rooms'] ?? 0}',
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      Text('通话房间', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugeCard extends StatelessWidget {
  final String title;
  final double value;
  final Color color;

  const _GaugeCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _GaugePainter(value: value, color: color),
              child: Center(
                child: Text(
                  '${value.toStringAsFixed(1)}%',
                  style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;

  _GaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -0.5 * 3.14159,
      3.14159,
      false,
      bgPaint,
    );

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (value / 100) * 3.14159;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159,
      -sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => oldDelegate.value != value;
}

class _ApiStat extends StatelessWidget {
  final String title;
  final String value;

  const _ApiStat({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(color: Colors.white.withOpacity(0.7))),
      ],
    );
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add admin-app/lib/features/monitor/
git commit -m "feat(client): add system monitor page"
```

---

### Task 13: 创建系统设置页面

**Files:**
- Create: `admin-app/lib/features/settings/data/settings_repository.dart`
- Create: `admin-app/lib/features/settings/presentation/settings_page.dart`

- [ ] **Step 1: 创建SettingsRepository**

```dart
// lib/features/settings/data/settings_repository.dart
import '../../../core/network/admin_api_client.dart';

class SettingsRepository {
  final _apiClient = AdminApiClient();

  Future<List<dynamic>> getConfigs() async {
    final response = await _apiClient.dio.get('/admin/configs');
    return response.data['data'];
  }

  Future<void> updateConfig(String key, String value) async {
    await _apiClient.dio.put('/admin/configs/$key', data: {'value': value});
  }
}

final settingsRepositoryProvider = Provider((ref) => SettingsRepository());

final configsProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(settingsRepositoryProvider).getConfigs();
});
```

- [ ] **Step 2: 创建设置页面**

```dart
// lib/features/settings/presentation/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../shared/widgets/glass_container.dart';
import '../data/settings_repository.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(configsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('系统设置', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            configsAsync.when(
              data: (configs) {
                return Column(
                  children: configs.map((config) {
                    final key = config['key'] as String;
                    final value = config['value'] as String;
                    final description = config['description'] as String? ?? '';

                    if (key == 'allow_registration') {
                      return _RegistrationToggle(
                        value: value == 'true',
                        description: description,
                        onChanged: (newValue) async {
                          await ref.read(settingsRepositoryProvider).updateConfig(key, newValue ? 'true' : 'false');
                          ref.invalidate(configsProvider);
                        },
                      );
                    }

                    return GlassContainer(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        title: Text(key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Text(description, style: TextStyle(color: Colors.white.withOpacity(0.7))),
                        trailing: Text(value, style: const TextStyle(color: AdminTheme.primaryColor)),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
              error: (error, _) => GlassContainer(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AdminTheme.errorColor, size: 48),
                    const SizedBox(height: 16),
                    Text('加载失败: $error', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(configsProvider),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationToggle extends StatelessWidget {
  final bool value;
  final String description;
  final ValueChanged<bool> onChanged;

  const _RegistrationToggle({
    required this.value,
    required this.description,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      child: SwitchListTile(
        title: const Text('允许新用户注册', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(
          value ? '新用户可以注册账号' : '新用户无法注册账号',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AdminTheme.successColor,
        inactiveThumbColor: Colors.grey,
      ),
    );
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add admin-app/lib/features/settings/
git commit -m "feat(client): add settings page"
```

---

## Chunk 9: 构建和部署

### Task 14: 构建发布版本

- [ ] **Step 1: 构建Windows客户端**

```bash
cd admin-app
flutter build windows --release
```

- [ ] **Step 2: 测试所有功能**

- 登录/登出
- 仪表盘数据展示
- 用户管理操作
- 系统监控实时数据
- 系统设置

- [ ] **Step 3: 部署服务端更新**

```bash
cd server
go build -o server.exe ./cmd/server
# 部署到服务器
```

- [ ] **Step 4: 最终提交**

```bash
git add .
git commit -m "feat: complete admin dashboard implementation"
```

---

## 测试验证

### 服务端测试

```bash
# 测试管理员登录
curl -X POST http://localhost:8080/api/v1/admin/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# 测试仪表盘
curl http://localhost:8080/api/v1/admin/dashboard \
  -H "Authorization: Bearer <token>"

# 测试用户列表
curl http://localhost:8080/api/v1/admin/users \
  -H "Authorization: Bearer <token>"
```

### 客户端测试

- 运行 `flutter run -d windows`
- 测试所有功能流程

---

## 注意事项

1. **安全**: 管理员密码需要修改默认值
2. **性能**: 监控数据使用SSE实时推送，注意连接管理
3. **权限**: Admin API需要独立的认证中间件
4. **日志**: 添加管理员操作日志便于审计