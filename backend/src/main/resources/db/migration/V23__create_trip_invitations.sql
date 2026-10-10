CREATE TABLE IF NOT EXISTS trip_invitations (
  id BIGSERIAL PRIMARY KEY,
  trip_id BIGINT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  inviter_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invitee_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  role VARCHAR(20) NOT NULL DEFAULT 'VIEWER',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_trip_invitations_invitee
  ON trip_invitations(invitee_user_id, status);

-- 같은 여행에 대해 동일 사용자 PENDING 중복 방지
CREATE UNIQUE INDEX IF NOT EXISTS uq_trip_invitations_pending
  ON trip_invitations(trip_id, invitee_user_id)
  WHERE status = 'PENDING';
