# Go PostgreSQL Backend Implementation Plan

> **For agentic workers:** Execute this plan task-by-task. Recommended path:
> dispatch a fresh subagent per task, review each result with `review-quality`,
> then continue. For complex multi-agent splits, use
> `parallel-feature-development`, `team-composition-patterns`, and
> `team-communication-protocols`. Steps use checkbox (`- [ ]`) syntax for
> tracking.

**Goal:** Build a Dockerized Go REST API backed by PostgreSQL so the iOS prototype can load museum spaces, exhibits, nearby POIs, and submit contributions without hardcoded Swift sample data.

**Architecture:** Add a new `backend/` service beside the iOS app. The API uses a small layered Go structure: HTTP handlers call repositories backed by PostgreSQL, migrations own schema, and seed data provides Downers Grove test content. The iOS app keeps `SampleData.swift` as fallback while adding an API client in a later task.

**Tech Stack:** Go 1.22+, `chi` router, `pgx` PostgreSQL driver, `goose` migrations, Docker Compose, PostgreSQL 16, Swift `URLSession` client integration.

---

## Current app context

- iOS app path: `ios-invisible-museum/InvisibleMuseum/`
- Current data model: `Models.swift` defines the canonical API shapes for `MuseumSpace`, `Exhibit`, `SpaceKind`, `ExhibitKind`, `ExhibitStatus`, and `ExhibitConfidence`.
- Current store: `MuseumStore.swift` seeds `spaces` from `SampleData.spaces` and keeps `savedExhibitIDs` / `downloadedSpaceIDs` in memory only.
- No backend, API client, auth, local database, or persistence currently exists.
- `ContributeView.swift` is UI-only; its submit button does not send data anywhere.

---

## File map

### Create backend files

- `backend/go.mod` — Go module and dependencies.
- `backend/go.sum` — Dependency lockfile after `go mod tidy`.
- `backend/Dockerfile` — Multi-stage Go API build.
- `backend/docker-compose.yml` — Local API + PostgreSQL stack.
- `backend/.env.example` — Development environment reference.
- `backend/Makefile` — Common local commands.
- `backend/cmd/api/main.go` — API entrypoint, config load, DB connect, router start.
- `backend/internal/config/config.go` — Environment parsing.
- `backend/internal/db/db.go` — PostgreSQL pool creation and health check.
- `backend/internal/http/router.go` — Route registration.
- `backend/internal/http/respond.go` — JSON and error responses.
- `backend/internal/http/handlers.go` — REST handlers.
- `backend/internal/models/models.go` — API/domain structs matching the Swift data shape.
- `backend/internal/repository/repository.go` — SQL repository for spaces, exhibits, and contributions.
- `backend/migrations/00001_init.sql` — Tables and indexes.
- `backend/migrations/00002_seed_downers_grove.sql` — Local test POIs and exhibits.
- `backend/internal/http/handlers_test.go` — Handler tests using mocked repository behavior where possible.

### Modify iOS files after backend API is working

- `ios-invisible-museum/InvisibleMuseum/MuseumStore.swift` — Load spaces from repository instead of only `SampleData.spaces`.
- Create `ios-invisible-museum/InvisibleMuseum/APIClient.swift` — `URLSession` API client.
- Create `ios-invisible-museum/InvisibleMuseum/MuseumRepository.swift` — API-first, sample-fallback data boundary.
- Modify `ios-invisible-museum/InvisibleMuseum/ContributeView.swift` — Submit contributions to backend.
- Modify `ios-invisible-museum/InvisibleMuseum.xcodeproj/project.pbxproj` — Add new Swift files to the app target if Xcode does not auto-add them.

---

## API contract

The backend must emit Swift-compatible camelCase JSON. DB tables may use snake_case internally, but API responses must match the current Swift models exactly.

### MuseumSpace JSON

`id`, `name`, `tagline`, `summary`, `latitude`, `longitude`, `radiusMeters`, `distanceMeters`, `kind`, `exhibitCount`, `contributorCount`, `accentHue`, `isDownloaded`, `exhibits`

### SpaceKind values

`plaza`, `station`, `storefront`, `ruin`, `garden`, `hall`

### Exhibit JSON

`id`, `title`, `kind`, `body`, `year`, `contributor`, `tags`, `status`, `confidence`, `offset`, `durationSeconds`, `likes`

### ExhibitKind values

`story`, `image`, `audio`, `artifact`, `timeline`, `thread`

### ExhibitStatus values

`published`, `underReview`

### ExhibitConfidence values

`high`, `medium`, `low`

### Health

```http
GET /healthz
```

Response:

```json
{"status":"ok"}
```

### List spaces

```http
GET /api/v1/spaces
```

Response shape: an array of `MuseumSpace` objects using the JSON fields listed above.

### Nearby spaces

```http
GET /api/v1/spaces/nearby?lat=41.794&lng=-88.007&radius_m=5000
```

Distance can start as a Haversine SQL expression. PostGIS is intentionally deferred until the prototype needs advanced geospatial querying.

Response shape: same `MuseumSpace` contract, with `distanceMeters` populated.

### Space detail

```http
GET /api/v1/spaces/{space_id}
```

Returns a space with nested exhibits.

Response shape: one `MuseumSpace` object including `exhibits`.

### Exhibit detail

```http
GET /api/v1/exhibits/{exhibit_id}
```

Response shape: one `Exhibit` object.

### Submit contribution

```http
POST /api/v1/contributions
Content-Type: application/json

{
  "space_id": "sp-main-street",
  "suggested_title": "Old photo of Main Street",
  "kind": "image",
  "body": "Family photo taken near the station in the 1970s.",
  "contributor_name": "Local resident"
}
```

Response:

```json
{
  "id": "generated-uuid",
  "status": "pending"
}
```

---

## Task 1: Backend scaffold and Docker stack

**Files:**
- Create: `backend/go.mod`
- Create: `backend/Dockerfile`
- Create: `backend/docker-compose.yml`
- Create: `backend/.env.example`
- Create: `backend/Makefile`
- Create: `backend/cmd/api/main.go`

- [ ] **Step 1: Create the Go module**

Run:

```bash
mkdir -p backend/cmd/api backend/internal/{config,db,http,models,repository} backend/migrations
cd backend
go mod init invisible-museum/backend
go get github.com/go-chi/chi/v5 github.com/jackc/pgx/v5/pgxpool
go mod tidy
```

Expected: `backend/go.mod` and `backend/go.sum` exist.

- [ ] **Step 2: Add the initial API entrypoint**

Create `backend/cmd/api/main.go`:

```go
package main

import (
    "encoding/json"
    "log/slog"
    "net/http"
    "os"
)

func main() {
    addr := os.Getenv("API_ADDR")
    if addr == "" {
        addr = ":8080"
    }

    mux := http.NewServeMux()
    mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        _ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
    })

    slog.Info("starting api", "addr", addr)
    if err := http.ListenAndServe(addr, mux); err != nil {
        slog.Error("api stopped", "error", err)
        os.Exit(1)
    }
}
```

- [ ] **Step 3: Add Docker files**

Create `backend/Dockerfile`:

```dockerfile
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/api ./cmd/api

FROM alpine:3.20
RUN adduser -D -H appuser
USER appuser
COPY --from=build /out/api /api
EXPOSE 8080
ENTRYPOINT ["/api"]
```

Create `backend/docker-compose.yml`:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: invisible_museum
      POSTGRES_USER: museum
      POSTGRES_PASSWORD: museum
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U museum -d invisible_museum"]
      interval: 5s
      timeout: 5s
      retries: 10

  api:
    build: .
    environment:
      API_ADDR: ":8080"
      DATABASE_URL: "postgres://museum:museum@postgres:5432/invisible_museum?sslmode=disable"
    ports:
      - "8080:8080"
    depends_on:
      migrate:
        condition: service_completed_successfully

volumes:
  postgres_data:
```

Create `backend/.env.example`:

```env
API_ADDR=:8080
DATABASE_URL=postgres://museum:museum@localhost:5432/invisible_museum?sslmode=disable
```

Create `backend/Makefile`:

```makefile
.PHONY: up down test tidy

up:
	docker compose up --build

down:
	docker compose down

test:
	go test ./...

tidy:
	go mod tidy
```

- [ ] **Step 4: Verify health endpoint**

Run:

```bash
cd backend
docker compose up --build
```

In another shell:

```bash
curl http://localhost:8080/healthz
```

Expected:

```json
{"status":"ok"}
```

---

## Task 2: Schema, migrations, and Downers Grove seed data

**Files:**
- Create: `backend/migrations/00001_init.sql`
- Create: `backend/migrations/00002_seed_downers_grove.sql`
- Modify: `backend/docker-compose.yml`

- [ ] **Step 1: Add schema migration**

Create `backend/migrations/00001_init.sql`:

```sql
-- +goose Up
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE spaces (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  tagline TEXT NOT NULL DEFAULT '',
  summary TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  radius_meters DOUBLE PRECISION NOT NULL DEFAULT 0,
  distance_meters DOUBLE PRECISION NOT NULL DEFAULT 0,
  kind TEXT NOT NULL,
  exhibit_count INTEGER NOT NULL DEFAULT 0,
  contributor_count INTEGER NOT NULL DEFAULT 0,
  accent_hue DOUBLE PRECISION NOT NULL DEFAULT 0,
  is_downloaded BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE exhibits (
  id TEXT PRIMARY KEY,
  space_id TEXT NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  kind TEXT NOT NULL,
  body TEXT NOT NULL,
  year TEXT NOT NULL DEFAULT '',
  contributor TEXT NOT NULL DEFAULT '',
  tags TEXT[] NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'published',
  confidence TEXT NOT NULL DEFAULT 'medium',
  offset_x REAL NOT NULL DEFAULT 0,
  offset_y REAL NOT NULL DEFAULT 0,
  offset_z REAL NOT NULL DEFAULT 0,
  duration_seconds INTEGER,
  likes INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE contributions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id TEXT REFERENCES spaces(id) ON DELETE SET NULL,
  suggested_title TEXT NOT NULL,
  kind TEXT NOT NULL,
  body TEXT NOT NULL,
  contributor_name TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX spaces_lat_lng_idx ON spaces(latitude, longitude);
CREATE INDEX exhibits_space_id_idx ON exhibits(space_id);
CREATE INDEX contributions_status_idx ON contributions(status);

-- +goose Down
DROP TABLE IF EXISTS contributions;
DROP TABLE IF EXISTS exhibits;
DROP TABLE IF EXISTS spaces;
```

- [ ] **Step 2: Add seed migration**

Create `backend/migrations/00002_seed_downers_grove.sql` with local test content near Downers Grove, IL:

```sql
-- +goose Up
INSERT INTO spaces (id, name, tagline, summary, latitude, longitude, radius_meters, distance_meters, kind, exhibit_count, contributor_count, accent_hue, is_downloaded)
VALUES
  ('sp-main-street-station', 'Main Street Station', 'Downtown Downers Grove rail corridor', 'A commuter rail landmark anchoring the historic downtown corridor and daily movement through Downers Grove.', 41.7959, -88.0092, 500, 120, 'station', 1, 1, 0.58, true),
  ('sp-tivoli-theatre', 'Tivoli Theatre', 'Historic downtown movie palace', 'A restored theater and recognizable downtown marquee connected to local entertainment memory.', 41.7952, -88.0099, 500, 220, 'hall', 1, 1, 0.72, true),
  ('sp-fishel-park', 'Fishel Park', 'Civic green and concert space', 'A community gathering place near downtown used for concerts, events, and everyday public life.', 41.7944, -88.0118, 500, 340, 'garden', 1, 1, 0.34, false),
  ('sp-downers-grove-museum', 'Downers Grove Museum', 'Local history campus', 'A local history site preserving stories, buildings, and artifacts from the village and surrounding area.', 41.8083, -88.0111, 500, 980, 'plaza', 1, 1, 0.12, true)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  tagline = EXCLUDED.tagline,
  summary = EXCLUDED.summary,
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  radius_meters = EXCLUDED.radius_meters,
  distance_meters = EXCLUDED.distance_meters,
  kind = EXCLUDED.kind,
  exhibit_count = EXCLUDED.exhibit_count,
  contributor_count = EXCLUDED.contributor_count,
  accent_hue = EXCLUDED.accent_hue,
  is_downloaded = EXCLUDED.is_downloaded;

INSERT INTO exhibits (id, space_id, title, kind, body, year, contributor, tags, status, confidence, offset_x, offset_y, offset_z, duration_seconds, likes)
VALUES
  ('ex-main-street-commute', 'sp-main-street-station', 'Morning Platform', 'story', 'Stand near the tracks and imagine the repeated choreography of arrivals, departures, coffee cups, school bags, and winter coats. The station is less a single monument than a rhythm repeated by generations of residents.', '20th century', 'Invisible Museum seed archive', ARRAY['rail', 'commute', 'downtown'], 'published', 'medium', 0.0, 0.0, 0.0, 120, 8),
  ('ex-tivoli-marquee', 'sp-tivoli-theatre', 'The Marquee After Dark', 'image', 'The theater marquee turns the street into a small stage. Its glow gives downtown a point of orientation and preserves the feeling of a shared night out.', '1920s-present', 'Invisible Museum seed archive', ARRAY['theater', 'neon', 'downtown'], 'published', 'medium', 0.2, 0.0, 0.0, NULL, 12),
  ('ex-fishel-summer', 'sp-fishel-park', 'Summer Concert Lawn', 'audio', 'The park can be read as an outdoor archive: folding chairs, blankets, children running between songs, and the temporary village that appears whenever music starts.', 'present day', 'Community placeholder', ARRAY['park', 'music', 'civic'], 'underReview', 'low', -0.2, 0.0, 0.0, 95, 5),
  ('ex-museum-house', 'sp-downers-grove-museum', 'House as Artifact', 'artifact', 'A museum building is not only a container for artifacts. It is itself evidence: material choices, room scale, thresholds, and wear patterns all speak.', '19th-20th century', 'Invisible Museum seed archive', ARRAY['museum', 'architecture', 'local history'], 'published', 'high', 0.0, 0.1, 0.0, NULL, 20)
ON CONFLICT (id) DO UPDATE SET
  space_id = EXCLUDED.space_id,
  title = EXCLUDED.title,
  kind = EXCLUDED.kind,
  body = EXCLUDED.body,
  year = EXCLUDED.year,
  contributor = EXCLUDED.contributor,
  tags = EXCLUDED.tags,
  status = EXCLUDED.status,
  confidence = EXCLUDED.confidence,
  offset_x = EXCLUDED.offset_x,
  offset_y = EXCLUDED.offset_y,
  offset_z = EXCLUDED.offset_z,
  duration_seconds = EXCLUDED.duration_seconds,
  likes = EXCLUDED.likes;

-- +goose Down
DELETE FROM exhibits WHERE id IN ('ex-main-street-commute', 'ex-tivoli-marquee', 'ex-fishel-summer', 'ex-museum-house');
DELETE FROM spaces WHERE id IN ('sp-main-street-station', 'sp-tivoli-theatre', 'sp-fishel-park', 'sp-downers-grove-museum');
```

- [ ] **Step 3: Add a migration runner service**

Modify `backend/docker-compose.yml` to include:

```yaml
  migrate:
    image: gomicro/goose:3.24.1
    environment:
      GOOSE_DRIVER: postgres
      GOOSE_DBSTRING: postgres://museum:museum@postgres:5432/invisible_museum?sslmode=disable
    volumes:
      - ./migrations:/migrations
    command: ["goose", "-dir", "/migrations", "up"]
    depends_on:
      migrate:
        condition: service_completed_successfully
```

- [ ] **Step 4: Verify seeded database**

Run:

```bash
cd backend
docker compose up postgres migrate
docker compose exec postgres psql -U museum -d invisible_museum -c "select id, name from spaces order by name;"
```

Expected rows include `Tivoli Theatre`, `Main Street Station`, `Fishel Park`, and `Downers Grove Museum`.

---

## Task 3: Go models, repository, and API routes

**Files:**
- Create: `backend/internal/models/models.go`
- Create: `backend/internal/repository/repository.go`
- Create: `backend/internal/http/respond.go`
- Create: `backend/internal/http/router.go`
- Create: `backend/internal/http/handlers.go`
- Modify: `backend/cmd/api/main.go`

- [ ] **Step 1: Define API models**

Create `backend/internal/models/models.go`:

```go
package models

type Space struct {
    ID               string    `json:"id"`
    Name             string    `json:"name"`
    Tagline          string    `json:"tagline"`
    Summary          string    `json:"summary"`
    Latitude         float64   `json:"latitude"`
    Longitude        float64   `json:"longitude"`
    RadiusMeters     float64   `json:"radiusMeters"`
    DistanceMeters    float64   `json:"distanceMeters"`
    Kind             string    `json:"kind"`
    ExhibitCount     int       `json:"exhibitCount"`
    ContributorCount int       `json:"contributorCount"`
    AccentHue        float64   `json:"accentHue"`
    IsDownloaded     bool      `json:"isDownloaded"`
    Exhibits         []Exhibit `json:"exhibits"`
}

type Exhibit struct {
    ID              string    `json:"id"`
    Title           string    `json:"title"`
    Kind            string    `json:"kind"`
    Body            string    `json:"body"`
    Year            string    `json:"year"`
    Contributor     string    `json:"contributor"`
    Tags            []string  `json:"tags"`
    Status          string    `json:"status"`
    Confidence      string    `json:"confidence"`
    Offset          [3]float64 `json:"offset"`
    DurationSeconds *int      `json:"durationSeconds"`
    Likes           int       `json:"likes"`
}

type ContributionRequest struct {
    SpaceID          *string `json:"space_id"`
    SuggestedTitle   string  `json:"suggested_title"`
    Kind             string  `json:"kind"`
    Body             string  `json:"body"`
    ContributorName  string  `json:"contributor_name"`
}

type ContributionResponse struct {
    ID     string `json:"id"`
    Status string `json:"status"`
}
```

- [ ] **Step 2: Implement SQL repository**

Create `backend/internal/repository/repository.go` with methods:

```go
package repository

import (
    "context"
    "errors"
    "math"

    "github.com/jackc/pgx/v5"
    "github.com/jackc/pgx/v5/pgxpool"

    "invisible-museum/backend/internal/models"
)

var ErrNotFound = errors.New("not found")

type Repository struct {
    db *pgxpool.Pool
}

func New(db *pgxpool.Pool) *Repository { return &Repository{db: db} }

func (r *Repository) ListSpaces(ctx context.Context) ([]models.Space, error) {
    rows, err := r.db.Query(ctx, `SELECT id,name,tagline,summary,latitude,longitude,radius_meters,distance_meters,kind,exhibit_count,contributor_count,accent_hue,is_downloaded FROM spaces ORDER BY name`)
    if err != nil { return nil, err }
    defer rows.Close()
    return scanSpaces(rows)
}

func (r *Repository) NearbySpaces(ctx context.Context, lat, lng float64, radiusM int) ([]models.Space, error) {
    rows, err := r.db.Query(ctx, `
        SELECT id,name,tagline,summary,latitude,longitude,radius_meters,distance_meters,kind,exhibit_count,contributor_count,accent_hue,is_downloaded
        FROM spaces
        WHERE (6371000 * 2 * asin(sqrt(power(sin(radians((latitude - $1) / 2)), 2) + cos(radians($1)) * cos(radians(latitude)) * power(sin(radians((longitude - $2) / 2)), 2)))) <= $3
        ORDER BY (6371000 * 2 * asin(sqrt(power(sin(radians((latitude - $1) / 2)), 2) + cos(radians($1)) * cos(radians(latitude)) * power(sin(radians((longitude - $2) / 2)), 2)))) ASC
    `, lat, lng, radiusM)
    if err != nil { return nil, err }
    defer rows.Close()
    return scanSpaces(rows)
}

func (r *Repository) GetSpace(ctx context.Context, id string) (*models.Space, error) {
    rows, err := r.db.Query(ctx, `SELECT id,name,tagline,summary,latitude,longitude,radius_meters,distance_meters,kind,exhibit_count,contributor_count,accent_hue,is_downloaded FROM spaces WHERE id=$1`, id)
    if err != nil { return nil, err }
    spaces, err := scanSpaces(rows)
    if err != nil { return nil, err }
    if len(spaces) == 0 { return nil, ErrNotFound }
    exhibits, err := r.ListExhibits(ctx, id)
    if err != nil { return nil, err }
    spaces[0].Exhibits = exhibits
    return &spaces[0], nil
}

func (r *Repository) ListExhibits(ctx context.Context, spaceID string) ([]models.Exhibit, error) {
    rows, err := r.db.Query(ctx, `SELECT id,title,kind,body,year,contributor,tags,status,confidence,ARRAY[offset_x,offset_y,offset_z] AS offset,duration_seconds,likes FROM exhibits WHERE space_id=$1 ORDER BY title`, spaceID)
    if err != nil { return nil, err }
    defer rows.Close()
    exhibits, err := pgx.CollectRows(rows, pgx.RowToStructByName[models.Exhibit])
    if err != nil { return nil, err }
    return exhibits, nil
}

func (r *Repository) CreateContribution(ctx context.Context, req models.ContributionRequest) (models.ContributionResponse, error) {
    var res models.ContributionResponse
    err := r.db.QueryRow(ctx, `INSERT INTO contributions (space_id,suggested_title,kind,body,contributor_name) VALUES ($1,$2,$3,$4,$5) RETURNING id::text,status`, req.SpaceID, req.SuggestedTitle, req.Kind, req.Body, req.ContributorName).Scan(&res.ID, &res.Status)
    return res, err
}

func scanSpaces(rows pgx.Rows) ([]models.Space, error) {
    spaces := []models.Space{}
    for rows.Next() {
        var s models.Space
        if err := rows.Scan(&s.ID,&s.Name,&s.Tagline,&s.Summary,&s.Latitude,&s.Longitude,&s.RadiusMeters,&s.DistanceMeters,&s.Kind,&s.ExhibitCount,&s.ContributorCount,&s.AccentHue,&s.IsDownloaded); err != nil {
            return nil, err
        }
        if math.IsNaN(s.Latitude) || math.IsNaN(s.Longitude) { continue }
        spaces = append(spaces, s)
    }
    return spaces, rows.Err()
}
```

- [ ] **Step 3: Wire HTTP routes**

Implement handlers that call these repository methods and return JSON. Validate contribution requests by requiring `suggested_title`, `kind`, and `body` to be non-empty. Return `400` for invalid input, `404` for missing records, and `500` for unexpected errors.

- [ ] **Step 4: Verify endpoints**

Run:

```bash
curl http://localhost:8080/api/v1/spaces
curl "http://localhost:8080/api/v1/spaces/nearby?lat=41.794&lng=-88.007&radius_m=5000"
curl http://localhost:8080/api/v1/spaces/sp-tivoli-theatre
```

Expected: JSON responses with seeded Downers Grove spaces.

---

## Task 4: Backend tests

**Files:**
- Create: `backend/internal/http/handlers_test.go`
- Modify: `backend/internal/http/handlers.go` if needed to support repository interfaces.

- [ ] **Step 1: Add handler tests**

Create tests for:

- `GET /healthz` returns `200` and `{"status":"ok"}`.
- `GET /api/v1/spaces` returns a JSON array.
- `POST /api/v1/contributions` rejects empty body with `400`.
- `POST /api/v1/contributions` accepts valid request and returns `pending`.

- [ ] **Step 2: Run tests**

Run:

```bash
cd backend
go test ./...
```

Expected: all tests pass.

---

## Task 5: iOS API client with sample-data fallback

**Files:**
- Create: `ios-invisible-museum/InvisibleMuseum/APIClient.swift`
- Create: `ios-invisible-museum/InvisibleMuseum/MuseumRepository.swift`
- Modify: `ios-invisible-museum/InvisibleMuseum/MuseumStore.swift`
- Modify: `ios-invisible-museum/InvisibleMuseum/ContentView.swift` if loading needs `.task`.

- [ ] **Step 1: Add API client**

Create a Swift client using `URLSession`. No custom key decoding should be needed if the backend emits the exact Swift camelCase keys (`radiusMeters`, `distanceMeters`, `exhibitCount`, `contributorCount`, `accentHue`, `isDownloaded`, `durationSeconds`).

- [ ] **Step 2: Add repository fallback**

Repository behavior:

1. Try `GET /api/v1/spaces/nearby`.
2. If the request fails, return `SampleData.spaces`.
3. Keep saved/downloaded state local for now.

- [ ] **Step 3: Update store loading**

Add an async load method:

```swift
@MainActor
func loadNearbySpaces() async {
    do {
        spaces = try await repository.fetchNearbySpaces(latitude: 41.794, longitude: -88.007, radiusMeters: 5000)
    } catch {
        spaces = SampleData.spaces
    }
}
```

Use injected or default repository so previews can still use sample data.

- [ ] **Step 4: Verify iOS build**

Run:

```bash
cd ios-invisible-museum
xcodebuild -project "InvisibleMuseum.xcodeproj" -scheme "InvisibleMuseum" -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 6: Contribution submit integration

**Files:**
- Modify: `ios-invisible-museum/InvisibleMuseum/ContributeView.swift`
- Modify: `ios-invisible-museum/InvisibleMuseum/APIClient.swift`
- Modify: `ios-invisible-museum/InvisibleMuseum/MuseumRepository.swift`

- [ ] **Step 1: Add contribution API method**

Add a method that sends `POST /api/v1/contributions` with `space_id`, `suggested_title`, `kind`, `body`, and `contributor_name`.

- [ ] **Step 2: Update submit button**

On submit:

1. Disable button while request is in flight.
2. Show success state when backend returns `pending`.
3. Show a short error message if the backend is unavailable.

- [ ] **Step 3: Verify manually**

Run backend, open app, submit a test contribution, then confirm in Postgres:

```bash
cd backend
docker compose exec postgres psql -U museum -d invisible_museum -c "select suggested_title, status from contributions order by created_at desc limit 5;"
```

Expected: submitted contribution appears with `pending` status.

---

## Review gate before implementation

Before coding, confirm these decisions:

- Backend lives in `backend/`.
- No auth in MVP 1.
- Saved/downloaded state remains local until auth exists.
- Seed data is used for local Downers Grove testing.
- Nearby search starts with SQL Haversine instead of PostGIS.
- Contributions are accepted as `pending` with no admin UI yet.

---

## Validation checklist

- [ ] `cd backend && go test ./...` passes.
- [ ] `cd backend && docker compose up --build` starts API and Postgres.
- [ ] `curl http://localhost:8080/healthz` returns status ok.
- [ ] `curl "http://localhost:8080/api/v1/spaces/nearby?lat=41.794&lng=-88.007&radius_m=5000"` returns seeded local spaces using the camelCase Swift contract.
- [ ] iOS app builds with `xcodebuild`.
- [ ] iOS app shows backend spaces when API is running.
- [ ] iOS app falls back to `SampleData.spaces` when API is down.
- [ ] Contribution submission writes a `pending` row to PostgreSQL.
