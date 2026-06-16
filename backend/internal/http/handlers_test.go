package httpapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"

	"invisible-museum/backend/internal/models"
	"invisible-museum/backend/internal/repository"
)

type fakeRepository struct {
	listSpacesFn             func() ([]models.Space, error)
	nearbySpacesFn           func(lat, lng float64, radiusM int) ([]models.Space, error)
	getSpaceFn               func(id string) (*models.Space, error)
	getExhibitFn             func(id string) (*models.Exhibit, error)
	createContributionFn     func(req models.ContributionRequest) (models.ContributionResponse, error)
	listContributionsFn      func(status string) ([]models.Contribution, error)
	updateContributionFn     func(id, status string) (*models.Contribution, error)
	nearbyLat                float64
	nearbyLng                float64
	nearbyRadiusM            int
	createContributionReq    models.ContributionRequest
	listContributionsStatus  string
	updateContributionID     string
	updateContributionStatus string
}

func (f *fakeRepository) ListSpaces(_ context.Context) ([]models.Space, error) {
	return f.listSpacesFn()
}

func (f *fakeRepository) NearbySpaces(_ context.Context, lat, lng float64, radiusM int) ([]models.Space, error) {
	f.nearbyLat = lat
	f.nearbyLng = lng
	f.nearbyRadiusM = radiusM
	return f.nearbySpacesFn(lat, lng, radiusM)
}

func (f *fakeRepository) GetSpace(_ context.Context, id string) (*models.Space, error) {
	return f.getSpaceFn(id)
}

func (f *fakeRepository) GetExhibit(_ context.Context, id string) (*models.Exhibit, error) {
	return f.getExhibitFn(id)
}

func (f *fakeRepository) CreateContribution(_ context.Context, req models.ContributionRequest) (models.ContributionResponse, error) {
	f.createContributionReq = req
	return f.createContributionFn(req)
}

func (f *fakeRepository) ListContributions(_ context.Context, status string) ([]models.Contribution, error) {
	f.listContributionsStatus = status
	return f.listContributionsFn(status)
}

func (f *fakeRepository) UpdateContributionStatus(_ context.Context, id, status string) (*models.Contribution, error) {
	f.updateContributionID = id
	f.updateContributionStatus = status
	return f.updateContributionFn(id, status)
}

func TestHealthz(t *testing.T) {
	h := NewHandlers(&fakeRepository{})
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()

	h.Healthz(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	if got := strings.TrimSpace(rec.Body.String()); got != `{"status":"ok"}` {
		t.Fatalf("body = %s, want %s", got, `{"status":"ok"}`)
	}
}

func TestListSpacesReturnsJSONArray(t *testing.T) {
	h := NewHandlers(&fakeRepository{
		listSpacesFn: func() ([]models.Space, error) {
			return []models.Space{{
				ID:               "sp-1",
				Name:             "Main Street Station",
				Tagline:          "Downtown rail corridor",
				Summary:          "A commuter rail landmark.",
				Latitude:         41.7959,
				Longitude:        -88.0092,
				RadiusMeters:     500,
				DistanceMeters:   120,
				Kind:             "station",
				ExhibitCount:     1,
				ContributorCount: 1,
				AccentHue:        210,
				IsDownloaded:     true,
				Exhibits:         []models.Exhibit{},
			}}, nil
		},
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/spaces", nil)
	rec := httptest.NewRecorder()

	h.ListSpaces(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	if ct := rec.Header().Get("Content-Type"); !strings.HasPrefix(ct, "application/json") {
		t.Fatalf("content-type = %q, want application/json", ct)
	}

	var spaces []map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &spaces); err != nil {
		t.Fatalf("unmarshal response: %v", err)
	}
	if len(spaces) != 1 {
		t.Fatalf("len(spaces) = %d, want 1", len(spaces))
	}
	if got := spaces[0]["name"]; got != "Main Street Station" {
		t.Fatalf("name = %v, want %q", got, "Main Street Station")
	}
	if got := spaces[0]["kind"]; got != "station" {
		t.Fatalf("kind = %v, want %q", got, "station")
	}
	if got := spaces[0]["radiusMeters"]; got != float64(500) {
		t.Fatalf("radiusMeters = %v, want 500", got)
	}
	if got := spaces[0]["distanceMeters"]; got != float64(120) {
		t.Fatalf("distanceMeters = %v, want 120", got)
	}
	if got := spaces[0]["exhibitCount"]; got != float64(1) {
		t.Fatalf("exhibitCount = %v, want 1", got)
	}
	if got := spaces[0]["contributorCount"]; got != float64(1) {
		t.Fatalf("contributorCount = %v, want 1", got)
	}
	if got := spaces[0]["isDownloaded"]; got != true {
		t.Fatalf("isDownloaded = %v, want true", got)
	}
	if exhibits, ok := spaces[0]["exhibits"].([]any); !ok || len(exhibits) != 0 {
		t.Fatalf("exhibits = %#v, want empty array", spaces[0]["exhibits"])
	}
}

func TestNearbySpacesValidationAndSuccess(t *testing.T) {
	repo := &fakeRepository{
		nearbySpacesFn: func(lat, lng float64, radiusM int) ([]models.Space, error) {
			return []models.Space{{
				ID:             "sp-nearby",
				Name:           "Nearby Space",
				DistanceMeters: 321,
				Exhibits:       []models.Exhibit{},
			}}, nil
		},
	}
	h := NewHandlers(repo)

	t.Run("missing query params", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/spaces/nearby", nil)
		rec := httptest.NewRecorder()

		h.NearbySpaces(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
		}
		if got := strings.TrimSpace(rec.Body.String()); !strings.Contains(got, "lat, lng, and radius_m are required") {
			t.Fatalf("body = %s, want required-query error", got)
		}
	})

	t.Run("invalid query values", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/spaces/nearby?lat=bad&lng=-88.007&radius_m=5000", nil)
		rec := httptest.NewRecorder()

		h.NearbySpaces(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
		}
		if got := strings.TrimSpace(rec.Body.String()); !strings.Contains(got, "lat must be a valid number") {
			t.Fatalf("body = %s, want lat parse error", got)
		}
	})

	t.Run("success", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/spaces/nearby?lat=41.794&lng=-88.007&radius_m=5000", nil)
		rec := httptest.NewRecorder()

		h.NearbySpaces(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
		}
		if repo.nearbyLat != 41.794 || repo.nearbyLng != -88.007 || repo.nearbyRadiusM != 5000 {
			t.Fatalf("repo args = (%v, %v, %d), want (41.794, -88.007, 5000)", repo.nearbyLat, repo.nearbyLng, repo.nearbyRadiusM)
		}

		var spaces []map[string]any
		if err := json.Unmarshal(rec.Body.Bytes(), &spaces); err != nil {
			t.Fatalf("unmarshal response: %v", err)
		}
		if len(spaces) != 1 {
			t.Fatalf("len(spaces) = %d, want 1", len(spaces))
		}
		if got := spaces[0]["distanceMeters"]; got != float64(321) {
			t.Fatalf("distanceMeters = %v, want 321", got)
		}
	})
}

func TestCreateContributionValidationAndSuccess(t *testing.T) {
	repo := &fakeRepository{
		createContributionFn: func(req models.ContributionRequest) (models.ContributionResponse, error) {
			return models.ContributionResponse{ID: "contrib-1", Status: "pending"}, nil
		},
	}
	h := NewHandlers(repo)

	t.Run("invalid", func(t *testing.T) {
		t.Run("empty body", func(t *testing.T) {
			req := httptest.NewRequest(http.MethodPost, "/api/v1/contributions", nil)
			rec := httptest.NewRecorder()

			h.CreateContribution(rec, req)

			if rec.Code != http.StatusBadRequest {
				t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
			}
			if got := strings.TrimSpace(rec.Body.String()); !strings.Contains(got, "invalid JSON body") {
				t.Fatalf("body = %s, want invalid JSON error", got)
			}
		})

		t.Run("missing required fields", func(t *testing.T) {
			req := httptest.NewRequest(http.MethodPost, "/api/v1/contributions", strings.NewReader(`{"suggested_title":"","kind":"image","body":""}`))
			rec := httptest.NewRecorder()

			h.CreateContribution(rec, req)

			if rec.Code != http.StatusBadRequest {
				t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
			}
			if got := strings.TrimSpace(rec.Body.String()); !strings.Contains(got, "suggested_title is required") {
				t.Fatalf("body = %s, want suggested_title error", got)
			}
		})
	})

	t.Run("valid", func(t *testing.T) {
		body := `{"space_id":"sp-main-street-station","suggested_title":"Old photo","kind":"image","body":"A photo from the 1970s.","contributor_name":"Resident"}`
		req := httptest.NewRequest(http.MethodPost, "/api/v1/contributions", strings.NewReader(body))
		rec := httptest.NewRecorder()

		h.CreateContribution(rec, req)

		if rec.Code != http.StatusCreated {
			t.Fatalf("status = %d, want %d", rec.Code, http.StatusCreated)
		}
		if repo.createContributionReq.SuggestedTitle != "Old photo" || repo.createContributionReq.Kind != "image" {
			t.Fatalf("repo request = %#v, want trimmed valid request", repo.createContributionReq)
		}

		var response models.ContributionResponse
		if err := json.Unmarshal(rec.Body.Bytes(), &response); err != nil {
			t.Fatalf("unmarshal response: %v", err)
		}
		if response.Status != "pending" || response.ID != "contrib-1" {
			t.Fatalf("response = %#v, want pending contrib-1", response)
		}
	})

	t.Run("invalid space_id", func(t *testing.T) {
		h := NewHandlers(&fakeRepository{
			createContributionFn: func(req models.ContributionRequest) (models.ContributionResponse, error) {
				return models.ContributionResponse{}, repository.ErrInvalidSpaceID
			},
		})

		req := httptest.NewRequest(http.MethodPost, "/api/v1/contributions", strings.NewReader(`{"space_id":"missing-space","suggested_title":"Old photo","kind":"image","body":"A photo from the 1970s.","contributor_name":"Resident"}`))
		rec := httptest.NewRecorder()

		h.CreateContribution(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
		}
		if got := strings.TrimSpace(rec.Body.String()); !strings.Contains(got, "space_id is invalid") {
			t.Fatalf("body = %s, want space_id validation error", got)
		}
	})
}

func TestAdminContributionModerationEndpoints(t *testing.T) {
	repo := &fakeRepository{
		listContributionsFn: func(status string) ([]models.Contribution, error) {
			return []models.Contribution{{
				ID:             "contrib-1",
				Status:         models.ContributionStatusPending,
				SuggestedTitle: "Old photo",
			}}, nil
		},
		updateContributionFn: func(id, status string) (*models.Contribution, error) {
			spaceID := "sp-1"
			return &models.Contribution{
				ID:      id,
				SpaceID: &spaceID,
				Status:  models.ContributionStatus(status),
			}, nil
		},
	}
	h := NewHandlers(repo)
	router := chi.NewRouter()
	router.Get("/admin/contributions", h.ListContributions)
	router.Patch("/admin/contributions/{id}/status", h.UpdateContributionStatus)

	t.Run("list defaults to pending", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/admin/contributions", nil)
		rec := httptest.NewRecorder()

		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
		}
		if repo.listContributionsStatus != string(models.ContributionStatusPending) {
			t.Fatalf("status filter = %q, want pending", repo.listContributionsStatus)
		}
		var contributions []models.Contribution
		if err := json.Unmarshal(rec.Body.Bytes(), &contributions); err != nil {
			t.Fatalf("unmarshal response: %v", err)
		}
		if len(contributions) != 1 || contributions[0].ID != "contrib-1" {
			t.Fatalf("response = %#v, want contrib-1", contributions)
		}
	})

	t.Run("list all", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/admin/contributions?status=all", nil)
		rec := httptest.NewRecorder()

		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
		}
		if repo.listContributionsStatus != "all" {
			t.Fatalf("status filter = %q, want all", repo.listContributionsStatus)
		}
	})

	t.Run("list rejects invalid status", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/admin/contributions?status=queued", nil)
		rec := httptest.NewRecorder()

		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
		}
		if got := strings.TrimSpace(rec.Body.String()); !strings.Contains(got, "status must be pending, approved, rejected, or all") {
			t.Fatalf("body = %s, want invalid filter error", got)
		}
	})

	t.Run("update status", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPatch, "/admin/contributions/contrib-1/status", strings.NewReader(`{"status":"approved"}`))
		rec := httptest.NewRecorder()

		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
		}
		if repo.updateContributionID != "contrib-1" || repo.updateContributionStatus != "approved" {
			t.Fatalf("repo args = (%q, %q), want (%q, %q)", repo.updateContributionID, repo.updateContributionStatus, "contrib-1", "approved")
		}
	})

	t.Run("reject invalid status", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPatch, "/admin/contributions/contrib-1/status", strings.NewReader(`{"status":"queued"}`))
		rec := httptest.NewRecorder()

		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
		}
		if got := strings.TrimSpace(rec.Body.String()); !strings.Contains(got, "status must be pending, approved, or rejected") {
			t.Fatalf("body = %s, want invalid status error", got)
		}
	})
}

func TestMissingRecordsReturn404(t *testing.T) {
	h := NewHandlers(&fakeRepository{
		getSpaceFn: func(id string) (*models.Space, error) {
			return nil, repository.ErrNotFound
		},
		getExhibitFn: func(id string) (*models.Exhibit, error) {
			return nil, repository.ErrNotFound
		},
	})

	router := chi.NewRouter()
	router.Get("/spaces/{space_id}", h.GetSpace)
	router.Get("/exhibits/{exhibit_id}", h.GetExhibit)

	for _, tc := range []struct {
		name string
		path string
	}{
		{name: "space", path: "/spaces/missing-space"},
		{name: "exhibit", path: "/exhibits/missing-exhibit"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, tc.path, nil)
			rec := httptest.NewRecorder()

			router.ServeHTTP(rec, req)

			if rec.Code != http.StatusNotFound {
				t.Fatalf("status = %d, want %d", rec.Code, http.StatusNotFound)
			}
			if got := strings.TrimSpace(rec.Body.String()); !strings.Contains(got, "not found") {
				t.Fatalf("body = %s, want not found", got)
			}
		})
	}
}
