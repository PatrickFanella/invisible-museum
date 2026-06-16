package config

import (
	"fmt"
	"os"
	"strings"
)

// Config holds runtime settings for the API.
type Config struct {
	APIAddr     string
	DatabaseURL string
}

// Load reads configuration from environment variables.
func Load() (Config, error) {
	addr := strings.TrimSpace(os.Getenv("API_ADDR"))
	if addr == "" {
		addr = ":8080"
	}

	databaseURL := strings.TrimSpace(os.Getenv("DATABASE_URL"))
	if databaseURL == "" {
		return Config{}, fmt.Errorf("DATABASE_URL is required")
	}

	return Config{APIAddr: addr, DatabaseURL: databaseURL}, nil
}
