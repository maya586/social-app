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
	ErrPhoneExists      = errors.New("phone already registered")
	ErrInvalidPassword  = errors.New("invalid password")
	ErrUserNotFound     = errors.New("user not found")
	ErrTokenBlacklisted = errors.New("token has been revoked")
)

type AuthService struct {
	userRepo    *repository.UserRepo
	jwtSecret   string
	tokenExpire int
}

func NewAuthService(userRepo *repository.UserRepo, jwtSecret string, tokenExpire int) *AuthService {
	return &AuthService{
		userRepo:    userRepo,
		jwtSecret:   jwtSecret,
		tokenExpire: tokenExpire,
	}
}

type RegisterInput struct {
	Phone    string `json:"phone" binding:"required"`
	Password string `json:"password" binding:"required,min=6,max=32"`
	Nickname string `json:"nickname" binding:"required,min=2,max=20"`
}

type LoginInput struct {
	Phone    string `json:"phone" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type AuthResponse struct {
	AccessToken  string      `json:"access_token"`
	RefreshToken string      `json:"refresh_token"`
	ExpiresIn    int         `json:"expires_in"`
	User         *model.User `json:"user"`
}

func (s *AuthService) Register(input *RegisterInput) (*AuthResponse, error) {
	exists, err := s.userRepo.ExistsByPhone(input.Phone)
	if err != nil {
		return nil, err
	}
	if exists {
		return nil, ErrPhoneExists
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	user := &model.User{
		Phone:        input.Phone,
		Nickname:     input.Nickname,
		PasswordHash: string(hashedPassword),
		Status:       model.UserStatusActive,
	}

	if err := s.userRepo.Create(user); err != nil {
		return nil, err
	}

	return s.generateTokens(user)
}

func (s *AuthService) Login(input *LoginInput) (*AuthResponse, error) {
	user, err := s.userRepo.FindByPhone(input.Phone)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(input.Password)); err != nil {
		return nil, ErrInvalidPassword
	}

	return s.generateTokens(user)
}

func (s *AuthService) RefreshToken(userID string, phone string) (*AuthResponse, error) {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, ErrUserNotFound
	}
	user, err := s.userRepo.FindByID(uid)
	if err != nil {
		return nil, ErrUserNotFound
	}

	return s.generateTokens(user)
}

func (s *AuthService) generateTokens(user *model.User) (*AuthResponse, error) {
	accessToken, err := jwt.GenerateToken(user.ID, user.Phone, s.jwtSecret, time.Duration(s.tokenExpire)*time.Second)
	if err != nil {
		return nil, err
	}

	refreshToken, err := jwt.GenerateToken(user.ID, user.Phone, s.jwtSecret, time.Duration(s.tokenExpire*7)*time.Second)
	if err != nil {
		return nil, err
	}

	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    s.tokenExpire,
		User:         user,
	}, nil
}

func (s *AuthService) ValidateToken(tokenString string) (*jwt.Claims, error) {
	claims, err := jwt.ParseToken(tokenString, s.jwtSecret)
	if err != nil {
		return nil, err
	}

	ctx := context.Background()
	key := "blacklist:" + tokenString
	if exists, _ := cache.RDB.Exists(ctx, key).Result(); exists > 0 {
		return nil, ErrTokenBlacklisted
	}

	return claims, nil
}

func (s *AuthService) Logout(tokenString string) error {
	ctx := context.Background()
	key := "blacklist:" + tokenString
	return cache.RDB.Set(ctx, key, "1", time.Duration(s.tokenExpire)*time.Second).Err()
}
