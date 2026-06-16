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
