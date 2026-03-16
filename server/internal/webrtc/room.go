package webrtc

import (
	"sync"
	"time"
	"github.com/google/uuid"
	"github.com/pion/webrtc/v3"
)

type CallType string

const (
	CallTypeAudio CallType = "audio"
	CallTypeVideo CallType = "video"
)

type CallStatus string

const (
	CallStatusCalling   CallStatus = "calling"
	CallStatusConnected  CallStatus = "connected"
	CallStatusEnded      CallStatus = "ended"
	CallStatusMissed     CallStatus = "missed"
)

type Participant struct {
	UserID         uuid.UUID
	PeerConnection *webrtc.PeerConnection
	Track          *webrtc.TrackLocalStaticRTP
	IsMuted        bool
	IsVideoOff     bool
}

type CallRoom struct {
	ID             uuid.UUID
	ConversationID uuid.UUID
	CallType       CallType
	Status         CallStatus
	Participants   map[uuid.UUID]*Participant
	CreatedAt      time.Time
	mu             sync.RWMutex
}

func NewCallRoom(id, conversationID uuid.UUID, callType CallType) *CallRoom {
	return &CallRoom{
		ID:             id,
		ConversationID: conversationID,
		CallType:       callType,
		Status:         CallStatusCalling,
		Participants:   make(map[uuid.UUID]*Participant),
		CreatedAt:      time.Now(),
	}
}

func (r *CallRoom) AddParticipant(userID uuid.UUID, pc *webrtc.PeerConnection) {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	r.Participants[userID] = &Participant{
		UserID:         userID,
		PeerConnection: pc,
		IsMuted:        false,
		IsVideoOff:     false,
	}
}

func (r *CallRoom) RemoveParticipant(userID uuid.UUID) {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	if p, ok := r.Participants[userID]; ok {
		if p.PeerConnection != nil {
			p.PeerConnection.Close()
		}
		delete(r.Participants, userID)
	}
}

func (r *CallRoom) GetParticipant(userID uuid.UUID) (*Participant, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	p, ok := r.Participants[userID]
	return p, ok
}

func (r *CallRoom) GetOtherParticipants(userID uuid.UUID) []*Participant {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	var others []*Participant
	for id, p := range r.Participants {
		if id != userID {
			others = append(others, p)
		}
	}
	return others
}

func (r *CallRoom) ParticipantCount() int {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.Participants)
}

func (r *CallRoom) SetStatus(status CallStatus) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.Status = status
}