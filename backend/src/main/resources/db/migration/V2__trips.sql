CREATE TABLE IF NOT EXISTS trips (
  id BIGSERIAL PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  start_date DATE NULL,
  end_date DATE NULL,
  created_by BIGINT NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS trip_members (
  id BIGSERIAL PRIMARY KEY,
  trip_id BIGINT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role VARCHAR(20) NOT NULL,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (trip_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_trip_members_trip_id ON trip_members(trip_id);
CREATE INDEX IF NOT EXISTS idx_trips_created_by ON trips(created_by);
