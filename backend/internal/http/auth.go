package httpapi

import (
	"crypto/subtle"
	"net/http"
	"strings"
)

const adminAuthNotConfiguredMessage = "admin authentication not configured"

func adminAuthMiddleware(adminBearerToken string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if strings.TrimSpace(adminBearerToken) == "" {
				writeError(w, http.StatusServiceUnavailable, adminAuthNotConfiguredMessage)
				return
			}

			rawAuth := r.Header.Get("Authorization")
			if rawAuth == "" {
				writeError(w, http.StatusUnauthorized, "authorization header is required")
				return
			}

			if strings.TrimSpace(rawAuth) != rawAuth {
				writeError(w, http.StatusUnauthorized, "authorization must be Bearer <token>")
				return
			}

			scheme, token, ok := strings.Cut(rawAuth, " ")
			if !ok || scheme != "Bearer" || token == "" || strings.Contains(token, " ") {
				writeError(w, http.StatusUnauthorized, "authorization must be Bearer <token>")
				return
			}

			if subtle.ConstantTimeCompare([]byte(token), []byte(adminBearerToken)) != 1 {
				writeError(w, http.StatusUnauthorized, "invalid admin token")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
