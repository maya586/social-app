package webrtc

import (
	"encoding/json"
	"log"
	"sync"
	"time"
	"github.com/google/uuid"
	"github.com/pion/webrtc/v3"
	"github.com/example/social-app/server/internal/config"
)

type SFU struct {
	rooms       map[uuid.UUID]*CallRoom
	api         *webrtc.API
	mu          sync.RWMutex
	iceServers  []webrtc.ICEServer
}

var sfuInstance *SFU
var sfuOnce sync.Once

func GetSFU() *SFU {
	sfuOnce.Do(func() {
		sfuInstance = &SFU{
			rooms:      make(map[uuid.UUID]*CallRoom),
			api:        webrtc.NewAPI(),
			iceServers: buildICEServers(),
		}
	})
	return sfuInstance
}

func buildICEServers() []webrtc.ICEServer {
	cfg := config.Load()
	var servers []webrtc.ICEServer
	
	for _, stun := range cfg.WebRTC.STUNServers {
		servers = append(servers, webrtc.ICEServer{
			URLs: []string{stun},
		})
	}
	
	for _, turn := range cfg.WebRTC.TURNServers {
		servers = append(servers, webrtc.ICEServer{
			URLs:           []string{turn.URL},
			Username:       turn.Username,
			Credential:     turn.Password,
			CredentialType: webrtc.ICECredentialTypePassword,
		})
	}
	
	return servers
}

func (s *SFU) CreateRoom(conversationID uuid.UUID, callType CallType) (*CallRoom, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	roomID := uuid.New()
	room := NewCallRoom(roomID, conversationID, callType)
	s.rooms[roomID] = room
	
	log.Printf("Created call room: %s for conversation: %s", roomID, conversationID)
	return room, nil
}

func (s *SFU) GetRoom(roomID uuid.UUID) (*CallRoom, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	room, ok := s.rooms[roomID]
	return room, ok
}

func (s *SFU) RemoveRoom(roomID uuid.UUID) {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	if room, ok := s.rooms[roomID]; ok {
		for _, p := range room.Participants {
			if p.PeerConnection != nil {
				p.PeerConnection.Close()
			}
		}
		delete(s.rooms, roomID)
		log.Printf("Removed call room: %s", roomID)
	}
}

func (s *SFU) JoinRoom(roomID, userID uuid.UUID, onTrack func(track *webrtc.TrackRemote, receiver *webrtc.RTPReceiver)) (*webrtc.PeerConnection, error) {
	s.mu.RLock()
	room, ok := s.rooms[roomID]
	s.mu.RUnlock()
	
	if !ok {
		return nil, ErrRoomNotFound
	}
	
	peerConnection, err := s.api.NewPeerConnection(webrtc.Configuration{
		ICEServers: s.iceServers,
	})
	if err != nil {
		return nil, err
	}
	
	_, err = peerConnection.AddTransceiverFromKind(webrtc.RTPCodecTypeAudio, webrtc.RTPTransceiverInit{
		Direction: webrtc.RTPTransceiverDirectionRecvonly,
	})
	if err != nil {
		return nil, err
	}
	
	if room.CallType == CallTypeVideo {
		_, err = peerConnection.AddTransceiverFromKind(webrtc.RTPCodecTypeVideo, webrtc.RTPTransceiverInit{
			Direction: webrtc.RTPTransceiverDirectionRecvonly,
		})
		if err != nil {
			return nil, err
		}
	}
	
	peerConnection.OnTrack(func(track *webrtc.TrackRemote, receiver *webrtc.RTPReceiver) {
		log.Printf("Got track from user %s: %s", userID, track.Kind())
		if onTrack != nil {
			onTrack(track, receiver)
		}
	})
	
	peerConnection.OnICECandidate(func(candidate *webrtc.ICECandidate) {
		if candidate == nil {
			return
		}
		log.Printf("ICE candidate for user %s: %s", userID, candidate.String())
	})
	
	peerConnection.OnConnectionStateChange(func(state webrtc.PeerConnectionState) {
		log.Printf("Connection state changed for user %s: %s", userID, state)
		if state == webrtc.PeerConnectionStateDisconnected || 
		   state == webrtc.PeerConnectionStateFailed ||
		   state == webrtc.PeerConnectionStateClosed {
			room.RemoveParticipant(userID)
			if room.ParticipantCount() == 0 {
				s.RemoveRoom(roomID)
			}
		}
	})
	
	room.AddParticipant(userID, peerConnection)
	
	return peerConnection, nil
}

func (s *SFU) LeaveRoom(roomID, userID uuid.UUID) {
	s.mu.RLock()
	room, ok := s.rooms[roomID]
	s.mu.RUnlock()
	
	if !ok {
		return
	}
	
	room.RemoveParticipant(userID)
	
	if room.ParticipantCount() == 0 {
		s.RemoveRoom(roomID)
	}
}

func (s *SFU) ProcessOffer(roomID, userID uuid.UUID, offer webrtc.SessionDescription) (*webrtc.SessionDescription, error) {
	s.mu.RLock()
	room, ok := s.rooms[roomID]
	s.mu.RUnlock()
	
	if !ok {
		return nil, ErrRoomNotFound
	}
	
	participant, ok := room.GetParticipant(userID)
	if !ok {
		return nil, ErrParticipantNotFound
	}
	
	if err := participant.PeerConnection.SetRemoteDescription(offer); err != nil {
		return nil, err
	}
	
	answer, err := participant.PeerConnection.CreateAnswer(nil)
	if err != nil {
		return nil, err
	}
	
	if err := participant.PeerConnection.SetLocalDescription(answer); err != nil {
		return nil, err
	}
	
	return &answer, nil
}

func (s *SFU) AddICECandidate(roomID, userID uuid.UUID, candidate webrtc.ICECandidateInit) error {
	s.mu.RLock()
	room, ok := s.rooms[roomID]
	s.mu.RUnlock()
	
	if !ok {
		return ErrRoomNotFound
	}
	
	participant, ok := room.GetParticipant(userID)
	if !ok {
		return ErrParticipantNotFound
	}
	
	return participant.PeerConnection.AddICECandidate(candidate)
}

func (s *SFU) GetRoomByConversation(conversationID uuid.UUID) (*CallRoom, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	for _, room := range s.rooms {
		if room.ConversationID == conversationID && room.Status == CallStatusCalling {
			return room, true
		}
	}
	return nil, false
}

var (
	ErrRoomNotFound       = &CallError{Message: "room not found"}
	ErrParticipantNotFound = &CallError{Message: "participant not found"}
)

type CallError struct {
	Message string
}

func (e *CallError) Error() string {
	return e.Message
}

func (s *SFU) GetStats() map[string]interface{} {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	rooms := make([]map[string]interface{}, 0)
	for id, room := range s.rooms {
		rooms = append(rooms, map[string]interface{}{
			"id":              id.String(),
			"conversation_id": room.ConversationID.String(),
			"type":            room.CallType,
			"status":          room.Status,
			"participants":    room.ParticipantCount(),
			"created_at":      room.CreatedAt.Format(time.RFC3339),
		})
	}
	
	return map[string]interface{}{
		"total_rooms": len(s.rooms),
		"rooms":       rooms,
	}
}

func (s *SFU) GetICEServers() []webrtc.ICEServer {
	return s.iceServers
}

func (s *SFU) BroadcastToRoom(roomID uuid.UUID, event string, data interface{}) error {
	s.mu.RLock()
	room, ok := s.rooms[roomID]
	s.mu.RUnlock()
	
	if !ok {
		return ErrRoomNotFound
	}
	
	message, err := json.Marshal(map[string]interface{}{
		"event": event,
		"data":  data,
	})
	if err != nil {
		return err
	}
	
	for _, p := range room.Participants {
		if p.PeerConnection != nil {
			log.Printf("Broadcasting to participant: %s", p.UserID)
		}
	}
	
	log.Printf("Broadcast to room %s: %s", roomID, string(message))
	return nil
}