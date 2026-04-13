package handler

import (
	"math"
	"net/http"
	"strconv"

	"betting-app/internal/modules/notification/usecase"
	apperrors "betting-app/internal/shared/errors"

	"github.com/labstack/echo/v4"
)

// NotificationHandler handles HTTP requests for the notification module
type NotificationHandler struct {
	useCase *usecase.NotificationUseCase
}

// NewNotificationHandler creates a new notification handler
func NewNotificationHandler(useCase *usecase.NotificationUseCase) *NotificationHandler {
	return &NotificationHandler{
		useCase: useCase,
	}
}

// GetNotifications handles GET /api/v1/notifications
func (h *NotificationHandler) GetNotifications(c echo.Context) error {
	userID := c.Get("user_id").(string)

	page, _ := strconv.Atoi(c.QueryParam("page"))
	limit, _ := strconv.Atoi(c.QueryParam("limit"))
	unreadOnly := c.QueryParam("unread") == "true"

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}

	notifications, total, err := h.useCase.GetUserNotifications(c.Request().Context(), userID, unreadOnly, page, limit)
	if err != nil {
		appErr := apperrors.NewInternalError("Failed to get notifications")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	lastPage := int(math.Ceil(float64(total) / float64(limit)))

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(notifications, &apperrors.PaginationMeta{
		Total:    total,
		Page:     page,
		LastPage: lastPage,
	}))
}

// GetUnreadCount handles GET /api/v1/notifications/unread-count
func (h *NotificationHandler) GetUnreadCount(c echo.Context) error {
	userID := c.Get("user_id").(string)

	count, err := h.useCase.GetUnreadCount(c.Request().Context(), userID)
	if err != nil {
		appErr := apperrors.NewInternalError("Failed to get unread count")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]int64{
		"unread_count": count,
	}, nil))
}

// MarkAsRead handles PATCH /api/v1/notifications/:id/read
func (h *NotificationHandler) MarkAsRead(c echo.Context) error {
	notificationID := c.Param("id")

	if err := h.useCase.MarkAsRead(c.Request().Context(), notificationID); err != nil {
		appErr := apperrors.NewInternalError("Failed to mark notification as read")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]string{
		"message": "Notification marked as read",
	}, nil))
}

// MarkAllAsRead handles PATCH /api/v1/notifications/read-all
func (h *NotificationHandler) MarkAllAsRead(c echo.Context) error {
	userID := c.Get("user_id").(string)

	if err := h.useCase.MarkAllAsRead(c.Request().Context(), userID); err != nil {
		appErr := apperrors.NewInternalError("Failed to mark all notifications as read")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]string{
		"message": "All notifications marked as read",
	}, nil))
}

// DeleteNotification handles DELETE /api/v1/notifications/:id
func (h *NotificationHandler) DeleteNotification(c echo.Context) error {
	notificationID := c.Param("id")

	if err := h.useCase.Delete(c.Request().Context(), notificationID); err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to delete notification")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(map[string]string{
		"message": "Notification deleted",
	}, nil))
}
