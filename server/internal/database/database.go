package database

import (
	"fmt"
	"log"
	"gorm.io/gorm"
	"gorm.io/driver/postgres"
	"github.com/example/social-app/server/internal/config"
	"github.com/example/social-app/server/internal/model"
)

var DB *gorm.DB

func Connect(cfg *config.DatabaseConfig) error {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.DBName, cfg.SSLMode,
	)
	
	var err error
	DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return fmt.Errorf("failed to connect database: %w", err)
	}
	
	log.Println("Database connected successfully")
	return nil
}

func Migrate() error {
	return DB.AutoMigrate(
		&model.User{},
		&model.Conversation{},
		&model.Message{},
		&model.Contact{},
		&model.ConversationMember{},
	)
}