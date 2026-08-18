package jwt

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// Claims represents the JWT claims
type Claims struct {
	UserID       string `json:"user_id"`
	Email        string `json:"email"`
	Role         string `json:"role"`
	TokenType    string `json:"token_type"`
	TokenVersion int    `json:"token_version"`
	SessionID    string `json:"session_id"`
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

// GenerateTokenPair creates a new access + refresh token pair using version 1.
func (m *Manager) GenerateTokenPair(userID, email, role string) (*TokenPair, error) {
	return m.GenerateTokenPairWithVersion(userID, email, role, 1)
}

// GenerateTokenPairWithVersion creates tokens that can be revoked in bulk by version.
func (m *Manager) GenerateTokenPairWithVersion(userID, email, role string, tokenVersion int) (*TokenPair, error) {
	now := time.Now()
	sessionID := uuid.NewString()
	expiresAt := now.Add(m.expiry)

	// Access token
	accessClaims := &Claims{
		UserID:       userID,
		Email:        email,
		Role:         role,
		TokenType:    "access",
		TokenVersion: tokenVersion,
		SessionID:    sessionID,
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
		UserID:       userID,
		TokenType:    "refresh",
		TokenVersion: tokenVersion,
		SessionID:    sessionID,
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

func (m *Manager) ValidateAccessToken(tokenString string) (*Claims, error) {
	claims, err := m.ValidateToken(tokenString)
	if err != nil {
		return nil, err
	}
	if claims.TokenType != "access" {
		return nil, fmt.Errorf("jwt.ValidateAccessToken: invalid token type")
	}
	return claims, nil
}

func (m *Manager) ValidateRefreshToken(tokenString string) (*Claims, error) {
	claims, err := m.ValidateToken(tokenString)
	if err != nil {
		return nil, err
	}
	if claims.TokenType != "refresh" {
		return nil, fmt.Errorf("jwt.ValidateRefreshToken: invalid token type")
	}
	return claims, nil
}
