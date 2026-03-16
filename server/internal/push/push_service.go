package push

import (
	"context"
	"log"
	"sync"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

type PushService struct {
	client *messaging.Client
	mu     sync.RWMutex
}

var pushService *PushService
var pushOnce sync.Once

func GetPushService() *PushService {
	pushOnce.Do(func() {
		pushService = &PushService{}
	})
	return pushService
}

func (s *PushService) Init(credentialFile string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	opt := option.WithCredentialsFile(credentialFile)
	app, err := firebase.NewApp(context.Background(), nil, opt)
	if err != nil {
		log.Printf("Failed to initialize Firebase app: %v", err)
		return err
	}
	
	client, err := app.Messaging(context.Background())
	if err != nil {
		log.Printf("Failed to get Messaging client: %v", err)
		return err
	}
	
	s.client = client
	log.Println("Firebase push notification service initialized")
	return nil
}

type PushMessage struct {
	Token       string            `json:"token"`
	Title       string            `json:"title"`
	Body        string            `json:"body"`
	Data        map[string]string `json:"data"`
	Topic       string            `json:"topic,omitempty"`
}

func (s *PushService) Send(message *PushMessage) (string, error) {
	if s.client == nil {
		return "", ErrPushNotInitialized
	}
	
	msg := &messaging.Message{
		Notification: &messaging.Notification{
			Title: message.Title,
			Body:  message.Body,
		},
		Data: message.Data,
	}
	
	if message.Token != "" {
		msg.Token = message.Token
	}
	if message.Topic != "" {
		msg.Topic = message.Topic
	}
	
	response, err := s.client.Send(context.Background(), msg)
	if err != nil {
		log.Printf("Failed to send push notification: %v", err)
		return "", err
	}
	
	return response, nil
}

func (s *PushService) SendMulticast(messages []*PushMessage) (*messaging.BatchResponse, error) {
	if s.client == nil {
		return nil, ErrPushNotInitialized
	}
	
	var tokens []string
	var notification *messaging.Notification
	var data map[string]string
	
	for _, msg := range messages {
		if msg.Token != "" {
			tokens = append(tokens, msg.Token)
		}
		if notification == nil && msg.Title != "" {
			notification = &messaging.Notification{
				Title: msg.Title,
				Body:  msg.Body,
			}
			data = msg.Data
		}
	}
	
	if len(tokens) == 0 {
		return nil, ErrNoTokens
	}
	
	msg := &messaging.MulticastMessage{
		Tokens:       tokens,
		Notification: notification,
		Data:         data,
	}
	
	response, err := s.client.SendEachForMulticast(context.Background(), msg)
	if err != nil {
		log.Printf("Failed to send multicast push notification: %v", err)
		return nil, err
	}
	
	return response, nil
}

func (s *PushService) SubscribeToTopic(tokens []string, topic string) error {
	if s.client == nil {
		return ErrPushNotInitialized
	}
	
	response, err := s.client.SubscribeToTopic(context.Background(), tokens, topic)
	if err != nil {
		log.Printf("Failed to subscribe to topic: %v", err)
		return err
	}
	
	if response.FailureCount > 0 {
		log.Printf("Some tokens failed to subscribe: %d failures", response.FailureCount)
	}
	
	return nil
}

func (s *PushService) UnsubscribeFromTopic(tokens []string, topic string) error {
	if s.client == nil {
		return ErrPushNotInitialized
	}
	
	response, err := s.client.UnsubscribeFromTopic(context.Background(), tokens, topic)
	if err != nil {
		log.Printf("Failed to unsubscribe from topic: %v", err)
		return err
	}
	
	if response.FailureCount > 0 {
		log.Printf("Some tokens failed to unsubscribe: %d failures", response.FailureCount)
	}
	
	return nil
}

var (
	ErrPushNotInitialized = &PushError{Message: "push service not initialized"}
	ErrNoTokens           = &PushError{Message: "no tokens provided"}
)

type PushError struct {
	Message string
}

func (e *PushError) Error() string {
	return e.Message
}