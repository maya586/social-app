package handler

import (
	"github.com/example/social-app/server/internal/middleware"
	"github.com/example/social-app/server/internal/service"
	"github.com/example/social-app/server/pkg/response"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"strconv"
)

type ContactHandler struct {
	contactService *service.ContactService
}

func NewContactHandler(contactService *service.ContactService) *ContactHandler {
	return &ContactHandler{contactService: contactService}
}

func (h *ContactHandler) AddContact(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	var input service.AddContactInput
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Invalid request")
		return
	}

	contact, err := h.contactService.AddContact(userID, &input)
	if err != nil {
		switch err {
		case service.ErrContactAlreadyExists:
			response.Error(c, 409, "CONTACT_ALREADY_EXISTS", err.Error())
		case service.ErrCannotAddSelf:
			response.BadRequest(c, err.Error())
		default:
			response.InternalError(c, "Failed to add contact")
		}
		return
	}

	response.Created(c, contact)
}

func (h *ContactHandler) AcceptContact(c *gin.Context) {
	contactID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid contact ID")
		return
	}

	if err := h.contactService.AcceptContact(contactID); err != nil {
		response.InternalError(c, "Failed to accept contact")
		return
	}

	response.Success(c, nil)
}

func (h *ContactHandler) GetContacts(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	contacts, err := h.contactService.GetContacts(userID, limit, offset)
	if err != nil {
		response.InternalError(c, "Failed to get contacts")
		return
	}

	response.Success(c, contacts)
}

func (h *ContactHandler) DeleteContact(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	contactID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid contact ID")
		return
	}

	if err := h.contactService.DeleteContact(userID, contactID); err != nil {
		response.InternalError(c, "Failed to delete contact")
		return
	}

	response.Success(c, nil)
}

func (h *ContactHandler) GetPendingRequests(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)

	contacts, err := h.contactService.GetPendingRequests(userID)
	if err != nil {
		response.InternalError(c, "Failed to get pending requests")
		return
	}

	response.Success(c, contacts)
}

func (h *ContactHandler) RejectContact(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	contactID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid contact ID")
		return
	}

	if err := h.contactService.RejectContact(userID, contactID); err != nil {
		response.InternalError(c, "Failed to reject contact")
		return
	}

	response.Success(c, nil)
}
