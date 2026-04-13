package event

import (
	"context"
	"fmt"
	"sync"

	"betting-app/pkg/logger"
)

// Event represents an internal event
type Event struct {
	Type    string
	Payload interface{}
}

// Handler is a function that handles an event
type Handler func(ctx context.Context, event Event) error

// Bus is an internal event bus (Kafka-ready interface)
type Bus struct {
	mu       sync.RWMutex
	handlers map[string][]Handler
}

// NewBus creates a new event bus
func NewBus() *Bus {
	return &Bus{
		handlers: make(map[string][]Handler),
	}
}

// Subscribe registers a handler for an event type
func (b *Bus) Subscribe(eventType string, handler Handler) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.handlers[eventType] = append(b.handlers[eventType], handler)
	logger.Info("Event handler subscribed", "event_type", eventType)
}

// Publish dispatches an event to all registered handlers
func (b *Bus) Publish(ctx context.Context, event Event) error {
	b.mu.RLock()
	handlers, exists := b.handlers[event.Type]
	b.mu.RUnlock()

	if !exists {
		return nil
	}

	for _, handler := range handlers {
		if err := handler(ctx, event); err != nil {
			logger.Error("Event handler failed",
				"event_type", event.Type,
				"error", err,
			)
			return fmt.Errorf("event.Publish: %s: %w", event.Type, err)
		}
	}

	return nil
}

// Event type constants
const (
	UserRegistered   = "user.registered"
	UserLoggedIn     = "user.logged_in"
	BetPlaced        = "bet.placed"
	BetSettled       = "bet.settled"
	BetCancelled     = "bet.cancelled"
	PaymentDeposit   = "payment.deposit"
	PaymentWithdraw  = "payment.withdraw"
	OddsUpdated      = "odds.updated"
	NotificationSent = "notification.sent"
)
