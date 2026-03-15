package router

import (
	"github.com/gin-gonic/gin"
	"github.com/example/social-app/server/internal/handler"
	"github.com/example/social-app/server/internal/middleware"
	"github.com/example/social-app/server/internal/service"
)

func Setup(r *gin.Engine, authService *service.AuthService, authHandler *handler.AuthHandler) {
	r.Use(middleware.CORS())

	api := r.Group("/api/v1")
	{
		auth := api.Group("/auth")
		{
			auth.POST("/register", authHandler.Register)
			auth.POST("/login", authHandler.Login)
			auth.POST("/logout", middleware.AuthMiddleware(authService), authHandler.Logout)
			auth.POST("/refresh-token", authHandler.RefreshToken)
		}
	}

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})
}