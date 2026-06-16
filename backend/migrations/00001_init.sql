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
