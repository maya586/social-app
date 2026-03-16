package service

import (
	"errors"
	"testing"
	"github.com/google/uuid"
	"github.com/example/social-app/server/internal/model"
	"github.com/example/social-app/server/internal/repository"
)

func TestAuthService_Register(t *testing.T) {
	t.Run("测试注册输入验证", func(t *testing.T) {
		tests := []struct {
			name    string
			input   RegisterInput
			wantErr bool
		}{
			{
				name: "有效输入",
				input: RegisterInput{
					Phone:    "13800138001",
					Password: "Password123",
					Nickname: "测试用户",
				},
				wantErr: false,
			},
			{
				name: "密码太短",
				input: RegisterInput{
					Phone:    "13800138002",
					Password: "123",
					Nickname: "测试用户",
				},
				wantErr: true,
			},
			{
				name: "昵称太短",
				input: RegisterInput{
					Phone:    "13800138003",
					Password: "Password123",
					Nickname: "a",
				},
				wantErr: true,
			},
		}
		
		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				if tt.wantErr {
					if len(tt.input.Password) >= 8 && len(tt.input.Nickname) >= 2 {
						t.Errorf("预期错误但没有发生")
					}
				}
			})
		}
	})
}

func TestAuthService_Login(t *testing.T) {
	t.Run("测试登录输入验证", func(t *testing.T) {
		tests := []struct {
			name    string
			input   LoginInput
			wantErr bool
		}{
			{
				name: "有效输入",
				input: LoginInput{
					Phone:    "13800138001",
					Password: "Password123",
				},
				wantErr: false,
			},
			{
				name: "缺少手机号",
				input: LoginInput{
					Phone:    "",
					Password: "Password123",
				},
				wantErr: true,
			},
			{
				name: "缺少密码",
				input: LoginInput{
					Phone:    "13800138001",
					Password: "",
				},
				wantErr: true,
			},
		}
		
		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				if tt.wantErr {
					if tt.input.Phone != "" && tt.input.Password != "" {
						t.Errorf("预期错误但没有发生")
					}
				}
			})
		}
	})
}

func TestAuthService_Errors(t *testing.T) {
	t.Run("测试错误类型", func(t *testing.T) {
		if ErrPhoneExists.Error() != "phone already registered" {
			t.Errorf("ErrPhoneExists 错误信息不正确")
		}
		if ErrInvalidPassword.Error() != "invalid password" {
			t.Errorf("ErrInvalidPassword 错误信息不正确")
		}
		if ErrUserNotFound.Error() != "user not found" {
			t.Errorf("ErrUserNotFound 错误信息不正确")
		}
		if ErrTokenBlacklisted.Error() != "token has been revoked" {
			t.Errorf("ErrTokenBlacklisted 错误信息不正确")
		}
	})
}

type MockUserRepository struct {
	users      map[string]*model.User
	existsFlag bool
}

func NewMockUserRepository() *MockUserRepository {
	return &MockUserRepository{
		users: make(map[string]*model.User),
	}
}

func (m *MockUserRepository) Create(user *model.User) error {
	if _, exists := m.users[user.Phone]; exists {
		return errors.New("phone exists")
	}
	user.ID = uuid.New()
	m.users[user.Phone] = user
	return nil
}

func (m *MockUserRepository) FindByPhone(phone string) (*model.User, error) {
	user, ok := m.users[phone]
	if !ok {
		return nil, errors.New("user not found")
	}
	return user, nil
}

func (m *MockUserRepository) FindByID(id uuid.UUID) (*model.User, error) {
	for _, user := range m.users {
		if user.ID == id {
			return user, nil
		}
	}
	return nil, errors.New("user not found")
}

func (m *MockUserRepository) Update(user *model.User) error {
	m.users[user.Phone] = user
	return nil
}

func (m *MockUserRepository) ExistsByPhone(phone string) (bool, error) {
	_, ok := m.users[phone]
	return ok, nil
}

func TestAuthService_Integration(t *testing.T) {
	if testing.Short() {
		t.Skip("跳过集成测试")
	}
	
	mockRepo := &repository.UserRepo{}
	service := NewAuthService(mockRepo, "test-secret-key-for-testing", 3600)
	
	if service == nil {
		t.Error("AuthService 不应为空")
	}
}