CREATE TABLE notifications (
  id           BIGSERIAL    PRIMARY KEY,
  user_id      BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type         VARCHAR(30)  NOT NULL,
  title        VARCHAR(200) NOT NULL,
  body         VARCHAR(500) NOT NULL,
  is_read      BOOLEAN      NOT NULL DEFAULT FALSE,
  target_trip_id  BIGINT,
  target_media_id BIGINT,
  created_at   TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id      ON notifications(user_id);
CREATE INDEX idx_notifications_user_unread  ON notifications(user_id, is_read) WHERE is_read = FALSE;
