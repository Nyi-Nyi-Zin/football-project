package handler

import (
	"math"
	"net/http"
	"strconv"

	"betting-app/internal/modules/user/domain"
	"betting-app/internal/modules/user/usecase"
	apperrors "betting-app/internal/shared/errors"

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
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to update profile")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(profile, nil))
}

// ListUsers handles GET /api/v1/users
func (h *UserHandler) ListUsers(c echo.Context) error {
	page, _ := strconv.Atoi(c.QueryParam("page"))
	limit, _ := strconv.Atoi(c.QueryParam("limit"))

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	profiles, total, err := h.useCase.ListUsers(c.Request().Context(), page, limit)
	if err != nil {
		appErr := apperrors.NewInternalError("Failed to list users")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	lastPage := int(math.Ceil(float64(total) / float64(limit)))

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(profiles, &apperrors.PaginationMeta{
		Total:    total,
		Page:     page,
		LastPage: lastPage,
	}))
}
