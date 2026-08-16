package domain

import "context"

// UserRepository defines the interface for user data operations
type UserRepository interface {
	Create(ctx context.Context, user *User) error
	FindByID(ctx context.Context, id string) (*User, error)
	FindByEmail(ctx context.Context, email string) (*User, error)
	FindByUsername(ctx context.Context, username string) (*User, error)
	Update(ctx context.Context, user *User) error
	UpdateStatus(ctx context.Context, userID, status string) error
	UpdateBalance(ctx context.Context, userID string, amount float64) error
	List(ctx context.Context, page, limit int) ([]*User, int64, error)
	ListFiltered(ctx context.Context, query, status string, page, limit int) ([]*User, int64, error)
	CountByStatus(ctx context.Context, status string) (int64, error)

	// KYC / Verification
	SetEmailVerified(ctx context.Context, userID string, verified bool) error
	SetPhoneVerified(ctx context.Context, userID string, verified bool) error
	UpdateKYCSubmission(ctx context.Context, userID, nationalID, kycImageURL string) error
	UpdateKYCStatus(ctx context.Context, userID string, status KYCStatus) error
	GetVerificationStatus(ctx context.Context, userID string) (*UserVerificationStatus, error)

	// NRC Reference Data
	FindNRCRegionByID(ctx context.Context, id int) (*NRCRegion, error)
	FindNRCTownshipByID(ctx context.Context, id int) (*NRCTownship, error)
	FindNRCTypeByID(ctx context.Context, id int) (*NRCType, error)
}
