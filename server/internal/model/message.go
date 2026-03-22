package model

import (
	"github.com/google/uuid"
	"gorm.io/gorm"
	"time"
)

type MessageType string
type MessageStatus string

const (
	MessageTypeText  MessageType = "text"
	MessageTypeImage MessageType = "image"
	MessageTypeVoice MessageType = "voice"
	MessageTypeVideo MessageType = "video"
	MessageTypeFile  MessageType = "file"
)

const (
	MessageStatusSending   MessageStatus = "sending"
	MessageStatusSent      MessageStatus = "sent"
	MessageStatusDelivered MessageStatus = "delivered"
	MessageStatusRead      MessageStatus = "read"
	MessageStatusFailed    MessageStatus = "failed"
)

type Message struct {
	ID             uuid.UUID     `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	ConversationID uuid.UUID     `gorm:"type:uuid;index;not null" json:"conversation_id"`
	SenderID       uuid.UUID     `gorm:"type:uuid;index;not null" json:"sender_id"`
	Type           MessageType   `gorm:"type:varchar(20);not null" json:"type"`
	Content        string        `gorm:"type:text" json:"content"`
	MediaURL       string        `gorm:"size:255" json:"media_url"`
	Duration       int           `gorm:"default:0" json:"duration"`
	Status         MessageStatus `gorm:"type:varchar(20);default:'sent'" json:"status"`
	CreatedAt      time.Time     `gorm:"index" json:"created_at"`
}

func (m *Message) BeforeCreate(tx *gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
