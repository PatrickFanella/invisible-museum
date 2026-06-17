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
	listToursFn              func() ([]models.Tour, error)
	getTourFn                func(id string) (*models.Tour, error)
	createContributionFn     func(req models.ContributionRequest) (models.ContributionResponse, error)
	listContributionsFn      func(status string) ([]models.Contribution, error)
	updateContributionFn     func(id, status string) (*models.Contribution, error)
	listContributionsCalls   int
	updateContributionCalls  int
	nearbyLat                float64
	nearbyLng                float64
	nearbyRadiusM            int
	getTourID                string
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

func (f *fakeRepository) ListTours(_ context.Context) ([]models.Tour, error) {
	if f.listToursFn != nil {
		return f.listToursFn()
	}
	return nil, nil
}

func (f *fakeRepository) GetTour(_ context.Context, id string) (*models.Tour, error) {
	f.getTourID = id
	if f.getTourFn != nil {
		return f.getTourFn(id)
	}
	return nil, nil
}

func (f *fakeRepository) CreateContribution(_ context.Context, req models.ContributionRequest) (models.ContributionResponse, error) {
	f.createContributionReq = req
	return f.createContributionFn(req)
}

func (f *fakeRepository) ListContributions(_ context.Context, status string) ([]models.Contribution, error) {
	f.listContributionsCalls++
	f.listContributionsStatus = status
	if f.listContributionsFn != nil {
		return f.listContributionsFn(status)
	}
	return nil, nil
}

func (f *fakeRepository) UpdateContributionStatus(_ context.Context, id, status string) (*models.Contribution, error) {
	f.updateContributionCalls++
	f.updateContributionID = id
	f.updateContributionStatus = status
	if f.updateContributionFn != nil {
		return f.updateContributionFn(id, status)
	}
	return nil, nil
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

func TestAdminContributionModerationAuth(t *testing.T) {
	type testCase struct {
		name             string
		method           string
		path             string
		body             string
		headers          map[string]string
		adminToken       string
		wantStatus       int
		wantRepoCalls    int
		wantBodyContains string
	}

	listRepoFactory := func() *fakeRepository {
		return &fakeRepository{
			listContributionsFn: func(status string) ([]models.Contribution, error) {
				return []models.Contribution{{ID: "contrib-1", Status: models.ContributionStatusPending, SuggestedTitle: "Old photo"}}, nil
			},
		}
	}

	updateRepoFactory := func() *fakeRepository {
		return &fakeRepository{
			updateContributionFn: func(id, status string) (*models.Contribution, error) {
				spaceID := "sp-1"
				return &models.Contribution{ID: id, SpaceID: &spaceID, Status: models.ContributionStatus(status)}, nil
			},
		}
	}

	for _, tc := range []testCase{
		{name: "list missing header", method: http.MethodGet, path: "/api/v1/admin/contributions", adminToken: "server-token", wantStatus: http.StatusUnauthorized, wantRepoCalls: 0, wantBodyContains: "authorization header is required"},
		{name: "list malformed header", method: http.MethodGet, path: "/api/v1/admin/contributions", adminToken: "server-token", headers: map[string]string{"Authorization": "Bearer"}, wantStatus: http.StatusUnauthorized, wantRepoCalls: 0, wantBodyContains: "authorization must be Bearer"},
		{name: "list wrong token", method: http.MethodGet, path: "/api/v1/admin/contributions", adminToken: "server-token", headers: map[string]string{"Authorization": "Bearer wrong-token"}, wantStatus: http.StatusUnauthorized, wantRepoCalls: 0, wantBodyContains: "invalid admin token"},
		{name: "list correct token", method: http.MethodGet, path: "/api/v1/admin/contributions", adminToken: "server-token", headers: map[string]string{"Authorization": "Bearer server-token"}, wantStatus: http.StatusOK, wantRepoCalls: 1},
		{name: "list unset server token", method: http.MethodGet, path: "/api/v1/admin/contributions", adminToken: "", headers: map[string]string{"Authorization": "Bearer server-token"}, wantStatus: http.StatusServiceUnavailable, wantRepoCalls: 0, wantBodyContains: adminAuthNotConfiguredMessage},
		{name: "update missing header", method: http.MethodPatch, path: "/api/v1/admin/contributions/contrib-1/status", body: `{"status":"approved"}`, adminToken: "server-token", wantStatus: http.StatusUnauthorized, wantRepoCalls: 0, wantBodyContains: "authorization header is required"},
		{name: "update malformed header", method: http.MethodPatch, path: "/api/v1/admin/contributions/contrib-1/status", body: `{"status":"approved"}`, adminToken: "server-token", headers: map[string]string{"Authorization": "Bearer"}, wantStatus: http.StatusUnauthorized, wantRepoCalls: 0, wantBodyContains: "authorization must be Bearer"},
		{name: "update wrong token", method: http.MethodPatch, path: "/api/v1/admin/contributions/contrib-1/status", body: `{"status":"approved"}`, adminToken: "server-token", headers: map[string]string{"Authorization": "Bearer wrong-token"}, wantStatus: http.StatusUnauthorized, wantRepoCalls: 0, wantBodyContains: "invalid admin token"},
		{name: "update correct token", method: http.MethodPatch, path: "/api/v1/admin/contributions/contrib-1/status", body: `{"status":"approved"}`, adminToken: "server-token", headers: map[string]string{"Authorization": "Bearer server-token"}, wantStatus: http.StatusOK, wantRepoCalls: 1},
		{name: "update unset server token", method: http.MethodPatch, path: "/api/v1/admin/contributions/contrib-1/status", body: `{"status":"approved"}`, adminToken: "", headers: map[string]string{"Authorization": "Bearer server-token"}, wantStatus: http.StatusServiceUnavailable, wantRepoCalls: 0, wantBodyContains: adminAuthNotConfiguredMessage},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var repo *fakeRepository
			switch tc.method {
			case http.MethodGet:
				repo = listRepoFactory()
			case http.MethodPatch:
				repo = updateRepoFactory()
			default:
				t.Fatalf("unsupported method %s", tc.method)
			}

			h := NewHandlers(repo)
			router := NewRouter(h, tc.adminToken)
			req := httptest.NewRequest(tc.method, tc.path, strings.NewReader(tc.body))
			for key, value := range tc.headers {
				req.Header.Set(key, value)
			}
			rec := httptest.NewRecorder()

			router.ServeHTTP(rec, req)

			if rec.Code != tc.wantStatus {
				t.Fatalf("status = %d, want %d", rec.Code, tc.wantStatus)
			}
			if tc.wantRepoCalls == 0 {
				if repo.listContributionsCalls != 0 || repo.updateContributionCalls != 0 {
					t.Fatalf("repo was called: list=%d update=%d", repo.listContributionsCalls, repo.updateContributionCalls)
				}
			} else {
				if tc.method == http.MethodGet && repo.listContributionsCalls != 1 {
					t.Fatalf("list calls = %d, want 1", repo.listContributionsCalls)
				}
				if tc.method == http.MethodPatch && repo.updateContributionCalls != 1 {
					t.Fatalf("update calls = %d, want 1", repo.updateContributionCalls)
				}
			}
			if tc.wantBodyContains != "" {
				if got := strings.TrimSpace(rec.Body.String()); !strings.Contains(got, tc.wantBodyContains) {
					t.Fatalf("body = %s, want %q", got, tc.wantBodyContains)
				}
			}
			if tc.method == http.MethodGet && tc.wantStatus == http.StatusOK {
				var contributions []models.Contribution
				if err := json.Unmarshal(rec.Body.Bytes(), &contributions); err != nil {
					t.Fatalf("unmarshal response: %v", err)
				}
				if len(contributions) != 1 || contributions[0].ID != "contrib-1" {
					t.Fatalf("response = %#v, want contrib-1", contributions)
				}
			}
			if tc.method == http.MethodPatch && tc.wantStatus == http.StatusOK {
				if repo.updateContributionID != "contrib-1" || repo.updateContributionStatus != "approved" {
					t.Fatalf("repo args = (%q, %q), want (%q, %q)", repo.updateContributionID, repo.updateContributionStatus, "contrib-1", "approved")
				}
			}
		})
	}
}

func TestPublicContributionRouteWorksWithoutAuth(t *testing.T) {
	repo := &fakeRepository{
		createContributionFn: func(req models.ContributionRequest) (models.ContributionResponse, error) {
			return models.ContributionResponse{ID: "contrib-1", Status: "pending"}, nil
		},
	}
	h := NewHandlers(repo)
	router := NewRouter(h, "server-token")
	req := httptest.NewRequest(http.MethodPost, "/api/v1/contributions", strings.NewReader(`{"suggested_title":"Old photo","kind":"image","body":"A photo from the 1970s."}`))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusCreated)
	}
	if repo.createContributionReq.SuggestedTitle != "Old photo" {
		t.Fatalf("repo request = %#v", repo.createContributionReq)
	}
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

func TestTourRoutesReturnJSONShape(t *testing.T) {
	listRepo := &fakeRepository{
		listToursFn: func() ([]models.Tour, error) {
			return []models.Tour{{
				ID:               "tour-downtown-memory-loop",
				Title:            "Downtown Memory Loop",
				Summary:          "A short walk linking downtown landmarks.",
				EstimatedMinutes: 45,
				Published:        true,
				Stops: []models.TourStop{{
					ID:      "tour-stop-1",
					Order:   1,
					SpaceID: "sp-main-street-station",
					Space: models.TourSpace{
						ID:        "sp-main-street-station",
						Title:     "Main Street Station",
						Latitude:  41.7959,
						Longitude: -88.0092,
						Tagline:   "Downtown rail corridor",
					},
				}},
			}}, nil
		},
	}

	getRepo := &fakeRepository{
		getTourFn: func(id string) (*models.Tour, error) {
			if id != "tour-downtown-memory-loop" {
				t.Fatalf("repo id = %q, want tour-downtown-memory-loop", id)
			}
			return &models.Tour{
				ID:               "tour-downtown-memory-loop",
				Title:            "Downtown Memory Loop",
				Summary:          "A short walk linking downtown landmarks.",
				EstimatedMinutes: 45,
				Published:        true,
				Stops: []models.TourStop{{
					ID:      "tour-stop-1",
					Order:   1,
					SpaceID: "sp-main-street-station",
					Space: models.TourSpace{
						ID:        "sp-main-street-station",
						Title:     "Main Street Station",
						Latitude:  41.7959,
						Longitude: -88.0092,
						Tagline:   "Downtown rail corridor",
					},
				}},
			}, nil
		},
	}

	router := NewRouter(NewHandlers(listRepo), "")
	req := httptest.NewRequest(http.MethodGet, "/api/v1/tours", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("list status = %d, want %d", rec.Code, http.StatusOK)
	}
	var tours []map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &tours); err != nil {
		t.Fatalf("unmarshal list response: %v", err)
	}
	if len(tours) != 1 {
		t.Fatalf("len(tours) = %d, want 1", len(tours))
	}
	if got := tours[0]["title"]; got != "Downtown Memory Loop" {
		t.Fatalf("title = %v, want Downtown Memory Loop", got)
	}
	if got := tours[0]["published"]; got != true {
		t.Fatalf("published = %v, want true", got)
	}
	stops, ok := tours[0]["stops"].([]any)
	if !ok || len(stops) != 1 {
		t.Fatalf("stops = %#v, want 1 stop", tours[0]["stops"])
	}
	stop := stops[0].(map[string]any)
	if got := stop["order"]; got != float64(1) {
		t.Fatalf("stop order = %v, want 1", got)
	}
	space := stop["space"].(map[string]any)
	if got := space["id"]; got != "sp-main-street-station" {
		t.Fatalf("space id = %v, want sp-main-street-station", got)
	}
	if got := space["latitude"]; got != 41.7959 {
		t.Fatalf("space latitude = %v, want 41.7959", got)
	}

	router = NewRouter(NewHandlers(getRepo), "")
	req = httptest.NewRequest(http.MethodGet, "/api/v1/tours/tour-downtown-memory-loop", nil)
	rec = httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("get status = %d, want %d", rec.Code, http.StatusOK)
	}
	var tour map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &tour); err != nil {
		t.Fatalf("unmarshal get response: %v", err)
	}
	if got := tour["id"]; got != "tour-downtown-memory-loop" {
		t.Fatalf("id = %v, want tour-downtown-memory-loop", got)
	}
	if got := tour["title"]; got != "Downtown Memory Loop" {
		t.Fatalf("title = %v, want Downtown Memory Loop", got)
	}
	stops, ok = tour["stops"].([]any)
	if !ok || len(stops) != 1 {
		t.Fatalf("get stops = %#v, want 1 stop", tour["stops"])
	}

	router = NewRouter(NewHandlers(&fakeRepository{
		getTourFn: func(id string) (*models.Tour, error) {
			return nil, repository.ErrNotFound
		},
	}), "")
	req = httptest.NewRequest(http.MethodGet, "/api/v1/tours/missing-tour", nil)
	rec = httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("not found status = %d, want %d", rec.Code, http.StatusNotFound)
	}
	if got := strings.TrimSpace(rec.Body.String()); !strings.Contains(got, "not found") {
		t.Fatalf("not found body = %s, want not found", got)
	}
}
