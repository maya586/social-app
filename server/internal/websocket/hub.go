package websocket

import (
	"encoding/json"
	"sync"
	"github.com/google/uuid"
)

type Hub struct {
	clients    map[uuid.UUID]*Client
	register   chan *Client
	unregister chan *Client
	broadcast  chan []byte
	mu         sync.RWMutex
}

func NewHub() *Hub {
	return &Hub{
		clients:    make(map[uuid.UUID]*Client),
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

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client.userID]; ok {
				delete(h.clients, client.userID)
				close(client.send)
			}
			h.mu.Unlock()

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

func (h *Hub) SendToUser(userID uuid.UUID, message []byte) {
	h.mu.RLock()
	if client, ok := h.clients[userID]; ok {
		client.send <- message
	}
	h.mu.RUnlock()
}

func (h *Hub) SendToUsers(userIDs []uuid.UUID, message []byte) {
	h.mu.RLock()
	for _, userID := range userIDs {
		if client, ok := h.clients[userID]; ok {
			client.send <- message
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

func (h *Hub) BroadcastCallSignal(msg *WSMessage, senderID uuid.UUID) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	
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