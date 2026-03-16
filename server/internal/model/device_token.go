package model

import (
	"time"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type DevicePlatform string

const (
	DevicePlatformAndroid DevicePlatform = "android"
	DevicePlatformIOS     DevicePlatform = "ios"
	DevicePlatformWeb     DevicePlatform = "web"
)

type DeviceToken struct {
	ID        uuid.UUID      `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID    uuid.UUID      `gorm:"type:uuid;index;not null" json:"user_id"`
	Token     string         `gorm:"size:255;uniqueIndex;not null" json:"token"`
	Platform  DevicePlatform `gorm:"type:varchar(20);not null" json:"platform"`
	DeviceID  string         `gorm:"size:100" json:"device_id"`
	IsActive  bool           `gorm:"default:true" json:"is_active"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
}

func (d *DeviceToken) BeforeCreate(tx *gorm.DB) error {
	if d.ID == uuid.Nil {
		d.ID = uuid.New()
	}
	return nil
}