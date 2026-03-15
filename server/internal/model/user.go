package model

import (
	"time"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type UserStatus string

const (
	UserStatusActive   UserStatus = "active"
	UserStatusInactive UserStatus = "inactive"
	UserStatusBanned   UserStatus = "banned"
)

type User struct {
	ID           uuid.UUID  `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	Phone        string     `gorm:"uniqueIndex;size:20;not null" json:"phone"`
	Nickname     string     `gorm:"size:50;not null" json:"nickname"`
	AvatarURL    string     `gorm:"size:255" json:"avatar_url"`
	PasswordHash string     `gorm:"size:255;not null" json:"-"`
	Status       UserStatus `gorm:"type:varchar(20);default:'active'" json:"status"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
}

func (u *User) BeforeCreate(tx *gorm.DB) error {
	if u.ID == uuid.Nil {
		u.ID = uuid.New()
	}
	return nil
}