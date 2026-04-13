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
