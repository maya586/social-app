package handler

import (
	"encoding/json"
	"log"

	"github.com/example/social-app/server/internal/middleware"
	"github.com/example/social-app/server/internal/model"
	"github.com/example/social-app/server/internal/service"
	"github.com/example/social-app/server/internal/websocket"
	"github.com/example/social-app/server/pkg/response"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"strconv"
)

type MessageHandler struct {
	messageService *service.MessageService
	hub            *websocket.Hub
}

func NewMessageHandler(messageService *service.MessageService) *MessageHandler {
	return &MessageHandler{messageService: messageService}
}

func (h *MessageHandler) SetHub(hub *websocket.Hub) {
	h.hub = hub
}

// Send godoc
// @Summary 发送消息
// @Description 发送消息到会话
// @Tags 消息
// @Security BearerAuth
// @Accept json
// @Produce json
// @Param request body service.SendMessageInput true "消息内容"
// @Success 201 {object} model.Message "发送成功"
// @Failure 400 {object} map[string]string "参数错误"
// @Failure 403 {object} map[string]string "无权限"
// @Router /messages [post]
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

	// Broadcast message to conversation members via WebSocket
	if h.hub != nil {
		members, err := h.messageService.GetConversationMembers(input.ConversationID)
		if err == nil {
			msgData := map[string]interface{}{
				"event": "message:new",
				"data": map[string]interface{}{
					"id":              message.ID,
					"conversation_id": message.ConversationID,
					"sender_id":       message.SenderID,
					"type":            message.Type,
					"content":         message.Content,
					"media_url":       message.MediaURL,
					"created_at":      message.CreatedAt,
				},
			}
			msgBytes, _ := json.Marshal(msgData)
			log.Printf("[Message] Broadcasting to %d members: %s", len(members), string(msgBytes))
			h.hub.SendToUsers(members, msgBytes)
		} else {
			log.Printf("[Message] Failed to get members: %v", err)
		}
	} else {
		log.Println("[Message] Hub is nil, cannot broadcast")
	}

	response.Created(c, message)
}

// List godoc
// @Summary 获取消息列表
// @Description 获取会话的消息列表
// @Tags 消息
// @Security BearerAuth
// @Produce json
// @Param id path string true "会话ID"
// @Param cursor query string false "分页游标"
// @Success 200 {object} map[string]interface{} "消息列表"
// @Failure 400 {object} map[string]string "参数错误"
// @Failure 403 {object} map[string]string "无权限"
// @Router /messages/conversation/{id} [get]
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

// Recall godoc
// @Summary 撤回消息
// @Description 撤回已发送的消息（2分钟内）
// @Tags 消息
// @Security BearerAuth
// @Produce json
// @Param id path string true "消息ID"
// @Success 200 {object} map[string]interface{} "撤回成功"
// @Failure 400 {object} map[string]string "参数错误或超时"
// @Failure 404 {object} map[string]string "消息不存在"
// @Router /messages/{id} [delete]
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

// ListConversations godoc
// @Summary 获取会话列表
// @Description 获取用户的会话列表
// @Tags 会话
// @Security BearerAuth
// @Produce json
// @Param limit query int false "数量限制" default(20)
// @Param offset query int false "偏移量" default(0)
// @Success 200 {array} model.Conversation "会话列表"
// @Router /conversations [get]
func (h *MessageHandler) ListConversations(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	conversations, err := h.messageService.ListConversations(userID, limit, offset)
	if err != nil {
		response.InternalError(c, "Failed to get conversations")
		return
	}

	response.Success(c, conversations)
}

// CreateConversation godoc
// @Summary 创建会话
// @Description 创建新会话（私聊或群聊）
// @Tags 会话
// @Security BearerAuth
// @Accept json
// @Produce json
// @Param request body map[string]interface{} true "会话信息"
// @Success 201 {object} model.Conversation "创建成功"
// @Failure 400 {object} map[string]string "参数错误"
// @Router /conversations [post]
func (h *MessageHandler) CreateConversation(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	var input struct {
		Type      model.ConversationType `json:"type" binding:"required"`
		Name      string                 `json:"name"`
		MemberIDs []uuid.UUID            `json:"member_ids"`
		ContactID uuid.UUID              `json:"contact_id"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Invalid request")
		return
	}

	conversation, err := h.messageService.CreateConversation(userID, input.Type, input.Name, input.MemberIDs, input.ContactID)
	if err != nil {
		response.InternalError(c, "Failed to create conversation")
		return
	}

	response.Created(c, conversation)
}

// GetConversation godoc
// @Summary 获取会话详情
// @Description 获取单个会话的详细信息
// @Tags 会话
// @Security BearerAuth
// @Produce json
// @Param id path string true "会话ID"
// @Success 200 {object} model.Conversation "会话详情"
// @Failure 404 {object} map[string]string "会话不存在"
// @Router /conversations/{id} [get]
func (h *MessageHandler) GetConversation(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	conversationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid conversation ID")
		return
	}

	conversation, err := h.messageService.GetConversation(conversationID, userID)
	if err != nil {
		response.NotFound(c, "Conversation not found")
		return
	}

	response.Success(c, conversation)
}

// MarkAsRead godoc
// @Summary 标记已读
// @Description 标记会话中的消息为已读
// @Tags 消息
// @Security BearerAuth
// @Produce json
// @Param id path string true "会话ID"
// @Success 200 {object} map[string]interface{} "标记成功"
// @Failure 400 {object} map[string]string "参数错误"
// @Router /messages/conversation/{id}/read [put]
func (h *MessageHandler) MarkAsRead(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	conversationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid conversation ID")
		return
	}

	if err := h.messageService.MarkAsRead(conversationID, userID); err != nil {
		response.InternalError(c, "Failed to mark as read")
		return
	}

	response.Success(c, nil)
}

// ClearConversation godoc
// @Summary 清空会话消息
// @Description 清空会话中的所有消息
// @Tags 消息
// @Security BearerAuth
// @Produce json
// @Param id path string true "会话ID"
// @Success 200 {object} map[string]interface{} "清空成功"
// @Failure 400 {object} map[string]string "参数错误"
// @Router /messages/conversation/{id} [delete]
func (h *MessageHandler) ClearConversation(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	conversationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid conversation ID")
		return
	}

	if err := h.messageService.ClearConversation(conversationID, userID); err != nil {
		switch err {
		case service.ErrNotMember:
			response.Forbidden(c, err.Error())
		default:
			response.InternalError(c, "Failed to clear conversation")
		}
		return
	}

	response.Success(c, nil)
}
