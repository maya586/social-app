package main

import (
	"log"
	"github.com/gin-gonic/gin"
	"github.com/example/social-app/server/internal/cache"
	"github.com/example/social-app/server/internal/config"
	"github.com/example/social-app/server/internal/database"
	"github.com/example/social-app/server/internal/handler"
	"github.com/example/social-app/server/internal/repository"
	"github.com/example/social-app/server/internal/router"
	"github.com/example/social-app/server/internal/service"
	"github.com/example/social-app/server/internal/storage"
	"github.com/example/social-app/server/internal/websocket"
)

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

	userRepo := repository.NewUserRepo()
	contactRepo := repository.NewContactRepo()
	conversationRepo := repository.NewConversationRepo()
	messageRepo := repository.NewMessageRepo()

	authService := service.NewAuthService(userRepo, cfg.JWT.Secret, int(cfg.JWT.ExpireTime.Seconds()))
	contactService := service.NewContactService(contactRepo, userRepo)
	messageService := service.NewMessageService(messageRepo, conversationRepo)

	authHandler := handler.NewAuthHandler(authService)
	contactHandler := handler.NewContactHandler(contactService)
	messageHandler := handler.NewMessageHandler(messageService)
	fileHandler := handler.NewFileHandler()

	hub := websocket.NewHub()
	go hub.Run()
	wsHandler := handler.NewWSHandler(hub)
	
	r := gin.Default()
	router.Setup(r, authService, authHandler, contactHandler, messageHandler, fileHandler, wsHandler)
	
	log.Printf("Server starting on port %s", cfg.Server.Port)
	if err := r.Run(":" + cfg.Server.Port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}