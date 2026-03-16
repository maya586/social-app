package main

import (
	"github.com/gin-gonic/gin"
	"log"

	_ "github.com/example/social-app/server/docs"
	"github.com/example/social-app/server/internal/cache"
	"github.com/example/social-app/server/internal/config"
	"github.com/example/social-app/server/internal/database"
	"github.com/example/social-app/server/internal/handler"
	"github.com/example/social-app/server/internal/repository"
	"github.com/example/social-app/server/internal/router"
	"github.com/example/social-app/server/internal/service"
	"github.com/example/social-app/server/internal/storage"
	"github.com/example/social-app/server/internal/webrtc"
	"github.com/example/social-app/server/internal/websocket"
)

// @title Social App API
// @version 1.0
// @description 跨平台社交应用 API 服务
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url http://www.swagger.io/support
// @contact.email support@swagger.io

// @license.name MIT
// @license.url https://opensource.org/licenses/MIT

// @host localhost:8080
// @BasePath /api/v1
// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization
// @description Type "Bearer" followed by a space and JWT token.
func main() {
	cfg := config.Load()

	if err := database.Connect(&cfg.Database); err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	if err := database.Migrate(); err != nil {
		log.Fatal("Failed to migrate database:", err)
	}

	if err := cache.Connect(&cfg.Redis); err != nil {
		log.Fatal("Failed to connect to redis:", err)
	}

	if err := storage.InitMinio(&cfg.Minio); err != nil {
		log.Println("Warning: Failed to connect to MinIO:", err)
	}

	_ = webrtc.GetSFU()

	userRepo := repository.NewUserRepo()
	contactRepo := repository.NewContactRepo()
	conversationRepo := repository.NewConversationRepo()
	messageRepo := repository.NewMessageRepo()

	authService := service.NewAuthService(userRepo, cfg.JWT.Secret, int(cfg.JWT.ExpireTime.Seconds()))
	contactService := service.NewContactService(contactRepo, userRepo)
	messageService := service.NewMessageService(messageRepo, conversationRepo)

	hub := websocket.NewHub()
	go hub.Run()

	authHandler := handler.NewAuthHandler(authService)
	contactHandler := handler.NewContactHandler(contactService)
	messageHandler := handler.NewMessageHandler(messageService)
	fileHandler := handler.NewFileHandler()
	callHandler := handler.NewCallHandler(hub)
	userHandler := handler.NewUserHandler(userRepo)
	wsHandler := handler.NewWSHandler(hub)

	r := gin.Default()
	router.Setup(r, authService, authHandler, contactHandler, messageHandler, fileHandler, callHandler, userHandler, wsHandler)

	log.Printf("Server starting on port %s", cfg.Server.Port)
	if err := r.Run(":" + cfg.Server.Port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
