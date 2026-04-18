package middleware

import (
	"strings"
	"time"

	"betting-app/internal/shared/cache"
	apperrors "betting-app/internal/shared/errors"
	jwtpkg "betting-app/pkg/jwt"
	"betting-app/pkg/logger"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

// AuthMiddleware creates JWT authentication middleware
func AuthMiddleware(jwtManager *jwtpkg.Manager, redisClient *cache.RedisClient) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			authHeader := c.Request().Header.Get("Authorization")
			if authHeader == "" {
				appErr := apperrors.NewUnauthorizedError("Missing authorization header")
				return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
			}

			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || parts[0] != "Bearer" {
				appErr := apperrors.NewUnauthorizedError("Invalid authorization header format")
				return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
			}

			tokenString := parts[1]

			// Check if token is blacklisted
			blacklisted, err := redisClient.IsTokenBlacklisted(c.Request().Context(), tokenString)
			if err != nil {
				logger.Error("middleware.Auth: check blacklist failed", "error", err)
			}
			if blacklisted {
				appErr := apperrors.NewUnauthorizedError("Token has been revoked")
				return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
			}

			// Validate token
			claims, err := jwtManager.ValidateToken(tokenString)
			if err != nil {
				appErr := apperrors.NewUnauthorizedError("Invalid or expired token")
				return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
			}

			// Set user info in context
			c.Set("user_id", claims.UserID)
			c.Set("email", claims.Email)
			c.Set("role", claims.Role)
			c.Set("token", tokenString)

			return next(c)
		}
	}
}

// RequireRole enforces that the authenticated user has one of the allowed roles.
func RequireRole(allowedRoles ...string) echo.MiddlewareFunc {
	allowed := map[string]struct{}{}
	for _, role := range allowedRoles {
		allowed[role] = struct{}{}
	}

	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			role, ok := c.Get("role").(string)
			if !ok || role == "" {
				appErr := apperrors.NewForbiddenError("Role is required")
				return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
			}
			if _, exists := allowed[role]; !exists {
				appErr := apperrors.NewForbiddenError("Insufficient permissions")
				return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
			}
			return next(c)
		}
	}
}

// RateLimitMiddleware creates per-IP rate limiting middleware using Redis
func RateLimitMiddleware(redisClient *cache.RedisClient, maxRequests int, window time.Duration) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			ip := c.RealIP()
			key := "ratelimit:" + ip

			ctx := c.Request().Context()
			if redisClient == nil || redisClient.Client == nil {
				return next(c)
			}

			// Increment counter
			count, err := redisClient.Client.Incr(ctx, key).Result()
			if err != nil {
				logger.Error("middleware.RateLimit: incr failed", "error", err)
				return next(c) // Fail open
			}

			// Set TTL on first request
			if count == 1 {
				redisClient.Client.Expire(ctx, key, window)
			}

			if count > int64(maxRequests) {
				appErr := apperrors.NewTooManyRequestsError("Rate limit exceeded. Try again later.")
				return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
			}

			return next(c)
		}
	}
}

// LoggingMiddleware creates request logging middleware
func LoggingMiddleware() echo.MiddlewareFunc {
	return middleware.RequestLoggerWithConfig(middleware.RequestLoggerConfig{
		LogURI:     true,
		LogStatus:  true,
		LogMethod:  true,
		LogLatency: true,
		LogValuesFunc: func(c echo.Context, v middleware.RequestLoggerValues) error {
			logger.Info("request",
				"method", v.Method,
				"uri", v.URI,
				"status", v.Status,
				"latency", v.Latency.String(),
			)
			return nil
		},
	})
}

// CORSMiddleware creates CORS middleware
func CORSMiddleware() echo.MiddlewareFunc {
	return middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins: []string{"*"},
		AllowMethods: []string{echo.GET, echo.POST, echo.PUT, echo.PATCH, echo.DELETE, echo.OPTIONS},
		AllowHeaders: []string{
			echo.HeaderOrigin,
			echo.HeaderContentType,
			echo.HeaderAccept,
			echo.HeaderAuthorization,
			"X-Idempotency-Key",
		},
	})
}
