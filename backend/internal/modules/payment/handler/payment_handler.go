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

type rejectWithdrawalRequest struct {
	Reason string `json:"reason"`
}

type verifyWithdrawalCodeRequest struct {
	Code string `json:"code" validate:"required,len=6"`
}

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

	return c.JSON(http.StatusCreated, apperrors.NewSuccessResponse(map[string]interface{}{
		"id":                tx.Transaction.ID,
		"user_id":           tx.Transaction.UserID,
		"type":              tx.Transaction.Type,
		"amount":            tx.Transaction.Amount,
		"currency":          tx.Transaction.Currency,
		"status":            tx.Transaction.Status,
		"idempotency_key":   tx.Transaction.IdempotencyKey,
		"reference":         tx.Transaction.Reference,
		"description":       tx.Transaction.Description,
		"balance_before":    tx.Transaction.BalanceBefore,
		"balance_after":     tx.Transaction.BalanceAfter,
		"created_at":        tx.Transaction.CreatedAt,
		"updated_at":        tx.Transaction.UpdatedAt,
		"verification_code": tx.VerificationCode,
		"assigned_agent_id": tx.AssignedAgentID,
		"request_status":    tx.RequestStatus,
	}, nil))
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

// AdminGetTransactions handles GET /api/v1/admin/transactions
func (h *PaymentHandler) AdminGetTransactions(c echo.Context) error {
	page, _ := strconv.Atoi(c.QueryParam("page"))
	limit, _ := strconv.Atoi(c.QueryParam("limit"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}

	filter := domain.TransactionFilter{
		UserID: c.QueryParam("user_id"),
		Type:   domain.TransactionType(c.QueryParam("type")),
		Status: domain.TransactionStatus(c.QueryParam("status")),
	}

	txs, total, err := h.useCase.GetAllTransactions(c.Request().Context(), filter, page, limit)
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

// AdminGetWithdrawals handles GET /api/v1/admin/withdrawals
func (h *PaymentHandler) AdminGetWithdrawals(c echo.Context) error {
	page, _ := strconv.Atoi(c.QueryParam("page"))
	limit, _ := strconv.Atoi(c.QueryParam("limit"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}

	filter := domain.TransactionFilter{
		UserID: c.QueryParam("user_id"),
		Type:   domain.TransactionWithdraw,
		Status: domain.TransactionStatus(c.QueryParam("status")),
	}
	txs, total, err := h.useCase.GetAllTransactions(c.Request().Context(), filter, page, limit)
	if err != nil {
		appErr := apperrors.NewInternalError("Failed to get withdrawals")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	lastPage := int(math.Ceil(float64(total) / float64(limit)))
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(txs, &apperrors.PaginationMeta{
		Total:    total,
		Page:     page,
		LastPage: lastPage,
	}))
}

// AdminAdjustBalance handles POST /api/v1/admin/balance/adjust
func (h *PaymentHandler) AdminAdjustBalance(c echo.Context) error {
	adminID := c.Get("user_id").(string)
	var req domain.AdminBalanceAdjustmentRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	req.PerformedBy = adminID
	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	tx, err := h.useCase.AdminAdjustBalance(c.Request().Context(), &req)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to adjust balance")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusCreated, apperrors.NewSuccessResponse(tx, nil))
}

// AdminApproveWithdrawal handles POST /api/v1/admin/withdrawals/:id/approve
func (h *PaymentHandler) AdminApproveWithdrawal(c echo.Context) error {
	adminID := c.Get("user_id").(string)
	txID := c.Param("id")

	tx, err := h.useCase.ApproveWithdrawal(c.Request().Context(), txID, adminID)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to approve withdrawal")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(tx, nil))
}

// AdminRejectWithdrawal handles POST /api/v1/admin/withdrawals/:id/reject
func (h *PaymentHandler) AdminRejectWithdrawal(c echo.Context) error {
	adminID := c.Get("user_id").(string)
	txID := c.Param("id")
	var req rejectWithdrawalRequest
	_ = c.Bind(&req)

	tx, err := h.useCase.RejectWithdrawal(c.Request().Context(), txID, adminID, req.Reason)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to reject withdrawal")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(tx, nil))
}

// AdminDashboardSummary handles GET /api/v1/admin/dashboard/financial-summary
func (h *PaymentHandler) AdminDashboardSummary(c echo.Context) error {
	ctx := c.Request().Context()

	allTxs, _, err := h.useCase.GetAllTransactions(ctx, domain.TransactionFilter{}, 1, 1000)
	if err != nil {
		appErr := apperrors.NewInternalError("Failed to load financial summary")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	var totalDeposits float64
	var totalWithdrawals float64
	var totalBetWins float64
	var totalRefunds float64
	var pendingWithdrawals int
	for _, tx := range allTxs {
		if tx.Type == domain.TransactionDeposit && tx.Status == domain.TransactionCompleted {
			totalDeposits += tx.Amount
		}
		if tx.Type == domain.TransactionWithdraw {
			if tx.Status == domain.TransactionCompleted {
				totalWithdrawals += tx.Amount
			}
			if tx.Status == domain.TransactionPending {
				pendingWithdrawals++
			}
		}
		if tx.Type == domain.TransactionBetWin && tx.Status == domain.TransactionCompleted {
			totalBetWins += tx.Amount
		}
		if tx.Type == domain.TransactionRefund && tx.Status == domain.TransactionCompleted {
			totalRefunds += tx.Amount
		}
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]interface{}{
		"total_transactions":  len(allTxs),
		"total_deposits":      totalDeposits,
		"total_withdrawals":   totalWithdrawals,
		"total_bet_wins":      totalBetWins,
		"total_refunds":       totalRefunds,
		"net_cash_flow":       totalDeposits - totalWithdrawals,
		"pending_withdrawals": pendingWithdrawals,
	}, nil))
}

// AgentGetAssignedWithdrawals handles GET /api/v1/agent/withdrawals
func (h *PaymentHandler) AgentGetAssignedWithdrawals(c echo.Context) error {
	agentID := c.Get("user_id").(string)
	page, _ := strconv.Atoi(c.QueryParam("page"))
	limit, _ := strconv.Atoi(c.QueryParam("limit"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}
	status := domain.WithdrawalRequestStatus(c.QueryParam("status"))

	rows, total, err := h.useCase.GetAssignedWithdrawalsForAgent(c.Request().Context(), agentID, status, page, limit)
	if err != nil {
		appErr := apperrors.NewInternalError("Failed to get assigned withdrawals")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	lastPage := int(math.Ceil(float64(total) / float64(limit)))
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(rows, &apperrors.PaginationMeta{
		Total:    total,
		Page:     page,
		LastPage: lastPage,
	}))
}

// AgentVerifyWithdrawalByCode handles POST /api/v1/agent/withdrawals/verify
func (h *PaymentHandler) AgentVerifyWithdrawalByCode(c echo.Context) error {
	agentID := c.Get("user_id").(string)
	var req verifyWithdrawalCodeRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	tx, err := h.useCase.VerifyWithdrawalCode(c.Request().Context(), agentID, req.Code)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to verify withdrawal code")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(tx, nil))
}

// ─── Location-based Withdrawal Flow ─────────────────────────────────

// GetAgentsByLocation handles GET /api/v1/withdrawals/agents/:location
func (h *PaymentHandler) GetAgentsByLocation(c echo.Context) error {
	location := c.Param("location")
	if location == "" {
		appErr := apperrors.NewBadRequestError("Location is required")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	agents, err := h.useCase.GetAgentsByLocation(c.Request().Context(), location)
	if err != nil {
		appErr := apperrors.NewInternalError("Failed to get agents")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(agents, nil))
}

// CreateLocationBasedWithdrawal handles POST /api/v1/withdrawals
func (h *PaymentHandler) CreateLocationBasedWithdrawal(c echo.Context) error {
	userID := c.Get("user_id").(string)

	var req struct {
		Amount         float64 `json:"amount" validate:"required,gt=0"`
		Location       string  `json:"location" validate:"required"`
		AgentID        string  `json:"agent_id" validate:"required"`
		AccountDetails string  `json:"account_details" validate:"required"`
	}
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	createReq := &domain.CreateWithdrawalRequest{
		Amount:         req.Amount,
		Location:       req.Location,
		AccountDetails: req.AccountDetails,
	}

	withdrawal, err := h.useCase.CreateLocationBasedWithdrawal(c.Request().Context(), userID, createReq, req.AgentID)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to create withdrawal request")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(withdrawal, nil))
}

// ApproveWithdrawalByCode handles POST /api/v1/withdrawals/approve
func (h *PaymentHandler) ApproveWithdrawalByCode(c echo.Context) error {
	var req domain.ApproveWithdrawalRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	withdrawal, err := h.useCase.ApproveWithdrawalByCode(c.Request().Context(), req.Code)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to approve withdrawal")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(withdrawal, nil))
}

// CancelWithdrawalRequest handles DELETE /api/v1/withdrawals/:id
func (h *PaymentHandler) CancelWithdrawalRequest(c echo.Context) error {
	requestID := c.Param("id")
	if requestID == "" {
		appErr := apperrors.NewBadRequestError("Request ID is required")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	if err := h.useCase.CancelWithdrawalRequest(c.Request().Context(), requestID); err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to cancel withdrawal")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]string{
		"message": "Withdrawal request cancelled successfully",
	}, nil))
}
