package websocket

import (
	"encoding/json"
	"time"
	gorillaws "github.com/gorilla/websocket"
	"github.com/google/uuid"
)

type Client struct {
	hub    *Hub
	conn   *gorillaws.Conn
	send   chan []byte
	userID uuid.UUID
}

type WSMessage struct {
	Event string      `json:"event"`
	Data  interface{} `json:"data"`
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
	switch msg.Event {
	case "ping":
		c.send <- []byte(`{"event":"pong"}`)
	case "sync":
		// Client requests message sync after reconnection
		// The actual sync is handled by the handler layer
		c.send <- []byte(`{"event":"sync:ack"}`)
	case "call:offer", "call:answer", "call:ice-candidate", "call:join", "call:leave":
		c.hub.BroadcastCallSignal(msg, c.userID)
	}
}