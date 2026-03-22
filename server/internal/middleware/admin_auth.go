package middleware

import (
	"strings"

	"github.com/example/social-app/server/internal/service"
	"github.com/example/social-app/server/pkg/response"
	"github.com/gin-gonic/gin"
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
		c.Next()
	}
}
