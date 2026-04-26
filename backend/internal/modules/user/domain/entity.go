package domain

import (
	"time"
)

// KYCStatus represents the Know Your Customer verification state
type KYCStatus string

const (
	KYCStatusPending  KYCStatus = "pending"
	KYCStatusApproved KYCStatus = "approved"
	KYCStatusRejected KYCStatus = "rejected"
)

// User represents the user entity
type User struct {
	ID              string    `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	Email           string    `json:"email" gorm:"uniqueIndex;not null"`
	Username        string    `json:"username" gorm:"uniqueIndex;not null"`
	PasswordHash    string    `json:"-" gorm:"not null"`
	FullName        string    `json:"full_name"`
	Phone           string    `json:"phone"`
	Role            string    `json:"role" gorm:"default:'user'"`
	Status          string    `json:"status" gorm:"default:'active'"`
	Balance         float64   `json:"balance" gorm:"type:decimal(18,2);default:0"`
	IsEmailVerified bool      `json:"is_email_verified" gorm:"default:false"`
	IsPhoneVerified bool      `json:"is_phone_verified" gorm:"default:false"`
	KYCStatus       KYCStatus `json:"kyc_status" gorm:"default:'pending'"`
	NationalID      string    `json:"national_id,omitempty" gorm:"size:100"`
	KYCImageURL     string    `json:"kyc_image_url,omitempty" gorm:"type:text"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

// TableName overrides the table name for schema-per-module
func (User) TableName() string {
	return "users.accounts"
}

// UserProfile is a safe representation without sensitive fields
type UserProfile struct {
	ID              string    `json:"id"`
	Email           string    `json:"email"`
	Username        string    `json:"username"`
	FullName        string    `json:"full_name"`
	Phone           string    `json:"phone"`
	Role            string    `json:"role"`
	Status          string    `json:"status"`
	Balance         float64   `json:"balance"`
	IsEmailVerified bool      `json:"is_email_verified"`
	IsPhoneVerified bool      `json:"is_phone_verified"`
	KYCStatus       KYCStatus `json:"kyc_status"`
	CreatedAt       time.Time `json:"created_at"`
}

// ToProfile converts a User to a safe UserProfile
func (u *User) ToProfile() *UserProfile {
	return &UserProfile{
		ID:              u.ID,
		Email:           u.Email,
		Username:        u.Username,
		FullName:        u.FullName,
		Phone:           u.Phone,
		Role:            u.Role,
		Status:          u.Status,
		Balance:         u.Balance,
		IsEmailVerified: u.IsEmailVerified,
		IsPhoneVerified: u.IsPhoneVerified,
		KYCStatus:       u.KYCStatus,
		CreatedAt:       u.CreatedAt,
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

type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" validate:"required"`
}

// UpdateProfileRequest represents a profile update request
type UpdateProfileRequest struct {
	FullName string `json:"full_name"`
	Phone    string `json:"phone"`
}

// ChangePasswordRequest represents a password change request
type ChangePasswordRequest struct {
	CurrentPassword string `json:"current_password" validate:"required"`
	NewPassword     string `json:"new_password" validate:"required,min=8"`
}

// VerifyEmailRequest represents an email verification request (OTP/code)
type VerifyEmailRequest struct {
	Code string `json:"code" validate:"required"`
}

// VerifyPhoneRequest represents a phone verification request (OTP/code)
type VerifyPhoneRequest struct {
	Code string `json:"code" validate:"required"`
}

// SubmitKYCRequest represents a KYC document submission
type SubmitKYCRequest struct {
	NationalID  string `json:"national_id" validate:"required,min=5"`
	KYCImageURL string `json:"kyc_image_url" validate:"required,url"`
}

// AdminKYCDecisionRequest represents an admin KYC approval/rejection
type AdminKYCDecisionRequest struct {
	Decision string `json:"decision" validate:"required,oneof=approved rejected"`
	Reason   string `json:"reason"`
}

// UserVerificationStatus is a cross-module DTO used by payment module
// to check if a user is eligible for withdrawals.
type UserVerificationStatus struct {
	IsEmailVerified bool
	IsPhoneVerified bool
	KYCStatus       KYCStatus
}
