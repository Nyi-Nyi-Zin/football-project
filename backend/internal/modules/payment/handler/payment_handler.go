package handler

import (
	"math"
	"net/http"
	"strconv"

	"betting-app/internal/modules/payment/domain"
	"betting-app/internal/modules/payment/usecase"
	apperrors "betting-app/internal/shared/errors"

	"github.com/go-playground/validator/v10"
	"github.com/labstack/echo/v4"
)

// PaymentHandler handles HTTP requests for the payment module
type PaymentHandler struct {
	useCase  *usecase.PaymentUseCase
	validate *validator.Validate
}

// NewPaymentHandler creates a new payment handler
func NewPaymentHandler(useCase *usecase.PaymentUseCase) *PaymentHandler {
	return &PaymentHandler{
		useCase:  useCase,
		validate: validator.New(),
	}
}

// Deposit handles POST /api/v1/payments/deposit
func (h *PaymentHandler) Deposit(c echo.Context) error {
	userID := c.Get("user_id").(string)

	var req domain.DepositRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	// Allow idempotency key from header
	if req.IdempotencyKey == "" {
		req.IdempotencyKey = c.Request().Header.Get("X-Idempotency-Key")
	}

	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	tx, err := h.useCase.Deposit(c.Request().Context(), userID, &req)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Deposit failed")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusCreated, apperrors.NewSuccessResponse(tx, nil))
}

// Withdraw handles POST /api/v1/payments/withdraw
func (h *PaymentHandler) Withdraw(c echo.Context) error {
	userID := c.Get("user_id").(string)

	var req domain.WithdrawRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	if req.IdempotencyKey == "" {
		req.IdempotencyKey = c.Request().Header.Get("X-Idempotency-Key")
	}

	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	tx, err := h.useCase.Withdraw(c.Request().Context(), userID, &req)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Withdrawal failed")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusCreated, apperrors.NewSuccessResponse(tx, nil))
}

// GetBalance handles GET /api/v1/payments/balance
func (h *PaymentHandler) GetBalance(c echo.Context) error {
	userID := c.Get("user_id").(string)

	wallet, err := h.useCase.GetWallet(c.Request().Context(), userID)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to get wallet")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(wallet, nil))
}

// GetTransactions handles GET /api/v1/payments/transactions
func (h *PaymentHandler) GetTransactions(c echo.Context) error {
	userID := c.Get("user_id").(string)

	page, _ := strconv.Atoi(c.QueryParam("page"))
	limit, _ := strconv.Atoi(c.QueryParam("limit"))

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	txs, total, err := h.useCase.GetTransactions(c.Request().Context(), userID, page, limit)
	if err != nil {
		appErr := apperrors.NewInternalError("Failed to get transactions")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	lastPage := int(math.Ceil(float64(total) / float64(limit)))

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(txs, &apperrors.PaginationMeta{
		Total:    total,
		Page:     page,
		LastPage: lastPage,
	}))
}
