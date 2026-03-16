package handler

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/example/social-app/server/internal/middleware"
	"github.com/example/social-app/server/internal/model"
	"github.com/example/social-app/server/internal/service"
	"github.com/example/social-app/server/pkg/response"
)

type MessageHandler struct {
	messageService *service.MessageService
}

func NewMessageHandler(messageService *service.MessageService) *MessageHandler {
	return &MessageHandler{messageService: messageService}
}

func (h *MessageHandler) Send(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	var input service.SendMessageInput
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Invalid request")
		return
	}

	if input.Type == model.MessageTypeText && input.Content == "" {
		response.BadRequest(c, "Content is required for text message")
		return
	}

	message, err := h.messageService.Send(userID, &input)
	if err != nil {
		switch err {
		case service.ErrNotMember:
			response.Forbidden(c, err.Error())
		default:
			response.InternalError(c, "Failed to send message")
		}
		return
	}

	response.Created(c, message)
}

func (h *MessageHandler) List(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	conversationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid conversation ID")
		return
	}

	cursor := c.Query("cursor")
	limit := 20

	result, err := h.messageService.List(conversationID, userID, cursor, limit)
	if err != nil {
		switch err {
		case service.ErrNotMember:
			response.Forbidden(c, err.Error())
		default:
			response.InternalError(c, "Failed to get messages")
		}
		return
	}

	response.Success(c, result)
}

func (h *MessageHandler) Recall(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	messageID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid message ID")
		return
	}

	if err := h.messageService.Recall(messageID, userID); err != nil {
		switch err {
		case service.ErrMessageNotFound:
			response.NotFound(c, err.Error())
		case service.ErrRecallTimeout:
			response.Error(c, 400, "RECALL_TIMEOUT", err.Error())
		default:
			response.InternalError(c, "Failed to recall message")
		}
		return
	}

	response.Success(c, nil)
}