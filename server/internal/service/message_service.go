package service

import (
	"errors"
	"time"
	"github.com/google/uuid"
	"github.com/example/social-app/server/internal/model"
	"github.com/example/social-app/server/internal/repository"
)

var (
	ErrConversationNotFound = errors.New("conversation not found")
	ErrNotMember            = errors.New("not a member of conversation")
	ErrMessageNotFound      = errors.New("message not found")
	ErrRecallTimeout        = errors.New("message recall timeout")
)

type MessageService struct {
	messageRepo      *repository.MessageRepo
	conversationRepo *repository.ConversationRepo
}

func NewMessageService(messageRepo *repository.MessageRepo, conversationRepo *repository.ConversationRepo) *MessageService {
	return &MessageService{
		messageRepo:      messageRepo,
		conversationRepo: conversationRepo,
	}
}

type SendMessageInput struct {
	ConversationID uuid.UUID         `json:"conversation_id" binding:"required"`
	Type           model.MessageType `json:"type" binding:"required"`
	Content        string            `json:"content"`
	MediaURL       string            `json:"media_url"`
}

type MessageListResponse struct {
	Messages   []model.Message `json:"messages"`
	NextCursor string          `json:"next_cursor"`
	HasMore    bool            `json:"has_more"`
}

func (s *MessageService) Send(senderID uuid.UUID, input *SendMessageInput) (*model.Message, error) {
	isMember, err := s.conversationRepo.IsMember(input.ConversationID, senderID)
	if err != nil {
		return nil, err
	}
	if !isMember {
		return nil, ErrNotMember
	}

	message := &model.Message{
		ConversationID: input.ConversationID,
		SenderID:       senderID,
		Type:           input.Type,
		Content:        input.Content,
		MediaURL:       input.MediaURL,
		Status:         model.MessageStatusSent,
	}

	if err := s.messageRepo.Create(message); err != nil {
		return nil, err
	}

	s.conversationRepo.UpdateLastMessageAt(input.ConversationID)
	return message, nil
}

func (s *MessageService) List(conversationID, userID uuid.UUID, cursor string, limit int) (*MessageListResponse, error) {
	isMember, err := s.conversationRepo.IsMember(conversationID, userID)
	if err != nil {
		return nil, err
	}
	if !isMember {
		return nil, ErrNotMember
	}

	var cursorTime *time.Time
	if cursor != "" {
		t, _ := time.Parse(time.RFC3339, cursor)
		cursorTime = &t
	}

	messages, err := s.messageRepo.ListByConversation(conversationID, cursorTime, limit+1)
	if err != nil {
		return nil, err
	}

	hasMore := len(messages) > limit
	if hasMore {
		messages = messages[:limit]
	}

	var nextCursor string
	if hasMore && len(messages) > 0 {
		nextCursor = messages[len(messages)-1].CreatedAt.Format(time.RFC3339)
	}

	return &MessageListResponse{
		Messages:   messages,
		NextCursor: nextCursor,
		HasMore:    hasMore,
	}, nil
}

func (s *MessageService) Recall(messageID, userID uuid.UUID) error {
	message, err := s.messageRepo.FindByID(messageID)
	if err != nil {
		return ErrMessageNotFound
	}

	if message.SenderID != userID {
		return errors.New("not message owner")
	}

	if time.Since(message.CreatedAt) > 2*time.Minute {
		return ErrRecallTimeout
	}

	return s.messageRepo.SoftDelete(messageID)
}