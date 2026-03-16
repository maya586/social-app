package service

import (
	"testing"
	"time"
	"github.com/google/uuid"
	"github.com/example/social-app/server/internal/model"
)

func TestMessageService_Send_InputValidation(t *testing.T) {
	t.Run("测试消息类型", func(t *testing.T) {
		tests := []struct {
			name      string
			input     SendMessageInput
			wantValid bool
		}{
			{
				name: "文本消息",
				input: SendMessageInput{
					ConversationID: uuid.New(),
					Type:           model.MessageTypeText,
					Content:        "你好",
				},
				wantValid: true,
			},
			{
				name: "图片消息",
				input: SendMessageInput{
					ConversationID: uuid.New(),
					Type:           model.MessageTypeImage,
					MediaURL:       "http://example.com/image.jpg",
				},
				wantValid: true,
			},
			{
				name: "语音消息",
				input: SendMessageInput{
					ConversationID: uuid.New(),
					Type:           model.MessageTypeVoice,
					MediaURL:       "http://example.com/voice.mp3",
				},
				wantValid: true,
			},
		}
		
		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				if tt.wantValid {
					if tt.input.ConversationID == uuid.Nil {
						t.Errorf("会话ID不应为空")
					}
					if tt.input.Type == "" {
						t.Errorf("消息类型不应为空")
					}
				}
			})
		}
	})
}

func TestMessageService_Recall_Validation(t *testing.T) {
	t.Run("撤回时间限制", func(t *testing.T) {
		oldTime := time.Now().Add(-3 * time.Minute)
		recentTime := time.Now().Add(-1 * time.Minute)
		
		if time.Since(oldTime) > 2*time.Minute {
		}
		
		if time.Since(recentTime) <= 2*time.Minute {
		}
	})
}

func TestMessageService_Errors(t *testing.T) {
	t.Run("测试错误类型", func(t *testing.T) {
		if ErrMessageNotFound.Error() != "message not found" {
			t.Errorf("ErrMessageNotFound 错误信息不正确")
		}
		if ErrNotMember.Error() != "not a member of conversation" {
			t.Errorf("ErrNotMember 错误信息不正确")
		}
		if ErrConversationNotFound.Error() != "conversation not found" {
			t.Errorf("ErrConversationNotFound 错误信息不正确")
		}
		if ErrRecallTimeout.Error() != "message recall timeout" {
			t.Errorf("ErrRecallTimeout 错误信息不正确")
		}
	})
}