package router

import (
	"github.com/gin-gonic/gin"
	"github.com/example/social-app/server/internal/handler"
	"github.com/example/social-app/server/internal/middleware"
	"github.com/example/social-app/server/internal/service"
)

func Setup(r *gin.Engine, authService *service.AuthService, authHandler *handler.AuthHandler,
	contactHandler *handler.ContactHandler, messageHandler *handler.MessageHandler,
	fileHandler *handler.FileHandler, wsHandler *handler.WSHandler) {
	
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

		protected := api.Group("")
		protected.Use(middleware.AuthMiddleware(authService))
		{
			contacts := protected.Group("/contacts")
			{
				contacts.GET("", contactHandler.GetContacts)
				contacts.POST("/request", contactHandler.AddContact)
				contacts.POST("/accept/:id", contactHandler.AcceptContact)
				contacts.DELETE("/:id", contactHandler.DeleteContact)
			}

			messages := protected.Group("/messages")
			{
				messages.GET("/conversation/:id", messageHandler.List)
				messages.POST("", messageHandler.Send)
				messages.DELETE("/:id", messageHandler.Recall)
				messages.PUT("/conversation/:id/read", messageHandler.MarkAsRead)
			}

			files := protected.Group("/files")
			{
				files.POST("/upload", fileHandler.Upload)
				files.GET("/:id", fileHandler.Download)
				files.DELETE("/:id", fileHandler.Delete)
			}

			conversations := protected.Group("/conversations")
			{
				conversations.GET("", messageHandler.ListConversations)
				conversations.POST("", messageHandler.CreateConversation)
				conversations.GET("/:id", messageHandler.GetConversation)
			}
		}
	}

	r.GET("/ws", wsHandler.HandleWebSocket)
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})
}