CREATE TABLE trip_likes (
    trip_id   BIGINT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    user_id   BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    PRIMARY KEY (trip_id, user_id)
);

CREATE TABLE trip_comments (
    id         BIGSERIAL PRIMARY KEY,
    trip_id    BIGINT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content    TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
