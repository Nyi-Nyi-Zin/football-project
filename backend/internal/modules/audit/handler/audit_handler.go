package handler

import (
	"net/http"
	"strconv"

	"betting-app/internal/modules/audit/domain"
	"betting-app/internal/modules/audit/usecase"
	apperrors "betting-app/internal/shared/errors"

	"github.com/labstack/echo/v4"
)

type AuditHandler struct {
	useCase *usecase.AuditUseCase
}

func NewAuditHandler(useCase *usecase.AuditUseCase) *AuditHandler {
	return &AuditHandler{useCase: useCase}
}

func (h *AuditHandler) List(c echo.Context) error {
	page, _ := strconv.Atoi(c.QueryParam("page"))
	limit, _ := strconv.Atoi(c.QueryParam("limit"))
	logs, total, err := h.useCase.List(c.Request().Context(), domain.AuditFilter{
		ActorID:      c.QueryParam("actor_id"),
		Action:       c.QueryParam("action"),
		ResourceType: c.QueryParam("resource_type"),
		Page:         page,
		Limit:        limit,
	})
	if err != nil {
		appErr := apperrors.NewInternalError("Unable to load audit history")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]interface{}{
		"items": logs,
		"total": total,
		"page":  page,
		"limit": limit,
	}, nil))
}
