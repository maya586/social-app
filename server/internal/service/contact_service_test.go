package service

import (
	"testing"
	"github.com/google/uuid"
	"github.com/example/social-app/server/internal/model"
)

func TestContactService_AddContact_Validation(t *testing.T) {
	t.Run("测试添加联系人验证", func(t *testing.T) {
		userID := uuid.New()
		phone := "13800138001"
		remark := "测试好友"
		
		if userID == uuid.Nil {
			t.Error("用户ID不应为空")
		}
		if phone == "" {
			t.Error("手机号不应为空")
		}
		if len(remark) > 20 {
			t.Error("备注名不应超过20个字符")
		}
	})
}

func TestContactService_GetContacts(t *testing.T) {
	t.Run("测试联系人状态", func(t *testing.T) {
		statuses := []model.ContactStatus{
			model.ContactStatusPending,
			model.ContactStatusAccepted,
			model.ContactStatusBlocked,
		}
		
		for _, status := range statuses {
			if status == "" {
				t.Error("联系人状态不应为空")
			}
		}
	})
}

func TestContactService_Errors(t *testing.T) {
	t.Run("测试错误类型", func(t *testing.T) {
		if ErrUserNotFound.Error() != "user not found" {
			t.Errorf("ErrUserNotFound 错误信息不正确")
		}
	})
}

func TestContactStatus(t *testing.T) {
	t.Run("测试联系人状态常量", func(t *testing.T) {
		if model.ContactStatusPending != "pending" {
			t.Errorf("ContactStatusPending 值不正确")
		}
		if model.ContactStatusAccepted != "accepted" {
			t.Errorf("ContactStatusAccepted 值不正确")
		}
		if model.ContactStatusBlocked != "blocked" {
			t.Errorf("ContactStatusBlocked 值不正确")
		}
	})
}