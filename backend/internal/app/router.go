package app

import (
	"time"

	bettingHandler "betting-app/internal/modules/betting/handler"
	notificationHandler "betting-app/internal/modules/notification/handler"
	oddsHandler "betting-app/internal/modules/odds/handler"
	paymentHandler "betting-app/internal/modules/payment/handler"
	userHandler "betting-app/internal/modules/user/handler"
	"betting-app/internal/shared/cache"
	"betting-app/internal/shared/middleware"
	jwtpkg "betting-app/pkg/jwt"

	"github.com/labstack/echo/v4"
)

// RegisterRoutes sets up all application routes
func RegisterRoutes(
	e *echo.Echo,
	jwtManager *jwtpkg.Manager,
	redisClient *cache.RedisClient,
	userH *userHandler.UserHandler,
	bettingH *bettingHandler.BettingHandler,
	paymentH *paymentHandler.PaymentHandler,
	oddsH *oddsHandler.OddsHandler,
	notificationH *notificationHandler.NotificationHandler,
) {
	// Global middleware
	e.Use(middleware.LoggingMiddleware())
	e.Use(middleware.CORSMiddleware())
	e.Use(middleware.RateLimitMiddleware(redisClient, 100, 1*time.Minute))

	// Health check
	e.GET("/health", func(c echo.Context) error {
		return c.JSON(200, map[string]string{"status": "healthy"})
	})

	// API v1 group
	v1 := e.Group("/api/v1")

	// --- Auth routes (public) ---
	auth := v1.Group("/auth")
	auth.POST("/register", userH.Register)
	auth.POST("/login", userH.Login)

	// --- Protected routes ---
	protected := v1.Group("")
	protected.Use(middleware.AuthMiddleware(jwtManager, redisClient))

	// User routes
	users := protected.Group("/users")
	users.GET("/me", userH.GetProfile)
	users.PATCH("/me", userH.UpdateProfile)
	users.GET("", userH.ListUsers) // Admin only — add role check middleware later

	// Betting routes
	bets := protected.Group("/bets")
	bets.POST("", bettingH.PlaceBet)
	bets.GET("/my", bettingH.GetMyBets)
	bets.GET("/:id", bettingH.GetBet)
	bets.DELETE("/:id", bettingH.CancelBet)

	// Match routes (public read, admin write)
	matches := v1.Group("/matches")
	matches.GET("", bettingH.ListMatches)

	// Payment routes
	payments := protected.Group("/payments")
	payments.POST("/deposit", paymentH.Deposit)
	payments.POST("/withdraw", paymentH.Withdraw)
	payments.GET("/balance", paymentH.GetBalance)
	payments.GET("/transactions", paymentH.GetTransactions)

	// Odds routes
	odds := v1.Group("/odds")
	odds.GET("/:matchId", oddsH.GetOdds)
	odds.GET("/:matchId/history", oddsH.GetOddsHistory)

	// Odds admin routes (protected)
	oddsAdmin := protected.Group("/odds")
	oddsAdmin.PUT("", oddsH.UpdateOdds)

	// Notification routes
	notifications := protected.Group("/notifications")
	notifications.GET("", notificationH.GetNotifications)
	notifications.GET("/unread-count", notificationH.GetUnreadCount)
	notifications.PATCH("/:id/read", notificationH.MarkAsRead)
	notifications.PATCH("/read-all", notificationH.MarkAllAsRead)
	notifications.DELETE("/:id", notificationH.DeleteNotification)

	// WebSocket route
	e.GET("/ws/odds", oddsH.HandleWebSocket)
}
