package handler

import (
	"math"
	"net/http"
	"strconv"
	"strings"

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

// PlaceBetSlip handles POST /api/v1/bets/slips
func (h *BettingHandler) PlaceBetSlip(c echo.Context) error {
	userID := c.Get("user_id").(string)

	var req domain.PlaceBetSlipRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	slip, err := h.useCase.PlaceBetSlip(c.Request().Context(), userID, &req)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to place bet slip")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusCreated, apperrors.NewSuccessResponse(slip, nil))
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

// SettleBet handles POST /api/v1/admin/bets/:id/settle
func (h *BettingHandler) SettleBet(c echo.Context) error {
	betID := c.Param("id")
	decision, err := h.useCase.SettleBet(c.Request().Context(), betID)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to settle bet")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(decision, nil))
}

// PreviewSettlement handles GET /api/v1/admin/bets/:id/settlement-preview
func (h *BettingHandler) PreviewSettlement(c echo.Context) error {
	betID := c.Param("id")
	decision, err := h.useCase.PreviewBetSettlement(c.Request().Context(), betID)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to preview settlement")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(decision, nil))
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

// GetMyBetSlips handles GET /api/v1/bets/slips/my
func (h *BettingHandler) GetMyBetSlips(c echo.Context) error {
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

	slips, total, err := h.useCase.GetUserBetSlips(c.Request().Context(), filter)
	if err != nil {
		appErr := apperrors.NewInternalError("Failed to get bet slips")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	lastPage := int(math.Ceil(float64(total) / float64(limit)))

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(slips, &apperrors.PaginationMeta{
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
	leagueFilters := make([]string, 0)
	if leagues := c.QueryParam("leagues"); leagues != "" {
		leagueFilters = append(leagueFilters, strings.Split(leagues, ",")...)
	}
	if league := c.QueryParam("league"); league != "" {
		leagueFilters = append(leagueFilters, league)
	}

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	matches, total, err := h.useCase.ListMatches(
		c.Request().Context(),
		sport,
		usecase.NormalizeLeagueFilters(leagueFilters),
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
