package router

import (
	"time"

	"github.com/example/social-app/server/internal/handler"
	"github.com/example/social-app/server/internal/middleware"
	"github.com/example/social-app/server/internal/service"
	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
)

func Setup(r *gin.Engine, authService *service.AuthService, authHandler *handler.AuthHandler,
	contactHandler *handler.ContactHandler, messageHandler *handler.MessageHandler,
	fileHandler *handler.FileHandler, callHandler *handler.CallHandler,
	userHandler *handler.UserHandler, wsHandler *handler.WSHandler,
	adminService *service.AdminService, adminHandler *handler.AdminHandler) {

	r.Use(middleware.CORS())
	r.Use(middleware.MonitorMiddleware())

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

		protected := api.Group("")
		protected.Use(middleware.AuthMiddleware(authService))
		protected.Use(middleware.UserRateLimit(300, time.Minute))
		{
			contacts := protected.Group("/contacts")
			{
				contacts.GET("", contactHandler.GetContacts)
				contacts.GET("/pending", contactHandler.GetPendingRequests)
				contacts.POST("/request", contactHandler.AddContact)
				contacts.POST("/accept/:id", contactHandler.AcceptContact)
				contacts.POST("/reject/:id", contactHandler.RejectContact)
				contacts.DELETE("/:id", contactHandler.DeleteContact)
			}

			messages := protected.Group("/messages")
			messages.Use(middleware.UserRateLimit(100, time.Minute))
			{
				messages.GET("/conversation/:id", messageHandler.List)
				messages.POST("", messageHandler.Send)
				messages.DELETE("/:id", messageHandler.Recall)
				messages.DELETE("/conversation/:id", messageHandler.ClearConversation)
				messages.PUT("/conversation/:id/read", messageHandler.MarkAsRead)
			}

			protectedFiles := protected.Group("/files")
			protectedFiles.Use(middleware.UserRateLimit(20, time.Hour))
			{
				protectedFiles.POST("/upload", fileHandler.Upload)
				protectedFiles.DELETE("/:id", fileHandler.Delete)
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

			users := protected.Group("/users")
			{
				users.GET("/search", userHandler.SearchUser)
				users.GET("/me", userHandler.GetProfile)
				users.PUT("/me", userHandler.UpdateProfile)
			}
		}
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

	r.GET("/ws", wsHandler.HandleWebSocket)
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})
	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))
}
