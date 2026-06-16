package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"time"

	"invisible-museum/backend/internal/config"
	"invisible-museum/backend/internal/db"
	httpapi "invisible-museum/backend/internal/http"
	"invisible-museum/backend/internal/repository"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		slog.Error("load config", "error", err)
		os.Exit(1)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	pool, err := db.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		slog.Error("connect database", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	repo := repository.New(pool)
	handlers := httpapi.NewHandlers(repo)
	router := httpapi.NewRouter(handlers)

	server := &http.Server{
		Addr:              cfg.APIAddr,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
	}

	slog.Info("starting api", "addr", cfg.APIAddr)
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		slog.Error("api stopped", "error", err)
		os.Exit(1)
	}
}
