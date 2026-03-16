package repository

import (
	"github.com/google/uuid"
	"github.com/example/social-app/server/internal/database"
	"github.com/example/social-app/server/internal/model"
)

type DeviceTokenRepo struct{}

func NewDeviceTokenRepo() *DeviceTokenRepo {
	return &DeviceTokenRepo{}
}

func (r *DeviceTokenRepo) Create(token *model.DeviceToken) error {
	return database.DB.Create(token).Error
}

func (r *DeviceTokenRepo) FindByUserID(userID uuid.UUID) ([]model.DeviceToken, error) {
	var tokens []model.DeviceToken
	err := database.DB.Where("user_id = ? AND is_active = ?", userID, true).Find(&tokens).Error
	return tokens, err
}

func (r *DeviceTokenRepo) FindByToken(token string) (*model.DeviceToken, error) {
	var dt model.DeviceToken
	err := database.DB.Where("token = ?", token).First(&dt).Error
	return &dt, err
}

func (r *DeviceTokenRepo) Update(token *model.DeviceToken) error {
	return database.DB.Save(token).Error
}

func (r *DeviceTokenRepo) DeactivateByUserID(userID uuid.UUID) error {
	return database.DB.Model(&model.DeviceToken{}).
		Where("user_id = ?", userID).
		Update("is_active", false).Error
}

func (r *DeviceTokenRepo) DeleteByToken(token string) error {
	return database.DB.Where("token = ?", token).Delete(&model.DeviceToken{}).Error
}