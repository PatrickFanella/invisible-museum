-- +goose Up
CREATE TABLE tours (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  estimated_minutes INTEGER NOT NULL DEFAULT 0,
  published BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE tour_stops (
  id TEXT PRIMARY KEY,
  tour_id TEXT NOT NULL REFERENCES tours(id) ON DELETE CASCADE,
  space_id TEXT NOT NULL REFERENCES spaces(id) ON DELETE RESTRICT,
  stop_order INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tour_id, stop_order)
);

CREATE INDEX tour_stops_tour_id_stop_order_idx ON tour_stops(tour_id, stop_order);
CREATE INDEX tour_stops_space_id_idx ON tour_stops(space_id);

INSERT INTO tours (id, title, summary, estimated_minutes, published)
VALUES (
  'tour-downtown-memory-loop',
  'Downtown Memory Loop',
  'A short walking tour linking the station, theater, park, and local history campus.',
  45,
  true
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  summary = EXCLUDED.summary,
  estimated_minutes = EXCLUDED.estimated_minutes,
  published = EXCLUDED.published;

INSERT INTO tour_stops (id, tour_id, space_id, stop_order)
VALUES
  ('tour-stop-main-street-station', 'tour-downtown-memory-loop', 'sp-main-street-station', 1),
  ('tour-stop-tivoli-theatre', 'tour-downtown-memory-loop', 'sp-tivoli-theatre', 2),
  ('tour-stop-fishel-park', 'tour-downtown-memory-loop', 'sp-fishel-park', 3),
  ('tour-stop-downers-grove-museum', 'tour-downtown-memory-loop', 'sp-downers-grove-museum', 4)
ON CONFLICT (id) DO UPDATE SET
  tour_id = EXCLUDED.tour_id,
  space_id = EXCLUDED.space_id,
  stop_order = EXCLUDED.stop_order;

-- +goose Down
DELETE FROM tour_stops WHERE tour_id = 'tour-downtown-memory-loop';
DELETE FROM tours WHERE id = 'tour-downtown-memory-loop';
