package domain

import "context"

// UserRepository defines the interface for user data access
type UserRepository interface {
	Create(ctx context.Context, user *User) error
	FindByID(ctx context.Context, id string) (*User, error)
	FindByEmail(ctx context.Context, email string) (*User, error)
	FindByUsername(ctx context.Context, username string) (*User, error)
	Update(ctx context.Context, user *User) error
	UpdateBalance(ctx context.Context, userID string, amount float64) error
	List(ctx context.Context, page, limit int) ([]*User, int64, error)
	ListFiltered(ctx context.Context, query, status string, page, limit int) ([]*User, int64, error)
	CountByStatus(ctx context.Context, status string) (int64, error)
}
