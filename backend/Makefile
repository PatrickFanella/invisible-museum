.PHONY: up down test tidy

up:
	docker compose up --build

down:
	docker compose down

test:
	go test ./...

tidy:
	go mod tidy
