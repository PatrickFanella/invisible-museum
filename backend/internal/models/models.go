package models

// Space represents a museum space in the API contract.
type Space struct {
	ID               string    `json:"id"`
	Name             string    `json:"name"`
	Tagline          string    `json:"tagline"`
	Summary          string    `json:"summary"`
	Latitude         float64   `json:"latitude"`
	Longitude        float64   `json:"longitude"`
	RadiusMeters     float64   `json:"radiusMeters"`
	DistanceMeters   float64   `json:"distanceMeters"`
	Kind             string    `json:"kind"`
	ExhibitCount     int       `json:"exhibitCount"`
	ContributorCount int       `json:"contributorCount"`
	AccentHue        float64   `json:"accentHue"`
	IsDownloaded     bool      `json:"isDownloaded"`
	Exhibits         []Exhibit `json:"exhibits"`
}

// Exhibit represents a nested museum exhibit in the API contract.
type Exhibit struct {
	ID              string     `json:"id"`
	Title           string     `json:"title"`
	Kind            string     `json:"kind"`
	Body            string     `json:"body"`
	Year            string     `json:"year"`
	Contributor     string     `json:"contributor"`
	Tags            []string   `json:"tags"`
	Status          string     `json:"status"`
	Confidence      string     `json:"confidence"`
	Offset          [3]float64 `json:"offset"`
	DurationSeconds *int       `json:"durationSeconds"`
	Likes           int        `json:"likes"`
}

// ContributionRequest is the JSON payload accepted by the contributions endpoint.
type ContributionRequest struct {
	SpaceID         *string `json:"space_id"`
	SuggestedTitle  string  `json:"suggested_title"`
	Kind            string  `json:"kind"`
	Body            string  `json:"body"`
	ContributorName string  `json:"contributor_name"`
}

// ContributionResponse is the JSON response returned after submission.
type ContributionResponse struct {
	ID     string `json:"id"`
	Status string `json:"status"`
}
