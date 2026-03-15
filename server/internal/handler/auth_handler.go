package handler

import (
	"strings"
	"github.com/gin-gonic/gin"
	"github.com/example/social-app/server/internal/service"
	"github.com/example/social-app/server/pkg/response"
)

type AuthHandler struct {
	authService *service.AuthService
}

func NewAuthHandler(authService *service.AuthService) *AuthHandler {
	return &AuthHandler{
		authService: authService,
	}
}

func (h *AuthHandler) Register(c *gin.Context) {
	var input service.RegisterInput
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Invalid request parameters")
		return
	}

	result, err := h.authService.Register(&input)
	if err != nil {
		switch err {
		case service.ErrPhoneExists:
			response.Error(c, 409, "USER_PHONE_EXISTS", "Phone number already registered")
		default:
			response.InternalError(c, "Failed to register user")
		}
		return
	}

	response.Created(c, result)
}

func (h *AuthHandler) Login(c *gin.Context) {
	var input service.LoginInput
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Invalid request parameters")
		return
	}

	result, err := h.authService.Login(&input)
	if err != nil {
		switch err {
		case service.ErrUserNotFound, service.ErrInvalidPassword:
			response.Error(c, 401, "AUTH_INVALID_CREDENTIALS", "Invalid phone or password")
		default:
			response.InternalError(c, "Failed to login")
		}
		return
	}

	response.Success(c, result)
}

func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var input struct {
		RefreshToken string `json:"refresh_token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Refresh token required")
		return
	}

	claims, err := h.authService.ValidateToken(input.RefreshToken)
	if err != nil {
		response.Unauthorized(c, "Invalid refresh token")
		return
	}

	result, err := h.authService.Login(&service.LoginInput{
		Phone: claims.Phone,
	})
	if err != nil {
		response.InternalError(c, "Failed to refresh token")
		return
	}

	response.Success(c, result)
}

func (h *AuthHandler) Logout(c *gin.Context) {
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

	if err := h.authService.Logout(parts[1]); err != nil {
		response.InternalError(c, "Failed to logout")
		return
	}

	response.Success(c, nil)
}