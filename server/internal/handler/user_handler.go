package handler

import (
	"github.com/example/social-app/server/internal/middleware"
	"github.com/example/social-app/server/internal/repository"
	"github.com/example/social-app/server/pkg/response"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type UserHandler struct {
	userRepo *repository.UserRepo
}

func NewUserHandler(userRepo *repository.UserRepo) *UserHandler {
	return &UserHandler{userRepo: userRepo}
}

// SearchUser godoc
// @Summary 搜索用户
// @Description 通过手机号搜索用户
// @Tags 用户
// @Security BearerAuth
// @Produce json
// @Param phone query string true "手机号"
// @Success 200 {object} map[string]interface{} "用户信息"
// @Failure 404 {object} map[string]string "用户不存在"
// @Router /users/search [get]
func (h *UserHandler) SearchUser(c *gin.Context) {
	phone := c.Query("phone")
	if phone == "" {
		response.BadRequest(c, "Phone number required")
		return
	}

	user, err := h.userRepo.FindByPhone(phone)
	if err != nil {
		response.NotFound(c, "User not found")
		return
	}

	response.Success(c, gin.H{
		"id":         user.ID.String(),
		"phone":      user.Phone,
		"nickname":   user.Nickname,
		"avatar_url": user.AvatarURL,
		"status":     user.Status,
	})
}

// GetProfile godoc
// @Summary 获取当前用户信息
// @Description 获取当前登录用户的详细信息
// @Tags 用户
// @Security BearerAuth
// @Produce json
// @Success 200 {object} map[string]interface{} "用户信息"
// @Router /users/me [get]
func (h *UserHandler) GetProfile(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)

	user, err := h.userRepo.FindByID(userID)
	if err != nil {
		response.InternalError(c, "Failed to get user profile")
		return
	}

	response.Success(c, gin.H{
		"id":         user.ID.String(),
		"phone":      user.Phone,
		"nickname":   user.Nickname,
		"avatar_url": user.AvatarURL,
		"status":     user.Status,
		"created_at": user.CreatedAt,
		"updated_at": user.UpdatedAt,
	})
}

// UpdateProfile godoc
// @Summary 更新用户信息
// @Description 更新当前用户的昵称或头像
// @Tags 用户
// @Security BearerAuth
// @Accept json
// @Produce json
// @Param request body map[string]interface{} true "更新信息"
// @Success 200 {object} map[string]interface{} "更新成功"
// @Router /users/me [put]
func (h *UserHandler) UpdateProfile(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)

	var input struct {
		Nickname  string `json:"nickname"`
		AvatarURL string `json:"avatar_url"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Invalid request")
		return
	}

	user, err := h.userRepo.FindByID(userID)
	if err != nil {
		response.InternalError(c, "Failed to get user")
		return
	}

	if input.Nickname != "" {
		user.Nickname = input.Nickname
	}
	if input.AvatarURL != "" {
		user.AvatarURL = input.AvatarURL
	}

	if err := h.userRepo.Update(user); err != nil {
		response.InternalError(c, "Failed to update profile")
		return
	}

	response.Success(c, gin.H{
		"id":         user.ID.String(),
		"nickname":   user.Nickname,
		"avatar_url": user.AvatarURL,
	})
}
