package handler

import (
	"encoding/json"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	pionwebrtc "github.com/pion/webrtc/v3"
	"github.com/example/social-app/server/internal/middleware"
	"github.com/example/social-app/server/internal/repository"
	"github.com/example/social-app/server/internal/webrtc"
	"github.com/example/social-app/server/internal/websocket"
	"github.com/example/social-app/server/pkg/response"
)

type CallHandler struct {
	hub            *websocket.Hub
	conversationRepo *repository.ConversationRepo
}

func NewCallHandler(hub *websocket.Hub) *CallHandler {
	return &CallHandler{
		hub:            hub,
		conversationRepo: repository.NewConversationRepo(),
	}
}

type CreateCallInput struct {
	ConversationID uuid.UUID       `json:"conversation_id" binding:"required"`
	CallType       webrtc.CallType `json:"type" binding:"required"`
}

type JoinCallInput struct {
	RoomID uuid.UUID `json:"room_id" binding:"required"`
}

type SignalInput struct {
	RoomID    uuid.UUID                      `json:"room_id" binding:"required"`
	Type      string                         `json:"type" binding:"required"`
	Offer     *pionwebrtc.SessionDescription `json:"offer,omitempty"`
	Answer    *pionwebrtc.SessionDescription `json:"answer,omitempty"`
	Candidate *pionwebrtc.ICECandidateInit   `json:"candidate,omitempty"`
}

// CreateCall godoc
// @Summary 创建通话
// @Description 创建新的音视频通话房间
// @Tags 通话
// @Security BearerAuth
// @Accept json
// @Produce json
// @Param request body CreateCallInput true "通话信息"
// @Success 201 {object} map[string]interface{} "创建成功"
// @Failure 400 {object} map[string]string "参数错误"
// @Router /calls/create [post]
func (h *CallHandler) CreateCall(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	
	var input CreateCallInput
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Invalid request")
		return
	}
	
	sfu := webrtc.GetSFU()
	
	existingRoom, _ := sfu.GetRoomByConversation(input.ConversationID)
	if existingRoom != nil {
		response.Success(c, gin.H{
			"room_id": existingRoom.ID.String(),
			"status":  existingRoom.Status,
		})
		return
	}
	
	room, err := sfu.CreateRoom(input.ConversationID, input.CallType)
	if err != nil {
		response.InternalError(c, "Failed to create call room")
		return
	}
	
	_, err = sfu.JoinRoom(room.ID, userID, nil)
	if err != nil {
		response.InternalError(c, "Failed to join call room")
		return
	}
	
	members, err := h.conversationRepo.GetMembers(input.ConversationID)
	if err == nil {
		notification, _ := json.Marshal(map[string]interface{}{
			"event": "call:incoming",
			"data": map[string]interface{}{
				"room_id":         room.ID.String(),
				"conversation_id": room.ConversationID.String(),
				"caller_id":       userID.String(),
				"type":            room.CallType,
			},
		})
		
		for _, member := range members {
			if member.UserID != userID {
				h.hub.SendToUser(member.UserID, notification)
			}
		}
	}
	
	response.Created(c, gin.H{
		"room_id":         room.ID.String(),
		"conversation_id": room.ConversationID.String(),
		"type":            room.CallType,
		"status":          room.Status,
	})
}

// JoinCall godoc
// @Summary 加入通话
// @Description 加入已有的通话房间
// @Tags 通话
// @Security BearerAuth
// @Accept json
// @Produce json
// @Param request body JoinCallInput true "房间信息"
// @Success 200 {object} map[string]interface{} "加入成功"
// @Failure 400 {object} map[string]string "参数错误"
// @Failure 404 {object} map[string]string "房间不存在"
// @Router /calls/join [post]
func (h *CallHandler) JoinCall(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	
	var input JoinCallInput
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Invalid request")
		return
	}
	
	sfu := webrtc.GetSFU()
	
	room, ok := sfu.GetRoom(input.RoomID)
	if !ok {
		response.NotFound(c, "Call room not found")
		return
	}
	
	if room.Status == webrtc.CallStatusEnded {
		response.Error(c, 400, "CALL_ENDED", "Call has ended")
		return
	}
	
	_, err := sfu.JoinRoom(input.RoomID, userID, nil)
	if err != nil {
		response.InternalError(c, "Failed to join call room")
		return
	}
	
	response.Success(c, gin.H{
		"room_id":         room.ID.String(),
		"conversation_id": room.ConversationID.String(),
		"type":            room.CallType,
		"status":          room.Status,
	})
}

// LeaveCall godoc
// @Summary 离开通话
// @Description 离开通话房间
// @Tags 通话
// @Security BearerAuth
// @Produce json
// @Param room_id path string true "房间ID"
// @Success 200 {object} map[string]interface{} "离开成功"
// @Failure 400 {object} map[string]string "参数错误"
// @Router /calls/{room_id} [delete]
func (h *CallHandler) LeaveCall(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	
	roomID, err := uuid.Parse(c.Param("room_id"))
	if err != nil {
		response.BadRequest(c, "Invalid room ID")
		return
	}
	
	sfu := webrtc.GetSFU()
	sfu.LeaveRoom(roomID, userID)
	
	response.Success(c, nil)
}

// Signal godoc
// @Summary WebRTC信令
// @Description 处理WebRTC信令交换
// @Tags 通话
// @Security BearerAuth
// @Accept json
// @Produce json
// @Param request body SignalInput true "信令数据"
// @Success 200 {object} map[string]interface{} "处理成功"
// @Failure 400 {object} map[string]string "参数错误"
// @Router /calls/signal [post]
func (h *CallHandler) Signal(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	
	var input SignalInput
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Invalid request")
		return
	}
	
	sfu := webrtc.GetSFU()
	
	switch input.Type {
	case "offer":
		if input.Offer == nil {
			response.BadRequest(c, "Offer is required")
			return
		}
		
		answer, err := sfu.ProcessOffer(input.RoomID, userID, *input.Offer)
		if err != nil {
			response.InternalError(c, "Failed to process offer")
			return
		}
		
		response.Success(c, gin.H{
			"type":   "answer",
			"answer": answer,
		})
		
	case "ice-candidate":
		if input.Candidate == nil {
			response.BadRequest(c, "Candidate is required")
			return
		}
		
		err := sfu.AddICECandidate(input.RoomID, userID, *input.Candidate)
		if err != nil {
			response.InternalError(c, "Failed to add ICE candidate")
			return
		}
		
		response.Success(c, nil)
		
	default:
		response.BadRequest(c, "Invalid signal type")
	}
}

// GetCallStats godoc
// @Summary 获取通话统计
// @Description 获取当前所有通话房间的统计信息
// @Tags 通话
// @Security BearerAuth
// @Produce json
// @Success 200 {object} map[string]interface{} "统计信息"
// @Router /calls/stats [get]
func (h *CallHandler) GetCallStats(c *gin.Context) {
	sfu := webrtc.GetSFU()
	stats := sfu.GetStats()
	response.Success(c, stats)
}

// GetICEServers godoc
// @Summary 获取ICE服务器配置
// @Description 获取WebRTC连接所需的ICE服务器列表
// @Tags 通话
// @Security BearerAuth
// @Produce json
// @Success 200 {object} map[string]interface{} "ICE服务器列表"
// @Router /calls/ice-servers [get]
func (h *CallHandler) GetICEServers(c *gin.Context) {
	sfu := webrtc.GetSFU()
	
	servers := make([]map[string]interface{}, 0)
	for _, server := range sfu.GetICEServers() {
		servers = append(servers, map[string]interface{}{
			"urls": server.URLs,
			"username": server.Username,
			"credential": server.Credential,
		})
	}
	
	response.Success(c, map[string]interface{}{
		"ice_servers": servers,
	})
}

func (h *CallHandler) HandleCallSignal(event string, data json.RawMessage, userID uuid.UUID) (interface{}, error) {
	sfu := webrtc.GetSFU()
	
	var signalData struct {
		RoomID    string          `json:"room_id"`
		Offer     json.RawMessage `json:"offer,omitempty"`
		Answer    json.RawMessage `json:"answer,omitempty"`
		Candidate json.RawMessage `json:"candidate,omitempty"`
	}
	
	if err := json.Unmarshal(data, &signalData); err != nil {
		return nil, err
	}
	
	roomID, err := uuid.Parse(signalData.RoomID)
	if err != nil {
		return nil, err
	}
	
	switch event {
	case "call:offer":
		var offer pionwebrtc.SessionDescription
		if err := json.Unmarshal(signalData.Offer, &offer); err != nil {
			return nil, err
		}
		
		answer, err := sfu.ProcessOffer(roomID, userID, offer)
		if err != nil {
			return nil, err
		}
		
		return map[string]interface{}{
			"event": "call:answer",
			"data": map[string]interface{}{
				"room_id": roomID.String(),
				"answer":  answer,
			},
		}, nil
		
	case "call:ice-candidate":
		var candidate pionwebrtc.ICECandidateInit
		if err := json.Unmarshal(signalData.Candidate, &candidate); err != nil {
			return nil, err
		}
		
		err := sfu.AddICECandidate(roomID, userID, candidate)
		if err != nil {
			return nil, err
		}
		
		return nil, nil
		
	case "call:leave":
		sfu.LeaveRoom(roomID, userID)
		return map[string]interface{}{
			"event": "call:left",
			"data": map[string]interface{}{
				"room_id": roomID.String(),
				"user_id": userID.String(),
			},
		}, nil
	}
	
	return nil, nil
}