package app

import (
	"time"

	bettingHandler "betting-app/internal/modules/betting/handler"
	notificationHandler "betting-app/internal/modules/notification/handler"
	oddsHandler "betting-app/internal/modules/odds/handler"
	paymentHandler "betting-app/internal/modules/payment/handler"
	userDomain "betting-app/internal/modules/user/domain"
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
	userRepo userDomain.UserRepository,
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
	auth.POST("/refresh", userH.Refresh)

	// --- Protected routes ---
	protected := v1.Group("")
	protected.Use(middleware.AuthMiddleware(jwtManager, redisClient, userRepo))

	// User routes
	users := protected.Group("/users")
	users.GET("/me", userH.GetProfile)
	users.PATCH("/me", userH.UpdateProfile)
	users.PATCH("/me/password", userH.ChangePassword)
	users.GET("", userH.ListUsers, middleware.RequireRole("admin"))

	// Betting routes
	bets := protected.Group("/bets")
	bets.POST("", bettingH.PlaceBet)
	bets.POST("/slips", bettingH.PlaceBetSlip)
	bets.GET("/my", bettingH.GetMyBets)
	bets.GET("/slips/my", bettingH.GetMyBetSlips)
	bets.GET("/:id/cashout-quote", bettingH.GetCashOutQuote)
	bets.POST("/:id/cashout", bettingH.ExecuteCashOut)
	bets.GET("/:id", bettingH.GetBet)
	bets.DELETE("/:id", bettingH.CancelBet)

	// Match routes (public read, admin write)
	matches := v1.Group("/matches")
	matches.GET("", bettingH.ListMatches)

	// Payment routes
	payments := protected.Group("/payments")
	payments.GET("/balance", paymentH.GetBalance)
	payments.GET("/transactions", paymentH.GetTransactions)

	// Location-based withdrawal routes (public for agent listing, protected for actions)
	withdrawals := v1.Group("/withdrawals")
	withdrawals.GET("/locations", paymentH.GetAgentLocations)
	withdrawals.GET("/agents/:location", paymentH.GetAgentsByLocation)

	withdrawalsProtected := protected.Group("/withdrawals")
	withdrawalsProtected.GET("", paymentH.GetCustomerWithdrawals)
	withdrawalsProtected.POST("", paymentH.CreateLocationBasedWithdrawal)
	withdrawalsProtected.DELETE("/:id", paymentH.CancelWithdrawalRequest)

	// Odds routes
	odds := v1.Group("/odds")
	odds.GET("/:matchId", oddsH.GetOdds)
	odds.GET("/:matchId/history", oddsH.GetOddsHistory)

	// Odds admin routes (admin only)
	oddsAdmin := protected.Group("/odds")
	oddsAdmin.Use(middleware.RequireRole("admin"))
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

	// Admin routes
	admin := protected.Group("/admin")
	admin.Use(middleware.RequireRole("admin"))
	admin.GET("/users", userH.ListUsers)
	admin.GET("/users/:id", userH.GetUserByID)
	admin.PATCH("/users/:id/status", userH.AdminUpdateStatus)
	admin.GET("/transactions", paymentH.AdminGetTransactions)
	admin.GET("/bets/:id/settlement-preview", bettingH.PreviewSettlement)
	admin.POST("/bets/:id/settle", bettingH.SettleBet)
	admin.POST("/bets/slips/:id/settle", bettingH.SettleBetSlip)
	admin.GET("/withdrawals", paymentH.AdminGetWithdrawals)
	admin.POST("/withdrawals/:id/approve", paymentH.AdminApproveWithdrawal)
	admin.POST("/withdrawals/:id/reject", paymentH.AdminRejectWithdrawal)
	admin.POST("/balance/adjust", paymentH.AdminAdjustBalance)
	admin.GET("/dashboard/financial-summary", paymentH.AdminDashboardSummary)
	admin.GET("/wallet/reconciliation", paymentH.AdminWalletReconciliation)

	// Agent routes (isolated from admin routes)
	agent := protected.Group("/agent")
	agent.Use(middleware.RequireRole("agent"))
	agent.GET("/withdrawals", paymentH.AgentGetAssignedWithdrawals)
	agent.POST("/withdrawals/verify", paymentH.AgentVerifyWithdrawalByCode)
}
