package websocket

import (
	"encoding/json"
	"log"
	"sync"

	"github.com/google/uuid"
)

type Hub struct {
	clients    map[uuid.UUID]*Client
	rooms      map[string]map[uuid.UUID]bool
	register   chan *Client
	unregister chan *Client
	broadcast  chan []byte
	mu         sync.RWMutex
}

type OnlineStatus struct {
	UserID    uuid.UUID `json:"user_id"`
	IsOnline  bool      `json:"is_online"`
	Timestamp int64     `json:"timestamp"`
}

func NewHub() *Hub {
	return &Hub{
		clients:    make(map[uuid.UUID]*Client),
		rooms:      make(map[string]map[uuid.UUID]bool),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		broadcast:  make(chan []byte),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client.userID] = client
			h.mu.Unlock()
			h.broadcastOnlineStatus(client.userID, true)

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client.userID]; ok {
				delete(h.clients, client.userID)
				close(client.send)
				h.mu.Unlock()
				h.broadcastOnlineStatus(client.userID, false)
			} else {
				h.mu.Unlock()
			}

		case message := <-h.broadcast:
			h.mu.RLock()
			for _, client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(h.clients, client.userID)
				}
			}
			h.mu.RUnlock()
		}
	}
}

func (h *Hub) broadcastOnlineStatus(userID uuid.UUID, isOnline bool) {
	statusData := map[string]interface{}{
		"user_id":   userID.String(),
		"is_online": isOnline,
	}
	dataBytes, _ := json.Marshal(statusData)
	msg := WSMessage{
		Event: "user:status",
		Data:  dataBytes,
	}
	data, _ := json.Marshal(msg)

	log.Printf("[WebSocket] Broadcasting online status: user=%s, online=%v", userID.String(), isOnline)

	h.mu.RLock()
	for _, client := range h.clients {
		select {
		case client.send <- data:
		default:
		}
	}
	h.mu.RUnlock()
}

func (h *Hub) SendToUser(userID uuid.UUID, message []byte) {
	h.mu.RLock()
	if client, ok := h.clients[userID]; ok {
		client.send <- message
	}
	h.mu.RUnlock()
}

func (h *Hub) SendToUsers(userIDs []uuid.UUID, message []byte) {
	h.mu.RLock()
	log.Printf("[Hub] SendToUsers: sending to %d users, %d connected", len(userIDs), len(h.clients))
	for _, userID := range userIDs {
		if client, ok := h.clients[userID]; ok {
			log.Printf("[Hub] Sending message to user %s", userID.String())
			select {
			case client.send <- message:
			default:
				log.Printf("[Hub] User %s channel full, skipping", userID.String())
			}
		} else {
			log.Printf("[Hub] User %s not connected", userID.String())
		}
	}
	h.mu.RUnlock()
}

func (h *Hub) Register(client *Client) {
	h.register <- client
}

func (h *Hub) Unregister(client *Client) {
	h.unregister <- client
}

func (h *Hub) IsUserOnline(userID uuid.UUID) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	_, ok := h.clients[userID]
	return ok
}

func (h *Hub) GetOnlineUsers() []uuid.UUID {
	h.mu.RLock()
	defer h.mu.RUnlock()
	var users []uuid.UUID
	for userID := range h.clients {
		users = append(users, userID)
	}
	return users
}

func (h *Hub) BroadcastCallSignal(msg *WSMessage, senderID uuid.UUID, targetUserID *uuid.UUID) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}

	if targetUserID != nil {
		log.Printf("[Call] Sending signal %s to target %s", msg.Event, targetUserID.String())
		h.SendToUser(*targetUserID, data)
		return
	}

	log.Printf("[Call] Broadcasting signal %s from %s to %d clients", msg.Event, senderID.String(), len(h.clients)-1)
	h.mu.RLock()
	for userID, client := range h.clients {
		if userID != senderID {
			select {
			case client.send <- data:
			default:
			}
		}
	}
	h.mu.RUnlock()
}

func (h *Hub) GetConnectionCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

func (h *Hub) GetOnlineUserCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

func (h *Hub) GetActiveRoomCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.rooms)
}
