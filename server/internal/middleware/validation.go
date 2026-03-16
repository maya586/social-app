package middleware

import (
	"regexp"
	"unicode"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
)

var validate *validator.Validate

func init() {
	validate = validator.New()
	validate.RegisterValidation("phone", validatePhone)
	validate.RegisterValidation("password", validatePassword)
	validate.RegisterValidation("nickname", validateNickname)
}

func validatePhone(fl validator.FieldLevel) bool {
	phone := fl.Field().String()
	matched, _ := regexp.MatchString(`^1[3-9]\d{9}$`, phone)
	return matched
}

func validatePassword(fl validator.FieldLevel) bool {
	password := fl.Field().String()
	
	if len(password) < 8 || len(password) > 32 {
		return false
	}
	
	var hasUpper, hasLower, hasDigit bool
	
	for _, char := range password {
		switch {
		case unicode.IsUpper(char):
			hasUpper = true
		case unicode.IsLower(char):
			hasLower = true
		case unicode.IsDigit(char):
			hasDigit = true
		}
	}
	
	return hasUpper && hasLower && hasDigit
}

func validateNickname(fl validator.FieldLevel) bool {
	nickname := fl.Field().String()
	
	if len(nickname) < 2 || len(nickname) > 20 {
		return false
	}
	
	for _, char := range nickname {
		if !unicode.IsLetter(char) && !unicode.IsDigit(char) && char != '_' {
			if char >= 0x4E00 && char <= 0x9FFF {
				continue
			}
			return false
		}
	}
	
	return true
}

func GetValidator() *validator.Validate {
	return validate
}

type ErrorResponse struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

func ValidateStruct(s interface{}) []*ErrorResponse {
	var errors []*ErrorResponse
	
	err := validate.Struct(s)
	if err == nil {
		return nil
	}
	
	for _, err := range err.(validator.ValidationErrors) {
		var message string
		
		switch err.Tag() {
		case "required":
			message = "This field is required"
		case "phone":
			message = "Invalid phone number format"
		case "password":
			message = "Password must be 8-32 characters with uppercase, lowercase and numbers"
		case "nickname":
			message = "Nickname must be 2-20 characters (letters, numbers, underscores, or Chinese)"
		case "email":
			message = "Invalid email format"
		case "min":
			message = "Value is too short"
		case "max":
			message = "Value is too long"
		default:
			message = "Invalid value"
		}
		
		errors = append(errors, &ErrorResponse{
			Field:   err.Field(),
			Message: message,
		})
	}
	
	return errors
}

func ValidationMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()
	}
}