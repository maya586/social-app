package handler

import (
	"encoding/json"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	pionwebrtc "github.com/pion/webrtc/v3"
	"github.com/example/social-app/server/internal/middleware"
	"github.com/example/social-app/server/internal/webrtc"
	"github.com/example/social-app/server/pkg/response"
)

type CallHandler struct{}

func NewCallHandler() *CallHandler {
	return &CallHandler{}
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
	
	response.Created(c, gin.H{
		"room_id":         room.ID.String(),
		"conversation_id": room.ConversationID.String(),
		"type":            room.CallType,
		"status":          room.Status,
	})
}

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

func (h *CallHandler) GetCallStats(c *gin.Context) {
	sfu := webrtc.GetSFU()
	stats := sfu.GetStats()
	response.Success(c, stats)
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