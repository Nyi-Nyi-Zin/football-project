package usecase

import (
	"testing"
	"time"
)

func TestTOTPVerificationAcceptsSmallClockSkew(t *testing.T) {
	secret := "JBSWY3DPEHPK3PXP"
	now := time.Unix(1_700_000_000, 0).UTC()
	code := totpCode(secret, now)
	if len(code) != 6 {
		t.Fatalf("code length = %d, want 6", len(code))
	}
	if !verifyTOTP(secret, code, now) {
		t.Fatal("expected current TOTP code to verify")
	}
	if !verifyTOTP(secret, code, now.Add(30*time.Second)) {
		t.Fatal("expected previous-window code to be accepted")
	}
	if verifyTOTP(secret, code, now.Add(3*time.Minute)) {
		t.Fatal("expected stale TOTP code to be rejected")
	}
}

func TestTwoFactorSecretEncryptionRoundTrips(t *testing.T) {
	uc := &UserUseCase{twoFactorKey: []byte("01234567890123456789012345678901")}
	secret := "JBSWY3DPEHPK3PXP"
	encrypted, err := uc.encryptTwoFactorSecret(secret)
	if err != nil {
		t.Fatalf("encrypt secret: %v", err)
	}
	if encrypted == secret || encrypted == "" {
		t.Fatal("expected encrypted secret to differ from plaintext")
	}
	decrypted, err := uc.decryptTwoFactorSecret(encrypted)
	if err != nil {
		t.Fatalf("decrypt secret: %v", err)
	}
	if decrypted != secret {
		t.Fatalf("decrypted secret = %q, want %q", decrypted, secret)
	}
}
