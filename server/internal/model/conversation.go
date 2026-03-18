package model

import (
	"github.com/google/uuid"
	"gorm.io/gorm"
	"time"
)

type ConversationType string

const (
	ConversationTypePrivate ConversationType = "private"
	ConversationTypeGroup   ConversationType = "group"
)

type Conversation struct {
	ID            uuid.UUID        `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	Type          ConversationType `gorm:"type:varchar(20);not null" json:"type"`
	Name          string           `gorm:"size:100" json:"name"`
	AvatarURL     string           `gorm:"size:255" json:"avatar_url"`
	OwnerID       uuid.UUID        `gorm:"type:uuid" json:"owner_id"`
	LastMessageAt *time.Time       `json:"last_message_at"`
	CreatedAt     time.Time        `json:"created_at"`
}

func (c *Conversation) BeforeCreate(tx *gorm.DB) error {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	return nil
}

type ConversationWithDetails struct {
	ID              uuid.UUID  `json:"id"`
	Type            string     `json:"type"`
	Name            string     `json:"name"`
	AvatarURL       string     `json:"avatar_url"`
	OwnerID         uuid.UUID  `json:"owner_id"`
	LastMessageAt   *time.Time `json:"last_message_at"`
	CreatedAt       time.Time  `json:"created_at"`
	LastMessage     string     `json:"last_message"`
	LastSenderName  string     `json:"last_sender_name"`
	UnreadCount     int64      `json:"unread_count"`
	OtherUserID     uuid.UUID  `json:"other_user_id,omitempty"`
	OtherUserName   string     `json:"other_user_name,omitempty"`
	OtherUserAvatar string     `json:"other_user_avatar,omitempty"`
}
