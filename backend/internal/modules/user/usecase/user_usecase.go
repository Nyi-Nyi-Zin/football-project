package usecase

import (
	"context"
	"fmt"
	"strings"

	"betting-app/internal/modules/user/domain"
	apperrors "betting-app/internal/shared/errors"
	"betting-app/internal/shared/event"
	jwtpkg "betting-app/pkg/jwt"

	"golang.org/x/crypto/bcrypt"
)

// UserUseCase handles user business logic
type UserUseCase struct {
	repo       domain.UserRepository
	jwtManager *jwtpkg.Manager
	eventBus   *event.Bus
}

type UserListStats struct {
	TotalUsers     int64 `json:"total_users"`
	ActiveUsers    int64 `json:"active_users"`
	SuspendedUsers int64 `json:"suspended_users"`
}

// NewUserUseCase creates a new user use case
func NewUserUseCase(repo domain.UserRepository, jwtManager *jwtpkg.Manager, eventBus *event.Bus) *UserUseCase {
	return &UserUseCase{
		repo:       repo,
		jwtManager: jwtManager,
		eventBus:   eventBus,
	}
}

// Register creates a new user account
func (uc *UserUseCase) Register(ctx context.Context, req *domain.RegisterRequest) (*domain.UserProfile, *jwtpkg.TokenPair, error) {
	// Check if email already exists
	existing, _ := uc.repo.FindByEmail(ctx, req.Email)
	if existing != nil {
		return nil, nil, apperrors.NewConflictError("Email already registered")
	}

	// Check if username already exists
	existing, _ = uc.repo.FindByUsername(ctx, req.Username)
	if existing != nil {
		return nil, nil, apperrors.NewConflictError("Username already taken")
	}

	// Hash password (bcrypt cost factor 12)
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		return nil, nil, fmt.Errorf("usecase.Register: hash password: %w", err)
	}

	user := &domain.User{
		Email:        strings.ToLower(req.Email),
		Username:     req.Username,
		PasswordHash: string(hashedPassword),
		FullName:     req.FullName,
		Phone:        req.Phone,
		Role:         "user",
		Status:       "active",
		KYCStatus:    domain.KYCStatusPending,
	}

	if err := uc.repo.Create(ctx, user); err != nil {
		return nil, nil, fmt.Errorf("usecase.Register: %w", err)
	}

	// Generate tokens
	tokens, err := uc.jwtManager.GenerateTokenPair(user.ID, user.Email, user.Role)
	if err != nil {
		return nil, nil, fmt.Errorf("usecase.Register: generate tokens: %w", err)
	}

	// Publish event
	_ = uc.eventBus.Publish(ctx, event.Event{
		Type:    event.UserRegistered,
		Payload: map[string]string{"user_id": user.ID, "email": user.Email},
	})

	return user.ToProfile(), tokens, nil
}

// Login authenticates a user and returns tokens
func (uc *UserUseCase) Login(ctx context.Context, req *domain.LoginRequest) (*domain.UserProfile, *jwtpkg.TokenPair, error) {
	user, err := uc.repo.FindByEmail(ctx, strings.ToLower(req.Email))
	if err != nil {
		return nil, nil, apperrors.NewUnauthorizedError("Invalid email or password")
	}

	if user.Status != "active" {
		return nil, nil, apperrors.NewForbiddenError("Account is suspended")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, nil, apperrors.NewUnauthorizedError("Invalid email or password")
	}

	tokens, err := uc.jwtManager.GenerateTokenPair(user.ID, user.Email, user.Role)
	if err != nil {
		return nil, nil, fmt.Errorf("usecase.Login: generate tokens: %w", err)
	}

	_ = uc.eventBus.Publish(ctx, event.Event{
		Type:    event.UserLoggedIn,
		Payload: map[string]string{"user_id": user.ID},
	})

	return user.ToProfile(), tokens, nil
}

// RefreshToken validates a refresh token and issues a new access/refresh pair.
func (uc *UserUseCase) RefreshToken(ctx context.Context, refreshToken string) (*domain.UserProfile, *jwtpkg.TokenPair, error) {
	claims, err := uc.jwtManager.ValidateRefreshToken(refreshToken)
	if err != nil {
		return nil, nil, apperrors.NewUnauthorizedError("Invalid or expired refresh token")
	}

	user, err := uc.repo.FindByID(ctx, claims.UserID)
	if err != nil {
		return nil, nil, apperrors.NewUnauthorizedError("Invalid refresh token subject")
	}
	if user.Status != "active" {
		return nil, nil, apperrors.NewForbiddenError("Account is suspended")
	}

	tokens, err := uc.jwtManager.GenerateTokenPair(user.ID, user.Email, user.Role)
	if err != nil {
		return nil, nil, fmt.Errorf("usecase.RefreshToken: generate tokens: %w", err)
	}

	return user.ToProfile(), tokens, nil
}

// GetProfile returns a user's profile
func (uc *UserUseCase) GetProfile(ctx context.Context, userID string) (*domain.UserProfile, error) {
	user, err := uc.repo.FindByID(ctx, userID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("User not found")
	}
	return user.ToProfile(), nil
}

// UpdateProfile updates a user's profile
func (uc *UserUseCase) UpdateProfile(ctx context.Context, userID string, req *domain.UpdateProfileRequest) (*domain.UserProfile, error) {
	user, err := uc.repo.FindByID(ctx, userID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("User not found")
	}

	if req.FullName != "" {
		user.FullName = req.FullName
	}
	if req.Phone != "" {
		user.Phone = req.Phone
	}

	if err := uc.repo.Update(ctx, user); err != nil {
		return nil, fmt.Errorf("usecase.UpdateProfile: %w", err)
	}

	return user.ToProfile(), nil
}

// ChangePassword updates the authenticated user's password.
func (uc *UserUseCase) ChangePassword(ctx context.Context, userID string, req *domain.ChangePasswordRequest) error {
	user, err := uc.repo.FindByID(ctx, userID)
	if err != nil {
		return apperrors.NewNotFoundError("User not found")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.CurrentPassword)); err != nil {
		return apperrors.NewUnauthorizedError("Current password is incorrect")
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), 12)
	if err != nil {
		return fmt.Errorf("usecase.ChangePassword: hash password: %w", err)
	}

	user.PasswordHash = string(hashedPassword)
	if err := uc.repo.Update(ctx, user); err != nil {
		return fmt.Errorf("usecase.ChangePassword: %w", err)
	}

	return nil
}

// ListUsers returns paginated users (admin only)
func (uc *UserUseCase) ListUsers(ctx context.Context, page, limit int) ([]*domain.UserProfile, int64, error) {
	users, total, err := uc.repo.List(ctx, page, limit)
	if err != nil {
		return nil, 0, fmt.Errorf("usecase.ListUsers: %w", err)
	}

	profiles := make([]*domain.UserProfile, len(users))
	for i, u := range users {
		profiles[i] = u.ToProfile()
	}

	return profiles, total, nil
}

// ListUsersAdmin returns paginated users and aggregate counters for admin screens.
func (uc *UserUseCase) ListUsersAdmin(ctx context.Context, query, status string, page, limit int) ([]*domain.UserProfile, int64, *UserListStats, error) {
	users, total, err := uc.repo.ListFiltered(ctx, query, status, page, limit)
	if err != nil {
		return nil, 0, nil, fmt.Errorf("usecase.ListUsersAdmin: %w", err)
	}

	profiles := make([]*domain.UserProfile, len(users))
	for i, u := range users {
		profiles[i] = u.ToProfile()
	}

	totalUsers, err := uc.repo.CountByStatus(ctx, "")
	if err != nil {
		return nil, 0, nil, fmt.Errorf("usecase.ListUsersAdmin: total: %w", err)
	}
	activeUsers, err := uc.repo.CountByStatus(ctx, "active")
	if err != nil {
		return nil, 0, nil, fmt.Errorf("usecase.ListUsersAdmin: active: %w", err)
	}
	suspendedUsers, err := uc.repo.CountByStatus(ctx, "suspended")
	if err != nil {
		return nil, 0, nil, fmt.Errorf("usecase.ListUsersAdmin: suspended: %w", err)
	}

	return profiles, total, &UserListStats{
		TotalUsers:     totalUsers,
		ActiveUsers:    activeUsers,
		SuspendedUsers: suspendedUsers,
	}, nil
}

func (uc *UserUseCase) GetProfileByID(ctx context.Context, userID string) (*domain.UserProfile, error) {
	user, err := uc.repo.FindByID(ctx, userID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("User not found")
	}
	return user.ToProfile(), nil
}

// ─── KYC & Verification ─────────────────────────────────────────────────────

// VerifyEmail marks the user's email as verified.
// In production this would validate an OTP/link token first.
func (uc *UserUseCase) VerifyEmail(ctx context.Context, userID string, req *domain.VerifyEmailRequest) error {
	// TODO: In production, validate the OTP/code against a stored value.
	// For now, any non-empty code is accepted to enable the flow.
	if strings.TrimSpace(req.Code) == "" {
		return apperrors.NewBadRequestError("Verification code is required")
	}

	if err := uc.repo.SetEmailVerified(ctx, userID, true); err != nil {
		return fmt.Errorf("usecase.VerifyEmail: %w", err)
	}
	return nil
}

// VerifyPhone marks the user's phone as verified.
// In production this would validate an SMS OTP first.
func (uc *UserUseCase) VerifyPhone(ctx context.Context, userID string, req *domain.VerifyPhoneRequest) error {
	// TODO: In production, validate the OTP/code against a stored value.
	if strings.TrimSpace(req.Code) == "" {
		return apperrors.NewBadRequestError("Verification code is required")
	}

	if err := uc.repo.SetPhoneVerified(ctx, userID, true); err != nil {
		return fmt.Errorf("usecase.VerifyPhone: %w", err)
	}
	return nil
}

// SubmitKYC records a user's National ID and verification image for admin review.
func (uc *UserUseCase) SubmitKYC(ctx context.Context, userID string, req *domain.SubmitKYCRequest) error {
	user, err := uc.repo.FindByID(ctx, userID)
	if err != nil {
		return apperrors.NewNotFoundError("User not found")
	}

	// If already approved, no re-submission needed
	if user.KYCStatus == domain.KYCStatusApproved {
		return apperrors.NewBadRequestError("KYC is already approved")
	}

	if err := uc.repo.UpdateKYCSubmission(ctx, userID, req.NationalID, req.KYCImageURL); err != nil {
		return fmt.Errorf("usecase.SubmitKYC: %w", err)
	}

	return nil
}

// AdminDecideKYC lets an admin approve or reject a user's KYC submission.
func (uc *UserUseCase) AdminDecideKYC(ctx context.Context, targetUserID string, req *domain.AdminKYCDecisionRequest) error {
	user, err := uc.repo.FindByID(ctx, targetUserID)
	if err != nil {
		return apperrors.NewNotFoundError("User not found")
	}

	// Ensure user actually submitted KYC documents
	if strings.TrimSpace(user.NationalID) == "" || strings.TrimSpace(user.KYCImageURL) == "" {
		return apperrors.NewBadRequestError("User has not submitted KYC documents yet")
	}

	newStatus := domain.KYCStatus(req.Decision)
	if newStatus != domain.KYCStatusApproved && newStatus != domain.KYCStatusRejected {
		return apperrors.NewBadRequestError("Invalid KYC decision; must be 'approved' or 'rejected'")
	}

	if err := uc.repo.UpdateKYCStatus(ctx, targetUserID, newStatus); err != nil {
		return fmt.Errorf("usecase.AdminDecideKYC: %w", err)
	}

	return nil
}

// GetVerificationStatus returns the KYC/verification state for cross-module checks.
func (uc *UserUseCase) GetVerificationStatus(ctx context.Context, userID string) (*domain.UserVerificationStatus, error) {
	return uc.repo.GetVerificationStatus(ctx, userID)
}
