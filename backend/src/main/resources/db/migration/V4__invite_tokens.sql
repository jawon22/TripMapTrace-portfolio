CREATE TABLE IF NOT EXISTS invite_tokens (
  id BIGSERIAL PRIMARY KEY,
  trip_id BIGINT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  token VARCHAR(128) NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  max_uses INT NOT NULL DEFAULT 10,
  used_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invite_tokens_trip_id ON invite_tokens(trip_id);
CREATE INDEX IF NOT EXISTS idx_invite_tokens_expires_at ON invite_tokens(expires_at);
