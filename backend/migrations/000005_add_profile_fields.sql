-- +goose Up
ALTER TABLE users.accounts ADD COLUMN IF NOT EXISTS nrc VARCHAR(100);
ALTER TABLE users.accounts ADD COLUMN IF NOT EXISTS gmail VARCHAR(255);
ALTER TABLE users.accounts ADD COLUMN IF NOT EXISTS location TEXT;

-- +goose Down
ALTER TABLE users.accounts DROP COLUMN IF EXISTS nrc;
ALTER TABLE users.accounts DROP COLUMN IF EXISTS gmail;
ALTER TABLE users.accounts DROP COLUMN IF EXISTS location;
