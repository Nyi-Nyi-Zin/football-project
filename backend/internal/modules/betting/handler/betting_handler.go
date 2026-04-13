package handler

import (
	"math"
	"net/http"
	"strconv"

	"betting-app/internal/modules/betting/domain"
	"betting-app/internal/modules/betting/usecase"
	apperrors "betting-app/internal/shared/errors"

	"github.com/go-playground/validator/v10"
	"github.com/labstack/echo/v4"
)

// BettingHandler handles HTTP requests for the betting module
type BettingHandler struct {
	useCase  *usecase.BettingUseCase
	validate *validator.Validate
}

// NewBettingHandler creates a new betting handler
func NewBettingHandler(useCase *usecase.BettingUseCase) *BettingHandler {
	return &BettingHandler{
		useCase:  useCase,
		validate: validator.New(),
	}
}

// PlaceBet handles POST /api/v1/bets
func (h *BettingHandler) PlaceBet(c echo.Context) error {
	userID := c.Get("user_id").(string)

	var req domain.PlaceBetRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	bet, err := h.useCase.PlaceBet(c.Request().Context(), userID, &req)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to place bet")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusCreated, apperrors.NewSuccessResponse(bet, nil))
}

// GetBet handles GET /api/v1/bets/:id
func (h *BettingHandler) GetBet(c echo.Context) error {
	betID := c.Param("id")

	bet, err := h.useCase.GetBet(c.Request().Context(), betID)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to get bet")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(bet, nil))
}

// GetMyBets handles GET /api/v1/bets/my
func (h *BettingHandler) GetMyBets(c echo.Context) error {
	userID := c.Get("user_id").(string)

	page, _ := strconv.Atoi(c.QueryParam("page"))
	limit, _ := strconv.Atoi(c.QueryParam("limit"))
	status := c.QueryParam("status")

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	filter := &domain.BetFilter{
		UserID: userID,
		Status: domain.BetStatus(status),
		Page:   page,
		Limit:  limit,
	}

	bets, total, err := h.useCase.GetUserBets(c.Request().Context(), filter)
	if err != nil {
		appErr := apperrors.NewInternalError("Failed to get bets")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	lastPage := int(math.Ceil(float64(total) / float64(limit)))

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(bets, &apperrors.PaginationMeta{
		Total:    total,
		Page:     page,
		LastPage: lastPage,
	}))
}

// CancelBet handles DELETE /api/v1/bets/:id
func (h *BettingHandler) CancelBet(c echo.Context) error {
	userID := c.Get("user_id").(string)
	betID := c.Param("id")

	if err := h.useCase.CancelBet(c.Request().Context(), userID, betID); err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to cancel bet")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]string{
		"message": "Bet cancelled successfully",
	}, nil))
}

// ListMatches handles GET /api/v1/matches
func (h *BettingHandler) ListMatches(c echo.Context) error {
	page, _ := strconv.Atoi(c.QueryParam("page"))
	limit, _ := strconv.Atoi(c.QueryParam("limit"))
	sport := c.QueryParam("sport")
	status := c.QueryParam("status")

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	matches, total, err := h.useCase.ListMatches(
		c.Request().Context(),
		sport,
		domain.MatchStatus(status),
		page, limit,
	)
	if err != nil {
		appErr := apperrors.NewInternalError("Failed to list matches")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	lastPage := int(math.Ceil(float64(total) / float64(limit)))

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(matches, &apperrors.PaginationMeta{
		Total:    total,
		Page:     page,
		LastPage: lastPage,
	}))
}
