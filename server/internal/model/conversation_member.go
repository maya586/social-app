package model

import (
	"time"
	"github.com/google/uuid"
)

type MemberRole string

const (
	MemberRoleOwner  MemberRole = "owner"
	MemberRoleAdmin  MemberRole = "admin"
	MemberRoleMember MemberRole = "member"
)

type ConversationMember struct {
	UserID         uuid.UUID  `gorm:"type:uuid;primaryKey" json:"user_id"`
	ConversationID uuid.UUID  `gorm:"type:uuid;primaryKey" json:"conversation_id"`
	Role           MemberRole `gorm:"type:varchar(20);default:'member'" json:"role"`
	LastReadAt     *time.Time `json:"last_read_at"`
	JoinedAt       time.Time  `json:"joined_at"`
}