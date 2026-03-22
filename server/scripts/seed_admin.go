package main

import (
	"log"
	"os"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "host=localhost user=postgres password=postgres dbname=social_app port=5432 sslmode=disable"
	}

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	password := "admin123"
	if len(os.Args) > 1 {
		password = os.Args[1]
	}

	hashedPassword, _ := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)

	result := db.Exec(`
		INSERT INTO admins (id, username, password_hash, nickname, role, created_at, updated_at)
		VALUES (gen_random_uuid(), 'admin', ?, 'Administrator', 'admin', NOW(), NOW())
		ON CONFLICT (username) DO NOTHING
	`, string(hashedPassword))

	if result.Error != nil {
		log.Println("Seed error:", result.Error)
	} else {
		log.Println("Admin user created/exists. Username: admin, Password:", password)
	}

	result = db.Exec(`
		INSERT INTO system_configs (key, value, description, updated_at)
		VALUES ('allow_registration', 'true', '是否允许新用户注册', NOW())
		ON CONFLICT (key) DO NOTHING
	`)

	if result.Error != nil {
		log.Println("Config seed error:", result.Error)
	} else {
		log.Println("System configs seeded")
	}
}
