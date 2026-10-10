CREATE TABLE IF NOT EXISTS media (
  id BIGSERIAL PRIMARY KEY,
  trip_id BIGINT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  uploader_id BIGINT NOT NULL REFERENCES users(id),
  type VARCHAR(20) NOT NULL, -- PHOTO | VIDEO
  taken_at TIMESTAMPTZ NOT NULL,
  lat DOUBLE PRECISION NULL,
  lng DOUBLE PRECISION NULL,
  address_text VARCHAR(255) NULL,
  storage_key VARCHAR(500) NOT NULL,
  thumbnail_key VARCHAR(500) NULL,
  status VARCHAR(20) NOT NULL, -- UPLOADING | READY | FAILED
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_media_trip_taken ON media(trip_id, taken_at, id);
CREATE INDEX IF NOT EXISTS idx_media_trip_id ON media(trip_id);
