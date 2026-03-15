package repository

import (
	"time"
	"github.com/google/uuid"
	"github.com/example/social-app/server/internal/database"
	"github.com/example/social-app/server/internal/model"
)

type MessageRepo struct{}

func NewMessageRepo() *MessageRepo {
	return &MessageRepo{}
}

func (r *MessageRepo) Create(message *model.Message) error {
	return database.DB.Create(message).Error
}

func (r *MessageRepo) FindByID(id uuid.UUID) (*model.Message, error) {
	var message model.Message
	err := database.DB.Where("id = ?", id).First(&message).Error
	return &message, err
}

func (r *MessageRepo) ListByConversation(conversationID uuid.UUID, cursor *time.Time, limit int) ([]model.Message, error) {
	query := database.DB.Where("conversation_id = ?", conversationID)
	if cursor != nil {
		query = query.Where("created_at < ?", cursor)
	}
	var messages []model.Message
	err := query.Order("created_at DESC").Limit(limit).Find(&messages).Error
	return messages, err
}

func (r *MessageRepo) UpdateStatus(id uuid.UUID, status model.MessageStatus) error {
	return database.DB.Model(&model.Message{}).Where("id = ?", id).Update("status", status).Error
}

func (r *MessageRepo) SoftDelete(id uuid.UUID) error {
	return database.DB.Model(&model.Message{}).Where("id = ?", id).
		Updates(map[string]interface{}{
			"content": "消息已撤回",
			"type":    model.MessageTypeText,
		}).Error
}