package jwt

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Claims represents the JWT claims
type Claims struct {
	UserID string `json:"user_id"`
	Email  string `json:"email"`
	Role   string `json:"role"`
	jwt.RegisteredClaims
}

// TokenPair contains both access and refresh tokens
type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresAt    int64  `json:"expires_at"`
}

// Manager handles JWT token operations
type Manager struct {
	secret        []byte
	expiry        time.Duration
	refreshExpiry time.Duration
}

// NewManager creates a new JWT manager
func NewManager(secret string, expiry, refreshExpiry time.Duration) *Manager {
	return &Manager{
		secret:        []byte(secret),
		expiry:        expiry,
		refreshExpiry: refreshExpiry,
	}
}

// GenerateTokenPair creates a new access + refresh token pair
func (m *Manager) GenerateTokenPair(userID, email, role string) (*TokenPair, error) {
	now := time.Now()
	expiresAt := now.Add(m.expiry)

	// Access token
	accessClaims := &Claims{
		UserID: userID,
		Email:  email,
		Role:   role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expiresAt),
			IssuedAt:  jwt.NewNumericDate(now),
			Subject:   userID,
		},
	}

	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessTokenString, err := accessToken.SignedString(m.secret)
	if err != nil {
		return nil, fmt.Errorf("jwt.GenerateTokenPair: access token: %w", err)
	}

	// Refresh token
	refreshClaims := &Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(now.Add(m.refreshExpiry)),
			IssuedAt:  jwt.NewNumericDate(now),
			Subject:   userID,
		},
	}

	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshTokenString, err := refreshToken.SignedString(m.secret)
	if err != nil {
		return nil, fmt.Errorf("jwt.GenerateTokenPair: refresh token: %w", err)
	}

	return &TokenPair{
		AccessToken:  accessTokenString,
		RefreshToken: refreshTokenString,
		ExpiresAt:    expiresAt.Unix(),
	}, nil
}

// ValidateToken validates a JWT token and returns its claims
func (m *Manager) ValidateToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("jwt.ValidateToken: unexpected signing method: %v", token.Header["alg"])
		}
		return m.secret, nil
	})

	if err != nil {
		return nil, fmt.Errorf("jwt.ValidateToken: %w", err)
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("jwt.ValidateToken: invalid token claims")
	}

	return claims, nil
}
