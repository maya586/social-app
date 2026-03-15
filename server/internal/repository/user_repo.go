package repository

import (
	"github.com/google/uuid"
	"github.com/example/social-app/server/internal/database"
	"github.com/example/social-app/server/internal/model"
)

type UserRepo struct{}

func NewUserRepo() *UserRepo {
	return &UserRepo{}
}

func (r *UserRepo) Create(user *model.User) error {
	return database.DB.Create(user).Error
}

func (r *UserRepo) FindByID(id uuid.UUID) (*model.User, error) {
	var user model.User
	err := database.DB.Where("id = ?", id).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepo) FindByPhone(phone string) (*model.User, error) {
	var user model.User
	err := database.DB.Where("phone = ?", phone).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepo) Update(user *model.User) error {
	return database.DB.Save(user).Error
}

func (r *UserRepo) ExistsByPhone(phone string) (bool, error) {
	var count int64
	err := database.DB.Model(&model.User{}).Where("phone = ?", phone).Count(&count).Error
	return count > 0, err
}

func (r *UserRepo) SearchByNickname(keyword string, limit int) ([]model.User, error) {
	var users []model.User
	err := database.DB.Where("nickname ILIKE ?", "%"+keyword+"%").
		Limit(limit).
		Find(&users).Error
	return users, err
}