package router

import (
	"time"
	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
	"github.com/example/social-app/server/internal/handler"
	"github.com/example/social-app/server/internal/middleware"
	"github.com/example/social-app/server/internal/service"
)

func Setup(r *gin.Engine, authService *service.AuthService, authHandler *handler.AuthHandler,
	contactHandler *handler.ContactHandler, messageHandler *handler.MessageHandler,
	fileHandler *handler.FileHandler, callHandler *handler.CallHandler, 
	deviceTokenHandler *handler.DeviceTokenHandler, wsHandler *handler.WSHandler) {
	
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

		protected := api.Group("")
		protected.Use(middleware.AuthMiddleware(authService))
		protected.Use(middleware.UserRateLimit(300, time.Minute))
		{
			contacts := protected.Group("/contacts")
			{
				contacts.GET("", contactHandler.GetContacts)
				contacts.POST("/request", contactHandler.AddContact)
				contacts.POST("/accept/:id", contactHandler.AcceptContact)
				contacts.DELETE("/:id", contactHandler.DeleteContact)
			}

			messages := protected.Group("/messages")
			messages.Use(middleware.UserRateLimit(100, time.Minute))
			{
				messages.GET("/conversation/:id", messageHandler.List)
				messages.POST("", messageHandler.Send)
				messages.DELETE("/:id", messageHandler.Recall)
				messages.PUT("/conversation/:id/read", messageHandler.MarkAsRead)
			}

			files := protected.Group("/files")
			files.Use(middleware.UserRateLimit(20, time.Hour))
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

			calls := protected.Group("/calls")
			{
				calls.POST("/create", callHandler.CreateCall)
				calls.POST("/join", callHandler.JoinCall)
				calls.DELETE("/:room_id", callHandler.LeaveCall)
				calls.POST("/signal", callHandler.Signal)
				calls.GET("/stats", callHandler.GetCallStats)
				calls.GET("/ice-servers", callHandler.GetICEServers)
			}

			devices := protected.Group("/devices")
			{
				devices.POST("/token", deviceTokenHandler.RegisterDeviceToken)
				devices.DELETE("/token", deviceTokenHandler.UnregisterDeviceToken)
			}
		}
	}

	r.GET("/ws", wsHandler.HandleWebSocket)
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})
	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))
}