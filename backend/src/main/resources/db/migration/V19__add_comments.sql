CREATE TABLE comments (
    id         BIGSERIAL    PRIMARY KEY,
    media_id   BIGINT       NOT NULL REFERENCES media(id) ON DELETE CASCADE,
    user_id    BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content    TEXT         NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_comments_media_id ON comments(media_id);
