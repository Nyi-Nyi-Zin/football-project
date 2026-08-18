package handler

import (
	"math"
	"net/http"
	"strconv"

	"betting-app/internal/modules/support/domain"
	"betting-app/internal/modules/support/usecase"
	apperrors "betting-app/internal/shared/errors"
	"github.com/go-playground/validator/v10"
	"github.com/labstack/echo/v4"
)

type SupportHandler struct {
	useCase  *usecase.SupportUseCase
	validate *validator.Validate
}

func NewSupportHandler(useCase *usecase.SupportUseCase) *SupportHandler {
	return &SupportHandler{useCase: useCase, validate: validator.New()}
}

func (h *SupportHandler) CreateTicket(c echo.Context) error {
	var req domain.CreateTicketRequest
	if err := c.Bind(&req); err != nil {
		return h.errorResponse(c, apperrors.NewBadRequestError("Invalid request body"))
	}
	if err := h.validate.Struct(&req); err != nil {
		return h.errorResponse(c, apperrors.NewValidationError("Validation failed", err.Error()))
	}
	ticket, err := h.useCase.CreateTicket(c.Request().Context(), c.Get("user_id").(string), &req)
	if err != nil {
		return h.handleError(c, err, "Failed to create support ticket")
	}
	return c.JSON(http.StatusCreated, apperrors.NewSuccessResponse(ticket, nil))
}

func (h *SupportHandler) ListTickets(c echo.Context) error {
	page, _ := strconv.Atoi(c.QueryParam("page"))
	limit, _ := strconv.Atoi(c.QueryParam("limit"))
	userID := c.Get("user_id").(string)
	role, _ := c.Get("role").(string)
	tickets, total, err := h.useCase.ListTickets(c.Request().Context(), userID, role, page, limit)
	if err != nil {
		return h.handleError(c, err, "Failed to list support tickets")
	}
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(tickets, &apperrors.PaginationMeta{
		Total: total, Page: page, LastPage: int(math.Ceil(float64(total) / float64(limit))),
	}))
}

func (h *SupportHandler) GetTicket(c echo.Context) error {
	ticket, err := h.useCase.GetTicket(c.Request().Context(), c.Param("id"), c.Get("user_id").(string), c.Get("role").(string))
	if err != nil {
		return h.handleError(c, err, "Failed to get support ticket")
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(ticket, nil))
}

func (h *SupportHandler) ListMessages(c echo.Context) error {
	messages, err := h.useCase.ListMessages(c.Request().Context(), c.Param("id"), c.Get("user_id").(string), c.Get("role").(string))
	if err != nil {
		return h.handleError(c, err, "Failed to get support messages")
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(messages, nil))
}

func (h *SupportHandler) AddMessage(c echo.Context) error {
	var req domain.AddMessageRequest
	if err := c.Bind(&req); err != nil {
		return h.errorResponse(c, apperrors.NewBadRequestError("Invalid request body"))
	}
	if err := h.validate.Struct(&req); err != nil {
		return h.errorResponse(c, apperrors.NewValidationError("Validation failed", err.Error()))
	}
	message, err := h.useCase.AddMessage(c.Request().Context(), c.Param("id"), c.Get("user_id").(string), c.Get("role").(string), &req)
	if err != nil {
		return h.handleError(c, err, "Failed to add support message")
	}
	return c.JSON(http.StatusCreated, apperrors.NewSuccessResponse(message, nil))
}

func (h *SupportHandler) UpdateStatus(c echo.Context) error {
	var req domain.UpdateStatusRequest
	if err := c.Bind(&req); err != nil {
		return h.errorResponse(c, apperrors.NewBadRequestError("Invalid request body"))
	}
	if err := h.validate.Struct(&req); err != nil {
		return h.errorResponse(c, apperrors.NewValidationError("Validation failed", err.Error()))
	}
	ticket, err := h.useCase.UpdateStatus(c.Request().Context(), c.Param("id"), c.Get("user_id").(string), req.Status)
	if err != nil {
		return h.handleError(c, err, "Failed to update support ticket")
	}
	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(ticket, nil))
}

func (h *SupportHandler) handleError(c echo.Context, err error, fallback string) error {
	if appErr, ok := err.(*apperrors.AppError); ok {
		return h.errorResponse(c, appErr)
	}
	return h.errorResponse(c, apperrors.NewInternalError(fallback))
}

func (h *SupportHandler) errorResponse(c echo.Context, appErr *apperrors.AppError) error {
	return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
}
