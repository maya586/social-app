package repository

import (
	"github.com/example/social-app/server/internal/database"
	"github.com/example/social-app/server/internal/model"
	"github.com/google/uuid"
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

type UserListFilter struct {
	Status   string
	Keyword  string
	Page     int
	PageSize int
}

func (r *UserRepo) ListUsers(filter *UserListFilter) ([]model.User, int64, error) {
	var users []model.User
	var total int64

	query := database.DB.Model(&model.User{})

	if filter.Status != "" {
		query = query.Where("status = ?", filter.Status)
	}

	if filter.Keyword != "" {
		query = query.Where("nickname ILIKE ? OR phone ILIKE ?", "%"+filter.Keyword+"%", "%"+filter.Keyword+"%")
	}

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (filter.Page - 1) * filter.PageSize
	if err := query.Offset(offset).Limit(filter.PageSize).Order("created_at desc").Find(&users).Error; err != nil {
		return nil, 0, err
	}

	return users, total, nil
}

func (r *UserRepo) UpdateStatus(id uuid.UUID, status model.UserStatus) error {
	return database.DB.Model(&model.User{}).Where("id = ?", id).Update("status", status).Error
}
