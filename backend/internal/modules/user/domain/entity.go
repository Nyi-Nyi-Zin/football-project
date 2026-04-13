package domain

import (
	"time"
)

// User represents the user entity
type User struct {
	ID           string    `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	Email        string    `json:"email" gorm:"uniqueIndex;not null"`
	Username     string    `json:"username" gorm:"uniqueIndex;not null"`
	PasswordHash string    `json:"-" gorm:"not null"`
	FullName     string    `json:"full_name"`
	Phone        string    `json:"phone"`
	Role         string    `json:"role" gorm:"default:'user'"`
	Status       string    `json:"status" gorm:"default:'active'"`
	Balance      float64   `json:"balance" gorm:"type:decimal(18,2);default:0"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// TableName overrides the table name for schema-per-module
func (User) TableName() string {
	return "users.accounts"
}

// UserProfile is a safe representation without sensitive fields
type UserProfile struct {
	ID        string    `json:"id"`
	Email     string    `json:"email"`
	Username  string    `json:"username"`
	FullName  string    `json:"full_name"`
	Phone     string    `json:"phone"`
	Role      string    `json:"role"`
	Status    string    `json:"status"`
	Balance   float64   `json:"balance"`
	CreatedAt time.Time `json:"created_at"`
}

// ToProfile converts a User to a safe UserProfile
func (u *User) ToProfile() *UserProfile {
	return &UserProfile{
		ID:        u.ID,
		Email:     u.Email,
		Username:  u.Username,
		FullName:  u.FullName,
		Phone:     u.Phone,
		Role:      u.Role,
		Status:    u.Status,
		Balance:   u.Balance,
		CreatedAt: u.CreatedAt,
	}
}

// RegisterRequest represents a user registration request
type RegisterRequest struct {
	Email    string `json:"email" validate:"required,email"`
	Username string `json:"username" validate:"required,min=3,max=30"`
	Password string `json:"password" validate:"required,min=8"`
	FullName string `json:"full_name" validate:"required"`
	Phone    string `json:"phone"`
}

// LoginRequest represents a user login request
type LoginRequest struct {
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required"`
}

// UpdateProfileRequest represents a profile update request
type UpdateProfileRequest struct {
	FullName string `json:"full_name"`
	Phone    string `json:"phone"`
}
