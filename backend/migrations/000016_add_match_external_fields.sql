-- +goose Up
ALTER TABLE betting.matches
    ADD COLUMN IF NOT EXISTS external_id VARCHAR(255);

ALTER TABLE betting.matches
    ADD COLUMN IF NOT EXISTS testing TEXT NOT NULL DEFAULT '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_matches_external_id_unique
    ON betting.matches (external_id)
    WHERE external_id IS NOT NULL AND external_id <> '';

-- +goose Down
DROP INDEX IF EXISTS betting.idx_matches_external_id_unique;

ALTER TABLE betting.matches
    DROP COLUMN IF EXISTS testing;

ALTER TABLE betting.matches
    DROP COLUMN IF EXISTS external_id;
