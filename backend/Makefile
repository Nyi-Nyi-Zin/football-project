.PHONY: run build test tidy docker-up docker-down migrate-up migrate-down

# Run the server
run:
	go run cmd/server/main.go

# Build the binary
build:
	CGO_ENABLED=0 go build -ldflags="-w -s" -o bin/server ./cmd/server

# Run tests
test:
	go test ./... -v -cover

# Tidy modules
tidy:
	go mod tidy

# Docker commands
docker-up:
	docker-compose up -d

docker-down:
	docker-compose down

docker-build:
	docker-compose build

docker-logs:
	docker-compose logs -f backend

# Database — start dependencies only
deps-up:
	docker-compose up -d postgres redis

deps-down:
	docker-compose down

# Migration commands (requires golang-migrate)
migrate-up:
	migrate -path migrations -database "$(DATABASE_URL)" up

migrate-down:
	migrate -path migrations -database "$(DATABASE_URL)" down

migrate-create:
	migrate create -ext sql -dir migrations -seq $(name)
