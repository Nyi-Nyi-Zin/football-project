-- +goose Up
ALTER TABLE users.accounts
    ADD COLUMN IF NOT EXISTS favorite_match_ids JSONB NOT NULL DEFAULT '[]'::jsonb;

-- +goose Down
ALTER TABLE users.accounts
    DROP COLUMN IF EXISTS favorite_match_ids;

