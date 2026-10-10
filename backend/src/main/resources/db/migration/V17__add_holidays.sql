CREATE TABLE holidays (
    id   BIGSERIAL PRIMARY KEY,
    date DATE         NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL
);
