package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"

	"invisible-museum/backend/internal/models"
	"invisible-museum/backend/internal/repository"
)

// Repository describes the data access methods required by the HTTP handlers.
type Repository interface {
	ListSpaces(ctx context.Context) ([]models.Space, error)
	NearbySpaces(ctx context.Context, lat, lng float64, radiusM int) ([]models.Space, error)
	GetSpace(ctx context.Context, id string) (*models.Space, error)
	GetExhibit(ctx context.Context, id string) (*models.Exhibit, error)
	CreateContribution(ctx context.Context, req models.ContributionRequest) (models.ContributionResponse, error)
	ListContributions(ctx context.Context, status string) ([]models.Contribution, error)
	UpdateContributionStatus(ctx context.Context, id string, status string) (*models.Contribution, error)
}

// Handlers bundles the HTTP route handlers.
type Handlers struct {
	repo Repository
}

// NewHandlers creates a handler bundle.
func NewHandlers(repo Repository) *Handlers {
	return &Handlers{repo: repo}
}

// Healthz reports API health.
func (h *Handlers) Healthz(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// ListSpaces returns all spaces.
func (h *Handlers) ListSpaces(w http.ResponseWriter, r *http.Request) {
	spaces, err := h.repo.ListSpaces(r.Context())
	if err != nil {
		writeUnexpectedError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, spaces)
}

// NearbySpaces returns spaces near the supplied location.
func (h *Handlers) NearbySpaces(w http.ResponseWriter, r *http.Request) {
	lat, lng, radiusM, err := parseNearbyQuery(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	spaces, err := h.repo.NearbySpaces(r.Context(), lat, lng, radiusM)
	if err != nil {
		writeUnexpectedError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, spaces)
}

// GetSpace returns a single space.
func (h *Handlers) GetSpace(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimSpace(chi.URLParam(r, "space_id"))
	if id == "" {
		writeError(w, http.StatusBadRequest, "space_id is required")
		return
	}

	space, err := h.repo.GetSpace(r.Context(), id)
	if err != nil {
		writeRepoError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, space)
}

// GetExhibit returns a single exhibit.
func (h *Handlers) GetExhibit(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimSpace(chi.URLParam(r, "exhibit_id"))
	if id == "" {
		writeError(w, http.StatusBadRequest, "exhibit_id is required")
		return
	}

	exhibit, err := h.repo.GetExhibit(r.Context(), id)
	if err != nil {
		writeRepoError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, exhibit)
}

// CreateContribution stores a contribution request.
func (h *Handlers) CreateContribution(w http.ResponseWriter, r *http.Request) {
	var req models.ContributionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if err := validateContributionRequest(&req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	response, err := h.repo.CreateContribution(r.Context(), req)
	if err != nil {
		if errors.Is(err, repository.ErrInvalidSpaceID) {
			writeError(w, http.StatusBadRequest, "space_id is invalid")
			return
		}
		writeUnexpectedError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, response)
}

// ListContributions returns moderation queue items.
// Dev-only local prototype route: intentionally unauthenticated.
func (h *Handlers) ListContributions(w http.ResponseWriter, r *http.Request) {
	status, err := parseContributionStatusFilter(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	contributions, err := h.repo.ListContributions(r.Context(), status)
	if err != nil {
		writeUnexpectedError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, contributions)
}

// UpdateContributionStatus changes a moderation state.
// Dev-only local prototype route: intentionally unauthenticated.
func (h *Handlers) UpdateContributionStatus(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimSpace(chi.URLParam(r, "id"))
	if id == "" {
		writeError(w, http.StatusBadRequest, "id is required")
		return
	}

	var req struct {
		Status string `json:"status"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	status, err := normalizeContributionStatus(req.Status)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	updated, err := h.repo.UpdateContributionStatus(r.Context(), id, status)
	if err != nil {
		writeRepoError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, updated)
}

func parseNearbyQuery(r *http.Request) (float64, float64, int, error) {
	query := r.URL.Query()
	latRaw := strings.TrimSpace(query.Get("lat"))
	lngRaw := strings.TrimSpace(query.Get("lng"))
	radiusRaw := strings.TrimSpace(query.Get("radius_m"))
	if latRaw == "" || lngRaw == "" || radiusRaw == "" {
		return 0, 0, 0, fmt.Errorf("lat, lng, and radius_m are required")
	}

	lat, err := strconv.ParseFloat(latRaw, 64)
	if err != nil {
		return 0, 0, 0, fmt.Errorf("lat must be a valid number")
	}
	lng, err := strconv.ParseFloat(lngRaw, 64)
	if err != nil {
		return 0, 0, 0, fmt.Errorf("lng must be a valid number")
	}
	radiusM, err := strconv.Atoi(radiusRaw)
	if err != nil || radiusM <= 0 {
		return 0, 0, 0, fmt.Errorf("radius_m must be a positive integer")
	}
	return lat, lng, radiusM, nil
}

func validateContributionRequest(req *models.ContributionRequest) error {
	if req.SpaceID != nil && strings.TrimSpace(*req.SpaceID) == "" {
		return fmt.Errorf("space_id cannot be empty")
	}
	if strings.TrimSpace(req.SuggestedTitle) == "" {
		return fmt.Errorf("suggested_title is required")
	}
	if strings.TrimSpace(req.Kind) == "" {
		return fmt.Errorf("kind is required")
	}
	if strings.TrimSpace(req.Body) == "" {
		return fmt.Errorf("body is required")
	}
	if req.SpaceID != nil {
		trimmed := strings.TrimSpace(*req.SpaceID)
		req.SpaceID = &trimmed
	}
	req.SuggestedTitle = strings.TrimSpace(req.SuggestedTitle)
	req.Kind = strings.TrimSpace(req.Kind)
	req.Body = strings.TrimSpace(req.Body)
	req.ContributorName = strings.TrimSpace(req.ContributorName)
	return nil
}

func parseContributionStatusFilter(r *http.Request) (string, error) {
	status := strings.TrimSpace(strings.ToLower(r.URL.Query().Get("status")))
	if status == "" {
		return string(models.ContributionStatusPending), nil
	}
	if status == "all" {
		return status, nil
	}
	if normalized, err := normalizeContributionStatus(status); err == nil {
		return normalized, nil
	}
	return "", fmt.Errorf("status must be pending, approved, rejected, or all")
}

func normalizeContributionStatus(raw string) (string, error) {
	status := strings.TrimSpace(strings.ToLower(raw))
	if status == "" {
		return "", fmt.Errorf("status is required")
	}
	moderationStatus := models.ContributionStatus(status)
	if !moderationStatus.Valid() {
		return "", fmt.Errorf("status must be pending, approved, or rejected")
	}
	return status, nil
}

func writeRepoError(w http.ResponseWriter, err error) {
	if errors.Is(err, repository.ErrNotFound) {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	writeUnexpectedError(w, err)
}

func writeUnexpectedError(w http.ResponseWriter, _ error) {
	writeError(w, http.StatusInternalServerError, "internal server error")
}
