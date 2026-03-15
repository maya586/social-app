package service

import (
	"errors"
	"github.com/google/uuid"
	"github.com/example/social-app/server/internal/model"
	"github.com/example/social-app/server/internal/repository"
)

var (
	ErrContactAlreadyExists = errors.New("contact already exists")
	ErrContactNotFound      = errors.New("contact not found")
	ErrCannotAddSelf        = errors.New("cannot add yourself as contact")
)

type ContactService struct {
	contactRepo *repository.ContactRepo
	userRepo    *repository.UserRepo
}

func NewContactService(contactRepo *repository.ContactRepo, userRepo *repository.UserRepo) *ContactService {
	return &ContactService{
		contactRepo: contactRepo,
		userRepo:    userRepo,
	}
}

type AddContactInput struct {
	ContactID uuid.UUID `json:"contact_id" binding:"required"`
	Remark    string    `json:"remark"`
}

type ContactResponse struct {
	ID        uuid.UUID   `json:"id"`
	UserID    uuid.UUID   `json:"user_id"`
	ContactID uuid.UUID   `json:"contact_id"`
	Remark    string      `json:"remark"`
	Status    string      `json:"status"`
	User      *model.User `json:"user"`
}

func (s *ContactService) AddContact(userID uuid.UUID, input *AddContactInput) (*model.Contact, error) {
	if userID == input.ContactID {
		return nil, ErrCannotAddSelf
	}

	exists, err := s.contactRepo.ExistsRelation(userID, input.ContactID)
	if err != nil {
		return nil, err
	}
	if exists {
		return nil, ErrContactAlreadyExists
	}

	contact := &model.Contact{
		UserID:    userID,
		ContactID: input.ContactID,
		Remark:    input.Remark,
		Status:    model.ContactStatusPending,
	}

	if err := s.contactRepo.Create(contact); err != nil {
		return nil, err
	}

	return contact, nil
}

func (s *ContactService) AcceptContact(contactID uuid.UUID) error {
	contact, err := s.contactRepo.FindByID(contactID)
	if err != nil {
		return ErrContactNotFound
	}

	contact.Status = model.ContactStatusAccepted
	if err := s.contactRepo.Update(contact); err != nil {
		return err
	}

	reverseContact := &model.Contact{
		UserID:    contact.ContactID,
		ContactID: contact.UserID,
		Status:    model.ContactStatusAccepted,
	}
	return s.contactRepo.Create(reverseContact)
}

func (s *ContactService) GetContacts(userID uuid.UUID, limit, offset int) ([]ContactResponse, error) {
	contacts, err := s.contactRepo.ListByUserID(userID, limit, offset)
	if err != nil {
		return nil, err
	}

	var result []ContactResponse
	for _, c := range contacts {
		resp := ContactResponse{
			ID:        c.ID,
			UserID:    c.UserID,
			ContactID: c.ContactID,
			Remark:    c.Remark,
			Status:    string(c.Status),
		}
		result = append(result, resp)
	}
	return result, nil
}

func (s *ContactService) GetPendingRequests(userID uuid.UUID) ([]model.Contact, error) {
	return s.contactRepo.ListPendingByUserID(userID)
}

func (s *ContactService) DeleteContact(userID, contactID uuid.UUID) error {
	contact, err := s.contactRepo.FindByUserAndContact(userID, contactID)
	if err != nil {
		return ErrContactNotFound
	}
	return s.contactRepo.Delete(contact.ID)
}