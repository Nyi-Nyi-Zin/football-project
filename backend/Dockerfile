# Build stage
FROM golang:1.25-alpine AS builder

RUN apk add --no-cache git

WORKDIR /app

# Copy dependency manifests first for better layer caching.
COPY go.mod go.sum ./
RUN go mod download

# Copy source code and migrations.
COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /app/server ./cmd/server

# Runtime stage
FROM alpine:3.21

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

COPY --from=builder /app/server ./server
COPY --from=builder /app/migrations ./migrations

ENV MIGRATIONS_DIR=/app/migrations

EXPOSE 8080

CMD ["./server"]
