package handler

import (
	"context"
	"log"

	"github.com/example/social-app/server/internal/middleware"
	"github.com/example/social-app/server/internal/storage"
	"github.com/example/social-app/server/pkg/response"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"io"
	"strconv"
	"strings"
)

type FileHandler struct{}

func NewFileHandler() *FileHandler {
	return &FileHandler{}
}

func (h *FileHandler) Upload(c *gin.Context) {
	_ = middleware.GetUserID(c).(uuid.UUID)

	file, header, err := c.Request.FormFile("file")
	if err != nil {
		response.BadRequest(c, "No file uploaded")
		return
	}
	defer file.Close()

	fileType := c.DefaultQuery("type", "general")
	if !isValidFileType(fileType) {
		response.BadRequest(c, "Invalid file type")
		return
	}

	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	ext := getFileExtension(header.Filename)
	objectName := storage.GenerateObjectName(fileType) + ext

	url, err := storage.UploadFile(context.Background(), objectName, file, header.Size, contentType)
	if err != nil {
		log.Printf("Failed to upload file to storage: %v", err)
		response.InternalError(c, "Failed to upload file: "+err.Error())
		return
	}

	log.Printf("File uploaded successfully: %s", url)

	response.Created(c, gin.H{
		"url":      url,
		"filename": header.Filename,
		"size":     header.Size,
		"type":     contentType,
	})
}

func (h *FileHandler) Download(c *gin.Context) {
	objectName := c.Param("id")
	if objectName == "" {
		response.BadRequest(c, "Invalid file id")
		return
	}

	log.Printf("Downloading file: %s", objectName)

	object, err := storage.GetFile(context.Background(), objectName)
	if err != nil {
		log.Printf("File not found: %s, error: %v", objectName, err)
		response.NotFound(c, "File not found")
		return
	}
	defer object.Close()

	info, err := object.Stat()
	if err != nil {
		response.InternalError(c, "Failed to get file info")
		return
	}

	c.Header("Content-Type", info.ContentType)
	c.Header("Content-Length", strconv.FormatInt(info.Size, 10))
	c.Header("Content-Disposition", "inline; filename="+objectName)

	_, err = io.Copy(c.Writer, object)
	if err != nil {
		response.InternalError(c, "Failed to send file")
		return
	}
}

func (h *FileHandler) Delete(c *gin.Context) {
	userID := middleware.GetUserID(c).(uuid.UUID)
	_ = userID

	objectName := c.Param("id")
	if objectName == "" {
		response.BadRequest(c, "Invalid file id")
		return
	}

	parts := strings.Split(objectName, "/")
	if len(parts) >= 2 {
		objectName = strings.Join(parts[1:], "/")
	}

	err := storage.DeleteFile(context.Background(), objectName)
	if err != nil {
		response.InternalError(c, "Failed to delete file")
		return
	}

	response.Success(c, nil)
}

func isValidFileType(fileType string) bool {
	validTypes := map[string]bool{
		"image": true,
		"voice": true,
		"video": true,
		"file":  true,
	}
	return validTypes[fileType]
}

func getFileExtension(filename string) string {
	parts := strings.Split(filename, ".")
	if len(parts) > 1 {
		return "." + parts[len(parts)-1]
	}
	return ""
}
