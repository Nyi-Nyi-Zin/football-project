package cache

import (
	"context"
	"fmt"
	"time"

	"betting-app/pkg/logger"

	"github.com/redis/go-redis/v9"
)

// RedisClient wraps the Redis client
type RedisClient struct {
	Client *redis.Client
}

// Connect initializes the Redis client
func Connect(redisURL string) (*RedisClient, error) {
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("cache.Connect: parse URL: %w", err)
	}

	client := redis.NewClient(opt)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("cache.Connect: ping: %w", err)
	}

	logger.Info("Redis connected successfully")
	return &RedisClient{Client: client}, nil
}

// Set stores a key-value pair with TTL
func (r *RedisClient) Set(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
	if r == nil || r.Client == nil { return nil }
	if err := r.Client.Set(ctx, key, value, ttl).Err(); err != nil {
		return fmt.Errorf("cache.Set: %w", err)
	}
	return nil
}

// Get retrieves a value by key
func (r *RedisClient) Get(ctx context.Context, key string) (string, error) {
	if r == nil || r.Client == nil { return "", nil }
	val, err := r.Client.Get(ctx, key).Result()
	if err != nil {
		return "", fmt.Errorf("cache.Get: %w", err)
	}
	return val, nil
}

// Delete removes a key
func (r *RedisClient) Delete(ctx context.Context, key string) error {
	if r == nil || r.Client == nil { return nil }
	if err := r.Client.Del(ctx, key).Err(); err != nil {
		return fmt.Errorf("cache.Delete: %w", err)
	}
	return nil
}

// Exists checks if a key exists
func (r *RedisClient) Exists(ctx context.Context, key string) (bool, error) {
	if r == nil || r.Client == nil { return false, nil }
	result, err := r.Client.Exists(ctx, key).Result()
	if err != nil {
		return false, fmt.Errorf("cache.Exists: %w", err)
	}
	return result > 0, nil
}

// BlacklistToken adds a JWT token to the blacklist
func (r *RedisClient) BlacklistToken(ctx context.Context, token string, ttl time.Duration) error {
	return r.Set(ctx, "blacklist:"+token, "1", ttl)
}

// IsTokenBlacklisted checks if a token is blacklisted
func (r *RedisClient) IsTokenBlacklisted(ctx context.Context, token string) (bool, error) {
	return r.Exists(ctx, "blacklist:"+token)
}

// Close closes the Redis connection
func (r *RedisClient) Close() error {
	if r == nil || r.Client == nil { return nil }
	return r.Client.Close()
}
