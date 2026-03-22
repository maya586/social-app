package repository

import (
	"github.com/example/social-app/server/internal/database"
	"github.com/example/social-app/server/internal/model"
	"github.com/google/uuid"
	"gorm.io/gorm"
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

func (r *ConversationRepo) ListWithDetailsByUserID(userID uuid.UUID, limit, offset int) ([]model.ConversationWithDetails, error) {
	var results []model.ConversationWithDetails

	query := `
		SELECT 
			c.id, c.type, c.name, c.avatar_url, c.owner_id, c.last_message_at, c.created_at,
			COALESCE(m.content, '') as last_message,
			COALESCE(u.nickname, '') as last_sender_name,
			COALESCE(unread.count, 0) as unread_count,
			other_user.id as other_user_id,
			other_user.nickname as other_user_name,
			other_user.avatar_url as other_user_avatar
		FROM conversations c
		JOIN conversation_members cm ON c.id = cm.conversation_id AND cm.user_id = ?
		LEFT JOIN LATERAL (
			SELECT content, sender_id FROM messages 
			WHERE conversation_id = c.id
			ORDER BY created_at DESC LIMIT 1
		) m ON true
		LEFT JOIN users u ON m.sender_id = u.id
		LEFT JOIN LATERAL (
			SELECT COUNT(*) as count FROM messages 
			WHERE conversation_id = c.id AND sender_id != ?
			AND created_at > COALESCE((
				SELECT last_read_at FROM conversation_members 
				WHERE conversation_id = c.id AND user_id = ?
			), '1970-01-01')
		) unread ON true
		LEFT JOIN LATERAL (
			SELECT u2.id, u2.nickname, u2.avatar_url FROM conversation_members cm2
			JOIN users u2 ON cm2.user_id = u2.id
			WHERE cm2.conversation_id = c.id AND cm2.user_id != ?
			LIMIT 1
		) other_user ON c.type = 'private'
		ORDER BY c.last_message_at DESC NULLS LAST
		LIMIT ? OFFSET ?
	`

	err := database.DB.Raw(query, userID, userID, userID, userID, limit, offset).Scan(&results).Error
	return results, err
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

func (r *ConversationRepo) FindWithOtherUser(conversationID, userID uuid.UUID) (*model.ConversationWithDetails, error) {
	var result model.ConversationWithDetails

	query := `
		SELECT 
			c.id, c.type, c.name, c.avatar_url, c.owner_id, c.last_message_at, c.created_at,
			other_user.id as other_user_id,
			other_user.nickname as other_user_name,
			other_user.avatar_url as other_user_avatar
		FROM conversations c
		LEFT JOIN LATERAL (
			SELECT u2.id, u2.nickname, u2.avatar_url FROM conversation_members cm2
			JOIN users u2 ON cm2.user_id = u2.id
			WHERE cm2.conversation_id = c.id AND cm2.user_id != ?
			LIMIT 1
		) other_user ON c.type = 'private'
		WHERE c.id = ?
	`

	err := database.DB.Raw(query, userID, conversationID).Scan(&result).Error
	return &result, err
}
