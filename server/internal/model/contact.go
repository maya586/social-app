package model

import (
	"github.com/google/uuid"
	"gorm.io/gorm"
	"time"
)

type ContactStatus string

const (
	ContactStatusPending  ContactStatus = "pending"
	ContactStatusAccepted ContactStatus = "accepted"
	ContactStatusBlocked  ContactStatus = "blocked"
)

type Contact struct {
	ID        uuid.UUID     `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID    uuid.UUID     `gorm:"type:uuid;index;not null" json:"user_id"`
	ContactID uuid.UUID     `gorm:"type:uuid;index;not null" json:"contact_id"`
	Remark    string        `gorm:"size:50" json:"remark"`
	Status    ContactStatus `gorm:"type:varchar(20);default:'pending'" json:"status"`
	CreatedAt time.Time     `json:"created_at"`

	ContactUser *User `gorm:"foreignKey:ContactID" json:"contact_user,omitempty"`
}

func (c *Contact) BeforeCreate(tx *gorm.DB) error {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	return nil
}
