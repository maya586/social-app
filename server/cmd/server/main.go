package main

import (
	"log"
	"github.com/gin-gonic/gin"
	"github.com/example/social-app/server/internal/config"
)

func main() {
	cfg := config.Load()
	
	r := gin.Default()
	
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})
	
	log.Printf("Server starting on port %s", cfg.Server.Port)
	if err := r.Run(":" + cfg.Server.Port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}