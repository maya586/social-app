package response

import (
	"github.com/gin-gonic/gin"
)

type Response struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

type ErrorResponse struct {
	Code    string      `json:"code"`
	Message string      `json:"message"`
	Details interface{} `json:"details,omitempty"`
}

func Success(c *gin.Context, data interface{}) {
	c.JSON(200, Response{
		Code:    0,
		Message: "success",
		Data:    data,
	})
}

func Created(c *gin.Context, data interface{}) {
	c.JSON(201, Response{
		Code:    0,
		Message: "created",
		Data:    data,
	})
}

func Error(c *gin.Context, httpStatus int, code, message string, details ...interface{}) {
	resp := ErrorResponse{
		Code:    code,
		Message: message,
	}
	if len(details) > 0 {
		resp.Details = details[0]
	}
	c.JSON(httpStatus, resp)
}

func BadRequest(c *gin.Context, message string) {
	Error(c, 400, "BAD_REQUEST", message)
}

func Unauthorized(c *gin.Context, message string) {
	Error(c, 401, "UNAUTHORIZED", message)
}

func Forbidden(c *gin.Context, message string) {
	Error(c, 403, "FORBIDDEN", message)
}

func NotFound(c *gin.Context, message string) {
	Error(c, 404, "NOT_FOUND", message)
}

func InternalError(c *gin.Context, message string) {
	Error(c, 500, "INTERNAL_ERROR", message)
}