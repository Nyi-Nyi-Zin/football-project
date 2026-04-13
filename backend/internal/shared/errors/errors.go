package errors

import (
	"fmt"
	"net/http"
)

// Error codes
const (
	CodeValidation     = "VALIDATION_ERROR"
	CodeUnauthorized   = "UNAUTHORIZED"
	CodeForbidden      = "FORBIDDEN"
	CodeNotFound       = "NOT_FOUND"
	CodeConflict       = "CONFLICT"
	CodeInternal       = "INTERNAL_ERROR"
	CodeBadRequest     = "BAD_REQUEST"
	CodeTooManyRequest = "TOO_MANY_REQUESTS"
)

// AppError represents a standardized application error
type AppError struct {
	Code       string      `json:"code"`
	Message    string      `json:"message"`
	Details    interface{} `json:"details,omitempty"`
	StatusCode int         `json:"-"`
}

func (e *AppError) Error() string {
	return fmt.Sprintf("[%s] %s", e.Code, e.Message)
}

// NewValidationError creates a validation error
func NewValidationError(message string, details interface{}) *AppError {
	return &AppError{
		Code:       CodeValidation,
		Message:    message,
		Details:    details,
		StatusCode: http.StatusBadRequest,
	}
}

// NewUnauthorizedError creates an unauthorized error
func NewUnauthorizedError(message string) *AppError {
	return &AppError{
		Code:       CodeUnauthorized,
		Message:    message,
		StatusCode: http.StatusUnauthorized,
	}
}

// NewForbiddenError creates a forbidden error
func NewForbiddenError(message string) *AppError {
	return &AppError{
		Code:       CodeForbidden,
		Message:    message,
		StatusCode: http.StatusForbidden,
	}
}

// NewNotFoundError creates a not found error
func NewNotFoundError(message string) *AppError {
	return &AppError{
		Code:       CodeNotFound,
		Message:    message,
		StatusCode: http.StatusNotFound,
	}
}

// NewConflictError creates a conflict error
func NewConflictError(message string) *AppError {
	return &AppError{
		Code:       CodeConflict,
		Message:    message,
		StatusCode: http.StatusConflict,
	}
}

// NewInternalError creates an internal server error
func NewInternalError(message string) *AppError {
	return &AppError{
		Code:       CodeInternal,
		Message:    message,
		StatusCode: http.StatusInternalServerError,
	}
}

// NewBadRequestError creates a bad request error
func NewBadRequestError(message string) *AppError {
	return &AppError{
		Code:       CodeBadRequest,
		Message:    message,
		StatusCode: http.StatusBadRequest,
	}
}

// NewTooManyRequestsError creates a rate limit error
func NewTooManyRequestsError(message string) *AppError {
	return &AppError{
		Code:       CodeTooManyRequest,
		Message:    message,
		StatusCode: http.StatusTooManyRequests,
	}
}

// Response helpers

// SuccessResponse represents a standard success response
type SuccessResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data"`
	Meta    interface{} `json:"meta,omitempty"`
}

// ErrorResponse represents a standard error response
type ErrorResponse struct {
	Success bool      `json:"success"`
	Error   *AppError `json:"error"`
}

// PaginationMeta holds pagination metadata
type PaginationMeta struct {
	Total    int64 `json:"total"`
	Page     int   `json:"page"`
	LastPage int   `json:"lastPage"`
}

// NewSuccessResponse creates a success response
func NewSuccessResponse(data interface{}, meta interface{}) *SuccessResponse {
	return &SuccessResponse{
		Success: true,
		Data:    data,
		Meta:    meta,
	}
}

// NewErrorResponse creates an error response
func NewErrorResponse(err *AppError) *ErrorResponse {
	return &ErrorResponse{
		Success: false,
		Error:   err,
	}
}
