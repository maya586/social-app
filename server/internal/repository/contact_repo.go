package repository

import (
	"github.com/example/social-app/server/internal/database"
	"github.com/example/social-app/server/internal/model"
	"github.com/google/uuid"
)

type ContactRepo struct{}

func NewContactRepo() *ContactRepo {
	return &ContactRepo{}
}

func (r *ContactRepo) Create(contact *model.Contact) error {
	return database.DB.Create(contact).Error
}

func (r *ContactRepo) FindByID(id uuid.UUID) (*model.Contact, error) {
	var contact model.Contact
	err := database.DB.Where("id = ?", id).First(&contact).Error
	return &contact, err
}

func (r *ContactRepo) FindByUserAndContact(userID, contactID uuid.UUID) (*model.Contact, error) {
	var contact model.Contact
	err := database.DB.Where("user_id = ? AND contact_id = ?", userID, contactID).First(&contact).Error
	return &contact, err
}

func (r *ContactRepo) ListByUserID(userID uuid.UUID, limit, offset int) ([]model.Contact, error) {
	var contacts []model.Contact
	err := database.DB.Where("user_id = ? AND status = ?", userID, model.ContactStatusAccepted).
		Preload("ContactUser").
		Limit(limit).Offset(offset).
		Find(&contacts).Error
	return contacts, err
}

func (r *ContactRepo) ListPendingByUserID(userID uuid.UUID) ([]model.Contact, error) {
	var contacts []model.Contact
	err := database.DB.Where("contact_id = ? AND status = ?", userID, model.ContactStatusPending).
		Preload("ContactUser").
		Find(&contacts).Error
	return contacts, err
}

func (r *ContactRepo) Update(contact *model.Contact) error {
	return database.DB.Save(contact).Error
}

func (r *ContactRepo) Delete(id uuid.UUID) error {
	return database.DB.Delete(&model.Contact{}, id).Error
}

func (r *ContactRepo) ExistsRelation(userID, contactID uuid.UUID) (bool, error) {
	var count int64
	err := database.DB.Model(&model.Contact{}).
		Where("user_id = ? AND contact_id = ?", userID, contactID).
		Count(&count).Error
	return count > 0, err
}
