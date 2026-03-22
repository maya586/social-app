package repository

import (
	"time"

	"github.com/example/social-app/server/internal/database"
	"github.com/example/social-app/server/internal/model"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type AdminRepo struct {
	db *gorm.DB
}

func NewAdminRepo() *AdminRepo {
	return &AdminRepo{
		db: database.DB,
	}
}

func (r *AdminRepo) FindByUsername(username string) (*model.Admin, error) {
	var admin model.Admin
	err := r.db.Where("username = ?", username).First(&admin).Error
	if err != nil {
		return nil, err
	}
	return &admin, nil
}

func (r *AdminRepo) FindByID(id uuid.UUID) (*model.Admin, error) {
	var admin model.Admin
	err := r.db.First(&admin, id).Error
	if err != nil {
		return nil, err
	}
	return &admin, nil
}

func (r *AdminRepo) UpdateLastLogin(id uuid.UUID) error {
	return r.db.Model(&model.Admin{}).Where("id = ?", id).Update("last_login_at", gorm.Expr("NOW()")).Error
}

func (r *AdminRepo) GetConfig(key string) (*model.SystemConfig, error) {
	var config model.SystemConfig
	err := r.db.First(&config, key).Error
	if err != nil {
		return nil, err
	}
	return &config, nil
}

func (r *AdminRepo) SetConfig(key, value string) error {
	return r.db.Model(&model.SystemConfig{}).Where("key = ?", key).Update("value", value).Error
}

func (r *AdminRepo) GetAllConfigs() ([]model.SystemConfig, error) {
	var configs []model.SystemConfig
	err := r.db.Find(&configs).Error
	return configs, err
}

func (r *AdminRepo) GetUserStats() (totalUsers int64, todayNewUsers int64, onlineUsers int64, err error) {
	err = r.db.Model(&model.User{}).Count(&totalUsers).Error
	if err != nil {
		return
	}

	err = r.db.Model(&model.User{}).Where("created_at >= CURRENT_DATE").Count(&todayNewUsers).Error
	if err != nil {
		return
	}

	return totalUsers, todayNewUsers, 0, nil
}

func (r *AdminRepo) GetMessageStats() (totalMessages int64, todayMessages int64, err error) {
	err = r.db.Model(&model.Message{}).Count(&totalMessages).Error
	if err != nil {
		return
	}

	err = r.db.Model(&model.Message{}).Where("created_at >= CURRENT_DATE").Count(&todayMessages).Error
	return totalMessages, todayMessages, err
}

func (r *AdminRepo) GetUserTrend(days int) ([]int64, error) {
	var trends []int64
	for i := days - 1; i >= 0; i-- {
		var count int64
		date := time.Now().AddDate(0, 0, -i).Format("2006-01-02")
		err := r.db.Model(&model.User{}).
			Where("DATE(created_at) = ?", date).
			Count(&count).Error
		if err != nil {
			return nil, err
		}
		trends = append(trends, count)
	}
	return trends, nil
}

func (r *AdminRepo) GetMessageTrend(days int) ([]int64, error) {
	var trends []int64
	for i := days - 1; i >= 0; i-- {
		var count int64
		date := time.Now().AddDate(0, 0, -i).Format("2006-01-02")
		err := r.db.Model(&model.Message{}).
			Where("DATE(created_at) = ?", date).
			Count(&count).Error
		if err != nil {
			return nil, err
		}
		trends = append(trends, count)
	}
	return trends, nil
}

func (r *AdminRepo) GetUserChatStats(userID string) (map[string]interface{}, error) {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, err
	}

	stats := make(map[string]interface{})

	var sentCount int64
	r.db.Model(&model.Message{}).Where("sender_id = ?", uid).Count(&sentCount)
	stats["sent_messages"] = sentCount

	var receivedCount int64
	r.db.Model(&model.Message{}).
		Joins("JOIN conversation_members cm ON messages.conversation_id = cm.conversation_id").
		Where("cm.user_id = ? AND messages.sender_id != ?", uid, uid).
		Count(&receivedCount)
	stats["received_messages"] = receivedCount

	var convCount int64
	r.db.Model(&model.ConversationMember{}).Where("user_id = ?", uid).Count(&convCount)
	stats["conversations"] = convCount

	var friendCount int64
	r.db.Model(&model.Contact{}).Where("user_id = ? AND status = ?", uid, "accepted").Count(&friendCount)
	stats["friends"] = friendCount

	stats["storage_bytes"] = int64(0)

	typeDist := make(map[string]int64)
	var textCount, imageCount, voiceCount, fileCount int64
	r.db.Model(&model.Message{}).Where("sender_id = ? AND type = ?", uid, "text").Count(&textCount)
	r.db.Model(&model.Message{}).Where("sender_id = ? AND type = ?", uid, "image").Count(&imageCount)
	r.db.Model(&model.Message{}).Where("sender_id = ? AND type = ?", uid, "voice").Count(&voiceCount)
	r.db.Model(&model.Message{}).Where("sender_id = ? AND type = ?", uid, "file").Count(&fileCount)
	typeDist["text"] = textCount
	typeDist["image"] = imageCount
	typeDist["voice"] = voiceCount
	typeDist["file"] = fileCount
	stats["type_distribution"] = typeDist

	return stats, nil
}

func (r *AdminRepo) GetUserConversations(userID string) ([]map[string]interface{}, error) {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, err
	}

	var members []model.ConversationMember
	r.db.Where("user_id = ?", uid).Find(&members)

	var result []map[string]interface{}
	for _, member := range members {
		var msgCount int64
		r.db.Model(&model.Message{}).Where("conversation_id = ?", member.ConversationID).Count(&msgCount)

		var lastMsg model.Message
		r.db.Where("conversation_id = ?", member.ConversationID).Order("created_at desc").First(&lastMsg)

		result = append(result, map[string]interface{}{
			"id":            member.ConversationID,
			"type":          "private",
			"message_count": msgCount,
			"last_message":  lastMsg.Content,
		})
	}

	return result, nil
}

func (r *AdminRepo) GetConversationMessages(conversationID string, page, pageSize int) ([]model.Message, int64, error) {
	var messages []model.Message
	var total int64

	cid, err := uuid.Parse(conversationID)
	if err != nil {
		return nil, 0, err
	}

	r.db.Model(&model.Message{}).Where("conversation_id = ?", cid).Count(&total)

	offset := (page - 1) * pageSize
	err = r.db.Where("conversation_id = ?", cid).
		Order("created_at desc").
		Offset(offset).Limit(pageSize).
		Find(&messages).Error

	return messages, total, err
}
