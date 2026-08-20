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
	ID                       string    `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	Email                    string    `json:"email" gorm:"uniqueIndex;not null"`
	Username                 string    `json:"username" gorm:"uniqueIndex;not null"`
	PasswordHash             string    `json:"-" gorm:"not null"`
	FullName                 string    `json:"full_name"`
	Phone                    string    `json:"phone"`
	Role                     string    `json:"role" gorm:"default:'user'"`
	Status                   string    `json:"status" gorm:"default:'active'"`
	Balance                  float64   `json:"balance" gorm:"type:decimal(18,2);default:0"`
	IsEmailVerified          bool      `json:"is_email_verified" gorm:"default:false"`
	IsPhoneVerified          bool      `json:"is_phone_verified" gorm:"default:false"`
	KYCStatus                KYCStatus `json:"kyc_status" gorm:"default:'pending'"`
	NationalID               string    `json:"national_id,omitempty" gorm:"size:100"`
	KYCImageURL              string    `json:"kyc_image_url,omitempty" gorm:"type:text"`
	NRC                      string    `json:"nrc,omitempty" gorm:"size:100"`
	NRCRegion                string    `json:"nrc_region,omitempty" gorm:"size:50"`
	NRCTownship              string    `json:"nrc_township,omitempty" gorm:"size:100"`
	NRCType                  string    `json:"nrc_type,omitempty" gorm:"size:50"`
	NRCNumber                string    `json:"nrc_number,omitempty" gorm:"size:20"`
	NRCRegionID              *int      `json:"nrc_region_id,omitempty" gorm:"column:nrc_region_id"`
	NRCTownshipID            *int      `json:"nrc_township_id,omitempty" gorm:"column:nrc_township_id"`
	NRCTypeID                *int      `json:"nrc_type_id,omitempty" gorm:"column:nrc_type_id"`
	Gmail                    string    `json:"gmail,omitempty" gorm:"size:255"`
	Location                 string    `json:"location,omitempty" gorm:"type:text"`
	Region                   string    `json:"region,omitempty" gorm:"size:100"`
	Township                 string    `json:"township,omitempty" gorm:"size:100"`
	CustomCode               *string   `json:"custom_code,omitempty" gorm:"size:10;uniqueIndex"`
	TokenVersion             int       `json:"-" gorm:"not null;default:1"`
	SecurityPINHash          string    `json:"-" gorm:"column:security_pin_hash"`
	TwoFactorSecretEncrypted string    `json:"-" gorm:"column:two_factor_secret_encrypted"`
	TwoFactorEnabled         bool      `json:"two_factor_enabled" gorm:"column:two_factor_enabled;not null;default:false"`
	FavoriteMatchIDs         []string  `json:"favorite_match_ids" gorm:"type:jsonb;serializer:json;default:'[]'"`
	CreatedAt                time.Time `json:"created_at"`
	UpdatedAt                time.Time `json:"updated_at"`
}

// TableName overrides the table name for schema-per-module
func (User) TableName() string {
	return "users.accounts"
}

// UserProfile is a safe representation without sensitive fields
type UserProfile struct {
	ID                     string    `json:"id"`
	Email                  string    `json:"email"`
	Username               string    `json:"username"`
	FullName               string    `json:"full_name"`
	Phone                  string    `json:"phone"`
	Role                   string    `json:"role"`
	Status                 string    `json:"status"`
	Balance                float64   `json:"balance"`
	IsEmailVerified        bool      `json:"is_email_verified"`
	IsPhoneVerified        bool      `json:"is_phone_verified"`
	KYCStatus              KYCStatus `json:"kyc_status"`
	NRC                    string    `json:"nrc,omitempty"`
	NRCRegion              string    `json:"nrc_region,omitempty"`
	NRCTownship            string    `json:"nrc_township,omitempty"`
	NRCType                string    `json:"nrc_type,omitempty"`
	NRCNumber              string    `json:"nrc_number,omitempty"`
	NRCRegionID            *int      `json:"nrc_region_id,omitempty"`
	NRCTownshipID          *int      `json:"nrc_township_id,omitempty"`
	NRCTypeID              *int      `json:"nrc_type_id,omitempty"`
	Gmail                  string    `json:"gmail,omitempty"`
	Location               string    `json:"location,omitempty"`
	Region                 string    `json:"region,omitempty"`
	Township               string    `json:"township,omitempty"`
	CustomCode             string    `json:"custom_code,omitempty"`
	PendingWithdrawalCount int       `json:"pending_withdrawal_count,omitempty"`
	FavoriteMatchIDs       []string  `json:"favorite_match_ids"`
	CreatedAt              time.Time `json:"created_at"`
}

// ToProfile converts a User to a safe UserProfile
func (u *User) ToProfile() *UserProfile {
	customCode := ""
	if u.CustomCode != nil {
		customCode = *u.CustomCode
	}
	return &UserProfile{
		ID:               u.ID,
		Email:            u.Email,
		Username:         u.Username,
		FullName:         u.FullName,
		Phone:            u.Phone,
		Role:             u.Role,
		Status:           u.Status,
		Balance:          u.Balance,
		IsEmailVerified:  u.IsEmailVerified,
		IsPhoneVerified:  u.IsPhoneVerified,
		KYCStatus:        u.KYCStatus,
		NRC:              u.NRC,
		NRCRegion:        u.NRCRegion,
		NRCTownship:      u.NRCTownship,
		NRCType:          u.NRCType,
		NRCNumber:        u.NRCNumber,
		NRCRegionID:      u.NRCRegionID,
		NRCTownshipID:    u.NRCTownshipID,
		NRCTypeID:        u.NRCTypeID,
		Gmail:            u.Gmail,
		Location:         u.Location,
		Region:           u.Region,
		Township:         u.Township,
		CustomCode:       customCode,
		FavoriteMatchIDs: append([]string(nil), u.FavoriteMatchIDs...),
		CreatedAt:        u.CreatedAt,
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

// AdminCreateUserRequest represents an admin-created customer or agent account.
type AdminCreateUserRequest struct {
	Email    string `json:"email" validate:"required,email"`
	Username string `json:"username" validate:"required,min=3,max=30"`
	Password string `json:"password" validate:"required,min=8"`
	FullName string `json:"full_name" validate:"required,min=2"`
	Phone    string `json:"phone" validate:"omitempty"`
	Role     string `json:"role" validate:"required,oneof=user agent"`
	Status   string `json:"status" validate:"omitempty,oneof=active suspended blocked"`
	Region   string `json:"region" validate:"omitempty,max=100"`
	Township string `json:"township" validate:"omitempty,max=100"`
}

type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" validate:"required"`
}

type TwoFactorCodeRequest struct {
	Code string `json:"code" validate:"required,len=6,numeric"`
}

type TwoFactorStatus struct {
	Enabled bool `json:"enabled"`
}

type TwoFactorEnrollment struct {
	Secret     string `json:"secret"`
	OtpauthURL string `json:"otpauth_url"`
	Enabled    bool   `json:"enabled"`
}

// UpdateProfileRequest represents a profile update request
type UpdateProfileRequest struct {
	FullName         string   `json:"full_name" validate:"omitempty,min=2"`
	Phone            string   `json:"phone" validate:"omitempty"`
	NRC              string   `json:"nrc" validate:"omitempty"`
	NRCRegion        string   `json:"nrc_region" validate:"omitempty"`
	NRCTownship      string   `json:"nrc_township" validate:"omitempty"`
	NRCType          string   `json:"nrc_type" validate:"omitempty"`
	NRCNumber        string   `json:"nrc_number" validate:"omitempty"`
	NRCRegionID      *int     `json:"nrc_region_id,omitempty" validate:"omitempty"`
	NRCTownshipID    *int     `json:"nrc_township_id,omitempty" validate:"omitempty"`
	NRCTypeID        *int     `json:"nrc_type_id,omitempty" validate:"omitempty"`
	Gmail            string   `json:"gmail" validate:"omitempty,email"`
	Location         string   `json:"location" validate:"omitempty"`
	Region           string   `json:"region" validate:"omitempty,max=100"`
	Township         string   `json:"township" validate:"omitempty,max=100"`
	CustomCode       string   `json:"custom_code" validate:"omitempty,min=3,max=10"`
	FavoriteMatchIDs []string `json:"favorite_match_ids,omitempty" validate:"omitempty,max=500,dive,max=120"`
}

// ChangePasswordRequest represents a password change request
type ChangePasswordRequest struct {
	CurrentPassword string `json:"current_password" validate:"required"`
	NewPassword     string `json:"new_password" validate:"required,min=8"`
}

// ChangeSecurityPINRequest updates the Agent's local payout/security PIN.
type ChangeSecurityPINRequest struct {
	CurrentPIN string `json:"current_pin" validate:"omitempty,numeric,min=4,max=8"`
	NewPIN     string `json:"new_pin" validate:"required,numeric,min=4,max=8"`
}

// SecuritySession describes the current authenticated device session.
type SecuritySession struct {
	SessionID string    `json:"session_id"`
	IssuedAt  time.Time `json:"issued_at"`
	ExpiresAt time.Time `json:"expires_at"`
	IsCurrent bool      `json:"is_current"`
	Revocable bool      `json:"revocable"`
}

// AdminUpdateStatusRequest controls whether an account can authenticate and bet.
type AdminUpdateStatusRequest struct {
	Status string `json:"status" validate:"required,oneof=active suspended blocked"`
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
