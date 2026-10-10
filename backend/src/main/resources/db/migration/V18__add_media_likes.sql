CREATE TABLE media_likes (
    media_id   BIGINT NOT NULL REFERENCES media(id) ON DELETE CASCADE,
    user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (media_id, user_id)
);
