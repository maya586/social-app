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

	userRepo := repository.NewUserRepo()
	authService := service.NewAuthService(userRepo, cfg.JWT.Secret, int(cfg.JWT.ExpireTime.Seconds()))
	authHandler := handler.NewAuthHandler(authService)
	
	r := gin.Default()
	router.Setup(r, authService, authHandler)
	
	log.Printf("Server starting on port %s", cfg.Server.Port)
	if err := r.Run(":" + cfg.Server.Port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}