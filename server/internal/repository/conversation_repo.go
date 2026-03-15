package repository

import (
	"github.com/google/uuid"
	"gorm.io/gorm"
	"github.com/example/social-app/server/internal/database"
	"github.com/example/social-app/server/internal/model"
)

type ConversationRepo struct{}

func NewConversationRepo() *ConversationRepo {
	return &ConversationRepo{}
}

func (r *ConversationRepo) Create(conv *model.Conversation) error {
	return database.DB.Create(conv).Error
}

func (r *ConversationRepo) FindByID(id uuid.UUID) (*model.Conversation, error) {
	var conv model.Conversation
	err := database.DB.Where("id = ?", id).First(&conv).Error
	return &conv, err
}

func (r *ConversationRepo) FindPrivateConversation(user1ID, user2ID uuid.UUID) (*model.Conversation, error) {
	var conv model.Conversation
	err := database.DB.
		Joins("JOIN conversation_members cm1 ON conversations.id = cm1.conversation_id").
		Joins("JOIN conversation_members cm2 ON conversations.id = cm2.conversation_id").
		Where("conversations.type = ?", model.ConversationTypePrivate).
		Where("cm1.user_id = ? AND cm2.user_id = ?", user1ID, user2ID).
		First(&conv).Error
	return &conv, err
}

func (r *ConversationRepo) ListByUserID(userID uuid.UUID, limit, offset int) ([]model.Conversation, error) {
	var convs []model.Conversation
	err := database.DB.
		Joins("JOIN conversation_members ON conversations.id = conversation_members.conversation_id").
		Where("conversation_members.user_id = ?", userID).
		Order("conversations.last_message_at DESC NULLS LAST").
		Limit(limit).Offset(offset).
		Find(&convs).Error
	return convs, err
}

func (r *ConversationRepo) AddMember(member *model.ConversationMember) error {
	return database.DB.Create(member).Error
}

func (r *ConversationRepo) RemoveMember(conversationID, userID uuid.UUID) error {
	return database.DB.Where("conversation_id = ? AND user_id = ?", conversationID, userID).
		Delete(&model.ConversationMember{}).Error
}

func (r *ConversationRepo) GetMembers(conversationID uuid.UUID) ([]model.ConversationMember, error) {
	var members []model.ConversationMember
	err := database.DB.Where("conversation_id = ?", conversationID).Find(&members).Error
	return members, err
}

func (r *ConversationRepo) IsMember(conversationID, userID uuid.UUID) (bool, error) {
	var count int64
	err := database.DB.Model(&model.ConversationMember{}).
		Where("conversation_id = ? AND user_id = ?", conversationID, userID).
		Count(&count).Error
	return count > 0, err
}

func (r *ConversationRepo) UpdateLastMessageAt(conversationID uuid.UUID) error {
	return database.DB.Model(&model.Conversation{}).
		Where("id = ?", conversationID).
		Update("last_message_at", gorm.Expr("NOW()")).Error
}