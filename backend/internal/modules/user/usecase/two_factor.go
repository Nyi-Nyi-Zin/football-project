package usecase

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha1"
	"crypto/subtle"
	"encoding/base32"
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"io"
	"net/url"
	"strconv"
	"strings"
	"time"

	"betting-app/internal/modules/user/domain"
	apperrors "betting-app/internal/shared/errors"

	"gorm.io/gorm"
)

const twoFactorIssuer = "Football Project Agent"

func (uc *UserUseCase) BeginTwoFactorEnrollment(ctx context.Context, userID string) (*domain.TwoFactorEnrollment, error) {
	user, err := uc.repo.FindByID(ctx, userID)
	if err != nil || user == nil {
		return nil, apperrors.NewNotFoundError("User not found")
	}
	if user.Role != "agent" {
		return nil, apperrors.NewForbiddenError("Two-factor authentication is available for Agent accounts only")
	}
	secretBytes := make([]byte, 20)
	if _, err := io.ReadFull(rand.Reader, secretBytes); err != nil {
		return nil, fmt.Errorf("usecase.BeginTwoFactorEnrollment: generate secret: %w", err)
	}
	secret := base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(secretBytes)
	encrypted, err := uc.encryptTwoFactorSecret(secret)
	if err != nil {
		return nil, fmt.Errorf("usecase.BeginTwoFactorEnrollment: encrypt secret: %w", err)
	}
	if err := uc.repo.UpdateTwoFactorSecret(ctx, userID, encrypted, false); err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, apperrors.NewNotFoundError("User not found")
		}
		return nil, fmt.Errorf("usecase.BeginTwoFactorEnrollment: persist secret: %w", err)
	}
	return &domain.TwoFactorEnrollment{
		Secret:     secret,
		OtpauthURL: buildOTPAuthURL(user.Email, secret),
		Enabled:    false,
	}, nil
}

func (uc *UserUseCase) ConfirmTwoFactorEnrollment(ctx context.Context, userID string, req *domain.TwoFactorCodeRequest) (*domain.TwoFactorStatus, error) {
	user, err := uc.repo.FindByID(ctx, userID)
	if err != nil || user == nil {
		return nil, apperrors.NewNotFoundError("User not found")
	}
	if user.Role != "agent" {
		return nil, apperrors.NewForbiddenError("Two-factor authentication is available for Agent accounts only")
	}
	secret, err := uc.decryptTwoFactorSecret(user.TwoFactorSecretEncrypted)
	if err != nil || !verifyTOTP(secret, req.Code, time.Now().UTC()) {
		return nil, apperrors.NewUnauthorizedError("Invalid authenticator code")
	}
	if err := uc.repo.UpdateTwoFactorSecret(ctx, userID, user.TwoFactorSecretEncrypted, true); err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, apperrors.NewNotFoundError("User not found")
		}
		return nil, fmt.Errorf("usecase.ConfirmTwoFactorEnrollment: %w", err)
	}
	return &domain.TwoFactorStatus{Enabled: true}, nil
}

func (uc *UserUseCase) VerifyTwoFactorCode(ctx context.Context, userID string, req *domain.TwoFactorCodeRequest) (bool, error) {
	user, err := uc.repo.FindByID(ctx, userID)
	if err != nil || user == nil {
		return false, apperrors.NewNotFoundError("User not found")
	}
	if user.Role != "agent" || !user.TwoFactorEnabled {
		return false, apperrors.NewForbiddenError("Two-factor authentication is not enabled")
	}
	secret, err := uc.decryptTwoFactorSecret(user.TwoFactorSecretEncrypted)
	if err != nil || !verifyTOTP(secret, req.Code, time.Now().UTC()) {
		return false, apperrors.NewUnauthorizedError("Invalid authenticator code")
	}
	return true, nil
}

func (uc *UserUseCase) DisableTwoFactor(ctx context.Context, userID string, req *domain.TwoFactorCodeRequest) (*domain.TwoFactorStatus, error) {
	user, err := uc.repo.FindByID(ctx, userID)
	if err != nil || user == nil {
		return nil, apperrors.NewNotFoundError("User not found")
	}
	if user.Role != "agent" || !user.TwoFactorEnabled {
		return nil, apperrors.NewBadRequestError("Two-factor authentication is not enabled")
	}
	secret, err := uc.decryptTwoFactorSecret(user.TwoFactorSecretEncrypted)
	if err != nil || !verifyTOTP(secret, req.Code, time.Now().UTC()) {
		return nil, apperrors.NewUnauthorizedError("Invalid authenticator code")
	}
	if err := uc.repo.ClearTwoFactorSecret(ctx, userID); err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, apperrors.NewNotFoundError("User not found")
		}
		return nil, fmt.Errorf("usecase.DisableTwoFactor: %w", err)
	}
	return &domain.TwoFactorStatus{Enabled: false}, nil
}

func (uc *UserUseCase) GetTwoFactorStatus(ctx context.Context, userID string) (*domain.TwoFactorStatus, error) {
	user, err := uc.repo.FindByID(ctx, userID)
	if err != nil || user == nil {
		return nil, apperrors.NewNotFoundError("User not found")
	}
	if user.Role != "agent" {
		return nil, apperrors.NewForbiddenError("Two-factor authentication is available for Agent accounts only")
	}
	return &domain.TwoFactorStatus{Enabled: user.TwoFactorEnabled}, nil
}

func (uc *UserUseCase) encryptTwoFactorSecret(secret string) (string, error) {
	block, err := aes.NewCipher(uc.twoFactorKey)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}
	sealed := gcm.Seal(nonce, nonce, []byte(secret), nil)
	return base64.RawURLEncoding.EncodeToString(sealed), nil
}

func (uc *UserUseCase) decryptTwoFactorSecret(value string) (string, error) {
	if strings.TrimSpace(value) == "" {
		return "", fmt.Errorf("two-factor secret is not configured")
	}
	sealed, err := base64.RawURLEncoding.DecodeString(value)
	if err != nil {
		return "", err
	}
	block, err := aes.NewCipher(uc.twoFactorKey)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	if len(sealed) < gcm.NonceSize() {
		return "", fmt.Errorf("invalid two-factor secret")
	}
	nonce, ciphertext := sealed[:gcm.NonceSize()], sealed[gcm.NonceSize():]
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", err
	}
	return string(plaintext), nil
}

func buildOTPAuthURL(email, secret string) string {
	return "otpauth://totp/" + url.PathEscape(twoFactorIssuer) + ":" + url.PathEscape(email) +
		"?secret=" + url.QueryEscape(secret) + "&issuer=" + url.QueryEscape(twoFactorIssuer) + "&algorithm=SHA1&digits=6&period=30"
}

func verifyTOTP(secret, code string, now time.Time) bool {
	if len(code) != 6 {
		return false
	}
	for _, r := range code {
		if r < '0' || r > '9' {
			return false
		}
	}
	for offset := -1; offset <= 1; offset++ {
		candidate := totpCode(secret, now.Add(time.Duration(offset)*30*time.Second))
		if subtle.ConstantTimeCompare([]byte(candidate), []byte(code)) == 1 {
			return true
		}
	}
	return false
}

func totpCode(secret string, now time.Time) string {
	decoded, err := base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(strings.ToUpper(strings.TrimSpace(secret)))
	if err != nil {
		return ""
	}
	counter := uint64(now.Unix() / 30)
	var counterBytes [8]byte
	binary.BigEndian.PutUint64(counterBytes[:], counter)
	h := hmac.New(sha1.New, decoded)
	_, _ = h.Write(counterBytes[:])
	sum := h.Sum(nil)
	offset := sum[len(sum)-1] & 0x0f
	binaryCode := (uint32(sum[offset])&0x7f)<<24 | uint32(sum[offset+1])<<16 | uint32(sum[offset+2])<<8 | uint32(sum[offset+3])
	return fmt.Sprintf("%06s", strconv.Itoa(int(binaryCode%1000000)))
}
