package handler

import (
	"math"
	"net/http"
	"strconv"

	"betting-app/internal/modules/user/domain"
	"betting-app/internal/modules/user/usecase"
	apperrors "betting-app/internal/shared/errors"
	jwtpkg "betting-app/pkg/jwt"
	"betting-app/pkg/logger"

	"github.com/go-playground/validator/v10"
	"github.com/labstack/echo/v4"
)

// UserHandler handles HTTP requests for the user module
type UserHandler struct {
	useCase  *usecase.UserUseCase
	validate *validator.Validate
}

// NewUserHandler creates a new user handler
func NewUserHandler(useCase *usecase.UserUseCase) *UserHandler {
	return &UserHandler{
		useCase:  useCase,
		validate: validator.New(),
	}
}

// Register handles POST /api/v1/auth/register
func (h *UserHandler) Register(c echo.Context) error {
	var req domain.RegisterRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	profile, tokens, err := h.useCase.Register(c.Request().Context(), &req)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Registration failed")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusCreated, apperrors.NewSuccessResponse(map[string]interface{}{
		"user":   profile,
		"tokens": tokens,
	}, nil))
}

// Login handles POST /api/v1/auth/login
func (h *UserHandler) Login(c echo.Context) error {
	var req domain.LoginRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	profile, tokens, err := h.useCase.Login(c.Request().Context(), &req)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Login failed")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]interface{}{
		"user":   profile,
		"tokens": tokens,
	}, nil))
}

// Refresh handles POST /api/v1/auth/refresh
func (h *UserHandler) Refresh(c echo.Context) error {
	var req domain.RefreshTokenRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	profile, tokens, err := h.useCase.RefreshToken(c.Request().Context(), req.RefreshToken)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Token refresh failed")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]interface{}{
		"user":   profile,
		"tokens": tokens,
	}, nil))
}

// GetProfile handles GET /api/v1/users/me
func (h *UserHandler) GetProfile(c echo.Context) error {
	userID := c.Get("user_id").(string)

	profile, err := h.useCase.GetProfile(c.Request().Context(), userID)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to get profile")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(profile, nil))
}

// UpdateProfile handles PATCH /api/v1/users/me
func (h *UserHandler) UpdateProfile(c echo.Context) error {
	userID := c.Get("user_id").(string)

	var req domain.UpdateProfileRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	profile, err := h.useCase.UpdateProfile(c.Request().Context(), userID, &req)
	if err != nil {
		logger.Error("UpdateProfile failed", "error", err)
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to update profile")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(profile, nil))
}

// ChangePassword handles PATCH /api/v1/users/me/password
func (h *UserHandler) ChangePassword(c echo.Context) error {
	userID := c.Get("user_id").(string)

	var req domain.ChangePasswordRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	if err := h.useCase.ChangePassword(c.Request().Context(), userID, &req); err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to change password")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]string{
		"message": "Password changed successfully",
	}, nil))
}

// GetTwoFactorStatus handles GET /api/v1/agent/security/2fa.
func (h *UserHandler) GetTwoFactorStatus(c echo.Context) error {
	status, err := h.useCase.GetTwoFactorStatus(c.Request().Context(), c.Get("user_id").(string))
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to get two-factor status")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(status, nil))
}

// BeginTwoFactorEnrollment handles POST /api/v1/agent/security/2fa/enroll.
func (h *UserHandler) BeginTwoFactorEnrollment(c echo.Context) error {
	enrollment, err := h.useCase.BeginTwoFactorEnrollment(c.Request().Context(), c.Get("user_id").(string))
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to begin two-factor enrollment")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(enrollment, nil))
}

// ConfirmTwoFactorEnrollment handles POST /api/v1/agent/security/2fa/confirm.
func (h *UserHandler) ConfirmTwoFactorEnrollment(c echo.Context) error {
	var req domain.TwoFactorCodeRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	status, err := h.useCase.ConfirmTwoFactorEnrollment(c.Request().Context(), c.Get("user_id").(string), &req)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to confirm two-factor enrollment")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(status, nil))
}

// VerifyTwoFactorCode handles POST /api/v1/agent/security/2fa/verify.
func (h *UserHandler) VerifyTwoFactorCode(c echo.Context) error {
	var req domain.TwoFactorCodeRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	verified, err := h.useCase.VerifyTwoFactorCode(c.Request().Context(), c.Get("user_id").(string), &req)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to verify two-factor code")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]bool{"verified": verified}, nil))
}

// DisableTwoFactor handles POST /api/v1/agent/security/2fa/disable.
func (h *UserHandler) DisableTwoFactor(c echo.Context) error {
	var req domain.TwoFactorCodeRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	status, err := h.useCase.DisableTwoFactor(c.Request().Context(), c.Get("user_id").(string), &req)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to disable two-factor authentication")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(status, nil))
}

// ChangeSecurityPIN handles POST /api/v1/agent/security/pin.
func (h *UserHandler) ChangeSecurityPIN(c echo.Context) error {
	var req domain.ChangeSecurityPINRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	if err := h.useCase.ChangeSecurityPIN(c.Request().Context(), c.Get("user_id").(string), &req); err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to change security PIN")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]string{
		"message": "Security PIN changed successfully",
	}, nil))
}

// GetCurrentSecuritySession handles GET /api/v1/agent/security/sessions.
func (h *UserHandler) GetCurrentSecuritySession(c echo.Context) error {
	claims, _ := c.Get("claims").(*jwtpkg.Claims)
	session := h.useCase.CurrentSecuritySession(claims)
	if session == nil {
		appErr := apperrors.NewUnauthorizedError("Authenticated session is unavailable")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse([]*domain.SecuritySession{session}, nil))
}

// LogoutAllDevices handles POST /api/v1/agent/security/logout-all.
func (h *UserHandler) LogoutAllDevices(c echo.Context) error {
	version, err := h.useCase.LogoutAllDevices(c.Request().Context(), c.Get("user_id").(string))
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to revoke sessions")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]interface{}{
		"message":       "All sessions revoked",
		"token_version": version,
	}, nil))
}

// ListAgentCustomers handles GET /api/v1/agent/customers.
func (h *UserHandler) ListAgentCustomers(c echo.Context) error {
	agentID, ok := c.Get("user_id").(string)
	if !ok || agentID == "" {
		appErr := apperrors.NewUnauthorizedError("Agent authentication required")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	page, _ := strconv.Atoi(c.QueryParam("page"))
	limit, _ := strconv.Atoi(c.QueryParam("limit"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	profiles, total, err := h.useCase.ListAgentCustomers(
		c.Request().Context(),
		agentID,
		c.QueryParam("q"),
		page,
		limit,
	)
	if err != nil {
		appErr := apperrors.NewInternalError("Failed to list agent customers")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    profiles,
		"meta": &apperrors.PaginationMeta{
			Total:    total,
			Page:     page,
			LastPage: int(math.Ceil(float64(total) / float64(limit))),
		},
	})
}

// ListUsers handles GET /api/v1/users
func (h *UserHandler) ListUsers(c echo.Context) error {
	page, _ := strconv.Atoi(c.QueryParam("page"))
	limit, _ := strconv.Atoi(c.QueryParam("limit"))
	query := c.QueryParam("q")
	status := c.QueryParam("status")

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	profiles, total, stats, err := h.useCase.ListUsersAdmin(c.Request().Context(), query, status, page, limit)
	if err != nil {
		appErr := apperrors.NewInternalError("Failed to list users")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	lastPage := int(math.Ceil(float64(total) / float64(limit)))

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    profiles,
		"meta": &apperrors.PaginationMeta{
			Total:    total,
			Page:     page,
			LastPage: lastPage,
		},
		"stats": stats,
	})
}

// GetUserByID handles GET /api/v1/admin/users/:id
func (h *UserHandler) GetUserByID(c echo.Context) error {
	userID := c.Param("id")
	profile, err := h.useCase.GetProfileByID(c.Request().Context(), userID)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to get user profile")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(profile, nil))
}

// AdminCreateUser handles POST /api/v1/admin/users.
func (h *UserHandler) AdminCreateUser(c echo.Context) error {
	var req domain.AdminCreateUserRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	profile, err := h.useCase.AdminCreateUser(c.Request().Context(), &req)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to create user account")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusCreated, apperrors.NewSuccessResponse(profile, nil))
}

// AdminUpdateStatus handles PATCH /api/v1/admin/users/:id/status
func (h *UserHandler) AdminUpdateStatus(c echo.Context) error {
	userID := c.Param("id")
	var req domain.AdminUpdateStatusRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	profile, err := h.useCase.AdminUpdateStatus(c.Request().Context(), userID, &req)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to update user status")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(profile, nil))
}

// ─── KYC & Verification Endpoints ──────────────────────────────────────────

// VerifyEmail handles POST /api/v1/users/me/verify-email
func (h *UserHandler) VerifyEmail(c echo.Context) error {
	userID := c.Get("user_id").(string)

	var req domain.VerifyEmailRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	if err := h.useCase.VerifyEmail(c.Request().Context(), userID, &req); err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to verify email")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]string{
		"message": "Email verified successfully",
	}, nil))
}

// VerifyPhone handles POST /api/v1/users/me/verify-phone
func (h *UserHandler) VerifyPhone(c echo.Context) error {
	userID := c.Get("user_id").(string)

	var req domain.VerifyPhoneRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	if err := h.useCase.VerifyPhone(c.Request().Context(), userID, &req); err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to verify phone")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]string{
		"message": "Phone verified successfully",
	}, nil))
}

// SubmitKYC handles POST /api/v1/users/me/kyc
func (h *UserHandler) SubmitKYC(c echo.Context) error {
	userID := c.Get("user_id").(string)

	var req domain.SubmitKYCRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	if err := h.useCase.SubmitKYC(c.Request().Context(), userID, &req); err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to submit KYC")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]string{
		"message": "KYC documents submitted for review",
	}, nil))
}

// AdminDecideKYC handles POST /api/v1/admin/users/:id/kyc
func (h *UserHandler) AdminDecideKYC(c echo.Context) error {
	targetUserID := c.Param("id")

	var req domain.AdminKYCDecisionRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	if err := h.useCase.AdminDecideKYC(c.Request().Context(), targetUserID, &req); err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to process KYC decision")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]string{
		"message": "KYC decision recorded",
	}, nil))
}
