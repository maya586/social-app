package main

import (
	"log"
	"github.com/gin-gonic/gin"
	"github.com/example/social-app/server/internal/config"
	"github.com/example/social-app/server/internal/database"
)

func main() {
	cfg := config.Load()
	
	if err := database.Connect(&cfg.Database); err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	
	if err := database.Migrate(); err != nil {
		log.Fatal("Failed to migrate database:", err)
	}
	
	r := gin.Default()
	
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})
	
	log.Printf("Server starting on port %s", cfg.Server.Port)
	if err := r.Run(":" + cfg.Server.Port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}