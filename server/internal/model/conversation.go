package model

import (
	"time"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type ConversationType string

const (
	ConversationTypePrivate ConversationType = "private"
	ConversationTypeGroup   ConversationType = "group"
)

type Conversation struct {
	ID             uuid.UUID        `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	Type           ConversationType `gorm:"type:varchar(20);not null" json:"type"`
	Name           string           `gorm:"size:100" json:"name"`
	AvatarURL      string           `gorm:"size:255" json:"avatar_url"`
	OwnerID        uuid.UUID        `gorm:"type:uuid" json:"owner_id"`
	LastMessageAt  *time.Time       `json:"last_message_at"`
	CreatedAt      time.Time        `json:"created_at"`
}

func (c *Conversation) BeforeCreate(tx *gorm.DB) error {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	return nil
}