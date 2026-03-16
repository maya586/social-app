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

// Register godoc
// @Summary 用户注册
// @Description 注册新用户账号
// @Tags 认证
// @Accept json
// @Produce json
// @Param request body service.RegisterInput true "注册信息"
// @Success 201 {object} map[string]interface{} "注册成功"
// @Failure 400 {object} map[string]string "参数错误"
// @Failure 409 {object} map[string]string "手机号已存在"
// @Router /auth/register [post]
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

// Login godoc
// @Summary 用户登录
// @Description 用户登录获取访问令牌
// @Tags 认证
// @Accept json
// @Produce json
// @Param request body service.LoginInput true "登录信息"
// @Success 200 {object} map[string]interface{} "登录成功"
// @Failure 401 {object} map[string]string "认证失败"
// @Router /auth/login [post]
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

// RefreshToken godoc
// @Summary 刷新令牌
// @Description 使用刷新令牌获取新的访问令牌
// @Tags 认证
// @Accept json
// @Produce json
// @Param request body map[string]string true "刷新令牌"
// @Success 200 {object} map[string]interface{} "刷新成功"
// @Failure 401 {object} map[string]string "无效的刷新令牌"
// @Router /auth/refresh-token [post]
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

// Logout godoc
// @Summary 用户登出
// @Description 用户登出，使令牌失效
// @Tags 认证
// @Security BearerAuth
// @Produce json
// @Success 200 {object} map[string]interface{} "登出成功"
// @Router /auth/logout [post]
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