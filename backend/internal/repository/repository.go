package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"invisible-museum/backend/internal/models"
)

var ErrNotFound = errors.New("not found")
var ErrInvalidSpaceID = errors.New("invalid space_id")

// Repository provides PostgreSQL-backed access to museum data.
type Repository struct {
	db *pgxpool.Pool
}

// New creates a new Repository.
func New(db *pgxpool.Pool) *Repository { return &Repository{db: db} }

// ListSpaces returns all spaces.
func (r *Repository) ListSpaces(ctx context.Context) ([]models.Space, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, name, tagline, summary, latitude, longitude, radius_meters, distance_meters, kind, exhibit_count, contributor_count, accent_hue, is_downloaded
		FROM spaces
		ORDER BY name
	`)
	if err != nil {
		return nil, fmt.Errorf("list spaces: %w", err)
	}
	defer rows.Close()

	spaces, err := scanSpaces(rows)
	if err != nil {
		return nil, err
	}
	if err := r.attachExhibits(ctx, spaces); err != nil {
		return nil, err
	}
	return spaces, nil
}

// NearbySpaces returns spaces within radiusM meters of the provided location.
func (r *Repository) NearbySpaces(ctx context.Context, lat, lng float64, radiusM int) ([]models.Space, error) {
	rows, err := r.db.Query(ctx, `
		SELECT
			id,
			name,
			tagline,
			summary,
			latitude,
			longitude,
			radius_meters,
			(
				6371000 * 2 * asin(
					sqrt(
						power(sin(radians((latitude - $1) / 2)), 2)
						+ cos(radians($1)) * cos(radians(latitude)) * power(sin(radians((longitude - $2) / 2)), 2)
					)
				)
			) AS distance_meters,
			kind,
			exhibit_count,
			contributor_count,
			accent_hue,
			is_downloaded
		FROM spaces
		WHERE (
			6371000 * 2 * asin(
				sqrt(
					power(sin(radians((latitude - $1) / 2)), 2)
					+ cos(radians($1)) * cos(radians(latitude)) * power(sin(radians((longitude - $2) / 2)), 2)
				)
			)
		) <= $3
		ORDER BY distance_meters ASC, name ASC
	`, lat, lng, radiusM)
	if err != nil {
		return nil, fmt.Errorf("nearby spaces: %w", err)
	}
	defer rows.Close()

	spaces, err := scanSpaces(rows)
	if err != nil {
		return nil, err
	}
	if err := r.attachExhibits(ctx, spaces); err != nil {
		return nil, err
	}
	return spaces, nil
}

// GetSpace returns a single space including nested exhibits.
func (r *Repository) GetSpace(ctx context.Context, id string) (*models.Space, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, name, tagline, summary, latitude, longitude, radius_meters, distance_meters, kind, exhibit_count, contributor_count, accent_hue, is_downloaded
		FROM spaces
		WHERE id = $1
	`, id)
	if err != nil {
		return nil, fmt.Errorf("get space: %w", err)
	}
	defer rows.Close()

	spaces, err := scanSpaces(rows)
	if err != nil {
		return nil, err
	}
	if len(spaces) == 0 {
		return nil, ErrNotFound
	}

	exhibits, err := r.ListExhibits(ctx, id)
	if err != nil {
		return nil, err
	}
	spaces[0].Exhibits = exhibits
	return &spaces[0], nil
}

// GetExhibit returns a single exhibit by ID.
func (r *Repository) GetExhibit(ctx context.Context, id string) (*models.Exhibit, error) {
	row := r.db.QueryRow(ctx, `
		SELECT id, title, kind, body, year, contributor, tags, status, confidence, ARRAY[offset_x::float8, offset_y::float8, offset_z::float8] AS offset, duration_seconds, likes
		FROM exhibits
		WHERE id = $1
	`, id)

	exhibit, err := scanExhibit(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &exhibit, nil
}

// ListExhibits returns all exhibits for a space.
func (r *Repository) ListExhibits(ctx context.Context, spaceID string) ([]models.Exhibit, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, title, kind, body, year, contributor, tags, status, confidence, ARRAY[offset_x::float8, offset_y::float8, offset_z::float8] AS offset, duration_seconds, likes
		FROM exhibits
		WHERE space_id = $1
		ORDER BY title
	`, spaceID)
	if err != nil {
		return nil, fmt.Errorf("list exhibits: %w", err)
	}
	defer rows.Close()

	exhibits := make([]models.Exhibit, 0)
	for rows.Next() {
		exhibit, err := scanExhibit(rows)
		if err != nil {
			return nil, err
		}
		exhibits = append(exhibits, exhibit)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("list exhibits rows: %w", err)
	}
	return exhibits, nil
}

// CreateContribution inserts a contribution and returns its ID and status.
func (r *Repository) CreateContribution(ctx context.Context, req models.ContributionRequest) (models.ContributionResponse, error) {
	var response models.ContributionResponse
	if req.SpaceID != nil {
		var exists bool
		if err := r.db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM spaces WHERE id = $1)`, *req.SpaceID).Scan(&exists); err != nil {
			return models.ContributionResponse{}, fmt.Errorf("check contribution space: %w", err)
		}
		if !exists {
			return models.ContributionResponse{}, ErrInvalidSpaceID
		}
	}
	err := r.db.QueryRow(ctx, `
		INSERT INTO contributions (space_id, suggested_title, kind, body, contributor_name)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id::text, status
	`, req.SpaceID, req.SuggestedTitle, req.Kind, req.Body, req.ContributorName).Scan(&response.ID, &response.Status)
	if err != nil {
		return models.ContributionResponse{}, fmt.Errorf("create contribution: %w", err)
	}
	return response, nil
}

// ListContributions returns contributions, optionally filtered by moderation status.
func (r *Repository) ListContributions(ctx context.Context, status string) ([]models.Contribution, error) {
	query := `
		SELECT id::text, space_id, suggested_title, kind, body, contributor_name, status, created_at, updated_at
		FROM contributions
	`
	args := []any{}
	if status != "all" {
		query += " WHERE status = $1"
		args = append(args, status)
	}
	query += " ORDER BY created_at DESC, suggested_title ASC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list contributions: %w", err)
	}
	defer rows.Close()

	contributions := make([]models.Contribution, 0)
	for rows.Next() {
		contribution, err := scanContribution(rows)
		if err != nil {
			return nil, err
		}
		contributions = append(contributions, contribution)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("list contributions rows: %w", err)
	}
	return contributions, nil
}

// UpdateContributionStatus changes a contribution moderation status.
func (r *Repository) UpdateContributionStatus(ctx context.Context, id string, status string) (*models.Contribution, error) {
	row := r.db.QueryRow(ctx, `
		UPDATE contributions
		SET status = $2, updated_at = now()
		WHERE id = $1
		RETURNING id::text, space_id, suggested_title, kind, body, contributor_name, status, created_at, updated_at
	`, id, status)

	contribution, err := scanContribution(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &contribution, nil
}

func (r *Repository) attachExhibits(ctx context.Context, spaces []models.Space) error {
	for i := range spaces {
		exhibits, err := r.ListExhibits(ctx, spaces[i].ID)
		if err != nil {
			return err
		}
		spaces[i].Exhibits = exhibits
		if spaces[i].Exhibits == nil {
			spaces[i].Exhibits = []models.Exhibit{}
		}
	}
	return nil
}

func scanSpaces(rows pgx.Rows) ([]models.Space, error) {
	spaces := make([]models.Space, 0)
	for rows.Next() {
		space, err := scanSpace(rows)
		if err != nil {
			return nil, err
		}
		spaces = append(spaces, space)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("scan spaces rows: %w", err)
	}
	return spaces, nil
}

func scanSpace(row interface{ Scan(dest ...any) error }) (models.Space, error) {
	var space models.Space
	if err := row.Scan(
		&space.ID,
		&space.Name,
		&space.Tagline,
		&space.Summary,
		&space.Latitude,
		&space.Longitude,
		&space.RadiusMeters,
		&space.DistanceMeters,
		&space.Kind,
		&space.ExhibitCount,
		&space.ContributorCount,
		&space.AccentHue,
		&space.IsDownloaded,
	); err != nil {
		return models.Space{}, fmt.Errorf("scan space: %w", err)
	}
	space.Exhibits = []models.Exhibit{}
	return space, nil
}

func scanExhibit(row interface{ Scan(dest ...any) error }) (models.Exhibit, error) {
	var exhibit models.Exhibit
	var tags []string
	var offset []float64
	var duration sql.NullInt32
	if err := row.Scan(
		&exhibit.ID,
		&exhibit.Title,
		&exhibit.Kind,
		&exhibit.Body,
		&exhibit.Year,
		&exhibit.Contributor,
		&tags,
		&exhibit.Status,
		&exhibit.Confidence,
		&offset,
		&duration,
		&exhibit.Likes,
	); err != nil {
		return models.Exhibit{}, fmt.Errorf("scan exhibit: %w", err)
	}
	if len(offset) == 3 {
		exhibit.Offset = [3]float64{offset[0], offset[1], offset[2]}
	}
	exhibit.Tags = tags
	if duration.Valid {
		value := int(duration.Int32)
		exhibit.DurationSeconds = &value
	}
	return exhibit, nil
}

func scanContribution(row interface{ Scan(dest ...any) error }) (models.Contribution, error) {
	var contribution models.Contribution
	var spaceID sql.NullString
	var status string
	if err := row.Scan(
		&contribution.ID,
		&spaceID,
		&contribution.SuggestedTitle,
		&contribution.Kind,
		&contribution.Body,
		&contribution.ContributorName,
		&status,
		&contribution.CreatedAt,
		&contribution.UpdatedAt,
	); err != nil {
		return models.Contribution{}, fmt.Errorf("scan contribution: %w", err)
	}
	if spaceID.Valid {
		trimmed := strings.TrimSpace(spaceID.String)
		contribution.SpaceID = &trimmed
	}
	contribution.Status = models.ContributionStatus(status)
	return contribution, nil
}
