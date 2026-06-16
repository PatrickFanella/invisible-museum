package httpapi

import (
	"net/http"

	"github.com/go-chi/chi/v5"
)

// NewRouter wires all API routes.
func NewRouter(h *Handlers) http.Handler {
	r := chi.NewRouter()
	r.Get("/healthz", h.Healthz)
	r.Route("/api/v1", func(r chi.Router) {
		r.Get("/spaces", h.ListSpaces)
		r.Get("/spaces/nearby", h.NearbySpaces)
		r.Get("/spaces/{space_id}", h.GetSpace)
		r.Get("/exhibits/{exhibit_id}", h.GetExhibit)
		r.Post("/contributions", h.CreateContribution)
		// Dev-only moderation endpoints for the local prototype; intentionally unauthenticated.
		r.Route("/admin", func(r chi.Router) {
			r.Get("/contributions", h.ListContributions)
			r.Patch("/contributions/{id}/status", h.UpdateContributionStatus)
		})
	})
	return r
}
