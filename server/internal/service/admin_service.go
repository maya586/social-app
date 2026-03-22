package service

import (
	"context"
	"errors"
	"time"

	"github.com/example/social-app/server/internal/cache"
	"github.com/example/social-app/server/internal/model"
	"github.com/example/social-app/server/internal/repository"
	"github.com/example/social-app/server/pkg/jwt"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

var (
	ErrAdminNotFound        = errors.New("admin not found")
	ErrInvalidAdminPassword = errors.New("invalid password")
	ErrAdminTokenInvalid    = errors.New("invalid admin token")
)

type AdminService struct {
	adminRepo *repository.AdminRepo
	userRepo  *repository.UserRepo
	jwtSecret string
	tokenExp  int
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

func (s *AdminService) Login(input *AdminLoginInput) (*AdminAuthResponse, error) {
	admin, err := s.adminRepo.FindByUsername(input.Username)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrAdminNotFound
		}
		return nil, err
	}

	if err := bcrypt.CompareHashAndPassword([]byte(admin.PasswordHash), []byte(input.Password)); err != nil {
		return nil, ErrInvalidAdminPassword
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

	ctx := context.Background()
	key := "admin_blacklist:" + tokenString
	if exists, _ := cache.RDB.Exists(ctx, key).Result(); exists > 0 {
		return nil, ErrAdminTokenInvalid
	}

	return claims, nil
}

func (s *AdminService) Logout(tokenString string) error {
	ctx := context.Background()
	key := "admin_blacklist:" + tokenString
	return cache.RDB.Set(ctx, key, "1", time.Duration(s.tokenExp)*time.Second).Err()
}

type DashboardStats struct {
	TotalUsers          int64   `json:"total_users"`
	TodayNewUsers       int64   `json:"today_new_users"`
	OnlineUsers         int64   `json:"online_users"`
	TotalMessages       int64   `json:"total_messages"`
	TodayMessages       int64   `json:"today_messages"`
	ActiveConversations int64   `json:"active_conversations"`
	UserTrend           []int64 `json:"user_trend"`
	MessageTrend        []int64 `json:"message_trend"`
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
