package handler

import (
	"encoding/json"
	"net/http"
	"strconv"
	"sync"

	"betting-app/internal/modules/odds/domain"
	"betting-app/internal/modules/odds/usecase"
	apperrors "betting-app/internal/shared/errors"
	"betting-app/pkg/logger"

	"github.com/go-playground/validator/v10"
	"github.com/gorilla/websocket"
	"github.com/labstack/echo/v4"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins in development
	},
}

// OddsHandler handles HTTP and WebSocket requests for the odds module
type OddsHandler struct {
	useCase  *usecase.OddsUseCase
	validate *validator.Validate
	hub      *WebSocketHub
}

// NewOddsHandler creates a new odds handler
func NewOddsHandler(useCase *usecase.OddsUseCase) *OddsHandler {
	h := &OddsHandler{
		useCase:  useCase,
		validate: validator.New(),
		hub:      NewWebSocketHub(),
	}
	go h.hub.Run()
	return h
}

// GetOdds handles GET /api/v1/odds/:matchId
func (h *OddsHandler) GetOdds(c echo.Context) error {
	matchID := c.Param("matchId")

	odds, err := h.useCase.GetOdds(c.Request().Context(), matchID)
	if err != nil {
		if appErr, ok := err.(*apperrors.AppError); ok {
			return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
		}
		appErr := apperrors.NewInternalError("Failed to get odds")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(odds, nil))
}

// UpdateOdds handles PUT /api/v1/odds (admin)
func (h *OddsHandler) UpdateOdds(c echo.Context) error {
	var req domain.UpdateOddsRequest
	if err := c.Bind(&req); err != nil {
		appErr := apperrors.NewBadRequestError("Invalid request body")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	if err := h.validate.Struct(&req); err != nil {
		appErr := apperrors.NewValidationError("Validation failed", err.Error())
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	odds, err := h.useCase.UpdateOdds(c.Request().Context(), &req)
	if err != nil {
		appErr := apperrors.NewInternalError("Failed to update odds")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	// Broadcast to WebSocket clients
	h.hub.Broadcast(domain.OddsUpdate{
		Type: "ODDS_UPDATE",
		Payload: domain.OddsPayload{
			MatchID:  req.MatchID,
			HomeOdds: req.HomeOdds,
			AwayOdds: req.AwayOdds,
			DrawOdds: req.DrawOdds,
		},
	})

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(odds, nil))
}

// GetOddsHistory handles GET /api/v1/odds/:matchId/history
func (h *OddsHandler) GetOddsHistory(c echo.Context) error {
	matchID := c.Param("matchId")
	limit, _ := strconv.Atoi(c.QueryParam("limit"))
	if limit <= 0 {
		limit = 50
	}

	history, err := h.useCase.GetOddsHistory(c.Request().Context(), matchID, limit)
	if err != nil {
		appErr := apperrors.NewInternalError("Failed to get odds history")
		return c.JSON(appErr.StatusCode, apperrors.NewErrorResponse(appErr))
	}

	return c.JSON(http.StatusOK, apperrors.NewSuccessResponse(history, nil))
}

// HandleWebSocket handles GET /ws/odds — WebSocket connection for live odds
func (h *OddsHandler) HandleWebSocket(c echo.Context) error {
	ws, err := upgrader.Upgrade(c.Response(), c.Request(), nil)
	if err != nil {
		logger.Error("WebSocket upgrade failed", "error", err)
		return err
	}

	client := &WebSocketClient{
		hub:  h.hub,
		conn: ws,
		send: make(chan []byte, 256),
	}

	h.hub.register <- client

	go client.writePump()
	go client.readPump()

	return nil
}

// GetHub returns the WebSocket hub for external broadcasting
func (h *OddsHandler) GetHub() *WebSocketHub {
	return h.hub
}

// --- WebSocket Hub ---

// WebSocketClient represents a single WebSocket connection
type WebSocketClient struct {
	hub  *WebSocketHub
	conn *websocket.Conn
	send chan []byte
}

// WebSocketHub maintains the set of active clients and broadcasts messages
type WebSocketHub struct {
	clients    map[*WebSocketClient]bool
	Broadcast_ chan []byte
	register   chan *WebSocketClient
	unregister chan *WebSocketClient
	mu         sync.RWMutex
}

// NewWebSocketHub creates a new hub
func NewWebSocketHub() *WebSocketHub {
	return &WebSocketHub{
		clients:    make(map[*WebSocketClient]bool),
		Broadcast_: make(chan []byte),
		register:   make(chan *WebSocketClient),
		unregister: make(chan *WebSocketClient),
	}
}

// Run starts the hub's event loop
func (h *WebSocketHub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()
			logger.Info("WebSocket client connected", "total_clients", len(h.clients))

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
			}
			h.mu.Unlock()
			logger.Info("WebSocket client disconnected", "total_clients", len(h.clients))

		case message := <-h.Broadcast_:
			h.mu.RLock()
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(h.clients, client)
				}
			}
			h.mu.RUnlock()
		}
	}
}

// Broadcast sends a message to all connected clients
func (h *WebSocketHub) Broadcast(data interface{}) {
	msg, err := json.Marshal(data)
	if err != nil {
		logger.Error("Failed to marshal broadcast message", "error", err)
		return
	}
	h.Broadcast_ <- msg
}

func (c *WebSocketClient) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	for {
		_, _, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				logger.Error("WebSocket read error", "error", err)
			}
			break
		}
	}
}

func (c *WebSocketClient) writePump() {
	defer c.conn.Close()

	for {
		message, ok := <-c.send
		if !ok {
			c.conn.WriteMessage(websocket.CloseMessage, []byte{})
			return
		}

		if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
			logger.Error("WebSocket write error", "error", err)
			return
		}
	}
}
