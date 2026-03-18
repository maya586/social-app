package websocket

import (
	"encoding/json"
	"log"

	"github.com/google/uuid"
	gorillaws "github.com/gorilla/websocket"
	"time"
)

type Client struct {
	hub    *Hub
	conn   *gorillaws.Conn
	send   chan []byte
	userID uuid.UUID
}

type WSMessage struct {
	Event string          `json:"event"`
	Data  json.RawMessage `json:"data"`
}

type CallSignalData struct {
	RoomID         string                 `json:"room_id,omitempty"`
	ConversationID string                 `json:"conversation_id,omitempty"`
	IsVideo        bool                   `json:"is_video,omitempty"`
	TargetUserID   string                 `json:"target_user_id,omitempty"`
	Type           string                 `json:"type,omitempty"`
	SDP            string                 `json:"sdp,omitempty"`
	Candidate      map[string]interface{} `json:"candidate,omitempty"`
}

func NewClient(hub *Hub, conn *gorillaws.Conn, userID uuid.UUID) *Client {
	return &Client{
		hub:    hub,
		conn:   conn,
		send:   make(chan []byte, 256),
		userID: userID,
	}
}

func (c *Client) ReadPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			break
		}
		var msg WSMessage
		if err := json.Unmarshal(message, &msg); err != nil {
			continue
		}
		c.handleMessage(&msg)
	}
}

func (c *Client) WritePump() {
	ticker := time.NewTicker(30 * time.Second)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				c.conn.WriteMessage(gorillaws.CloseMessage, []byte{})
				return
			}
			c.conn.WriteMessage(gorillaws.TextMessage, message)

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(gorillaws.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (c *Client) handleMessage(msg *WSMessage) {
	log.Printf("[WebSocket] Received message: event=%s, userID=%s", msg.Event, c.userID.String())

	switch msg.Event {
	case "ping":
		c.send <- []byte(`{"event":"pong"}`)
	case "sync":
		c.send <- []byte(`{"event":"sync:ack"}`)

	case "call:offer":
		var data CallSignalData
		if err := json.Unmarshal(msg.Data, &data); err != nil {
			return
		}
		log.Printf("[Call] Offer received from %s, room=%s", c.userID.String(), data.RoomID)
		c.broadcastCallSignalWithSender(msg, c.userID.String())

	case "call:answer":
		var data CallSignalData
		if err := json.Unmarshal(msg.Data, &data); err != nil {
			return
		}
		log.Printf("[Call] Answer received from %s, target=%s", c.userID.String(), data.TargetUserID)
		if data.TargetUserID != "" {
			c.sendCallSignalToTarget(msg, c.userID.String(), data.TargetUserID)
		}

	case "call:ice-candidate":
		var data CallSignalData
		if err := json.Unmarshal(msg.Data, &data); err != nil {
			return
		}
		c.broadcastCallSignalWithSender(msg, c.userID.String())

	case "call:leave", "call:end":
		var data CallSignalData
		if err := json.Unmarshal(msg.Data, &data); err != nil {
			return
		}
		log.Printf("[Call] Call ended by %s, room=%s", c.userID.String(), data.RoomID)
		c.broadcastCallSignalWithSender(msg, c.userID.String())

	case "call:join":
		c.broadcastCallSignalWithSender(msg, c.userID.String())
	}
}

func (c *Client) broadcastCallSignalWithSender(msg *WSMessage, senderID string) {
	var dataMap map[string]interface{}
	if err := json.Unmarshal(msg.Data, &dataMap); err != nil {
		return
	}
	dataMap["sender_id"] = senderID

	updatedData, _ := json.Marshal(dataMap)
	updatedMsg := WSMessage{
		Event: msg.Event,
		Data:  updatedData,
	}

	c.hub.BroadcastCallSignal(&updatedMsg, c.userID, nil)
}

func (c *Client) sendCallSignalToTarget(msg *WSMessage, senderID string, targetUserID string) {
	var dataMap map[string]interface{}
	if err := json.Unmarshal(msg.Data, &dataMap); err != nil {
		return
	}
	dataMap["sender_id"] = senderID

	updatedData, _ := json.Marshal(dataMap)
	updatedMsg := WSMessage{
		Event: msg.Event,
		Data:  updatedData,
	}

	if targetID, err := uuid.Parse(targetUserID); err == nil {
		c.hub.BroadcastCallSignal(&updatedMsg, c.userID, &targetID)
	}
}
