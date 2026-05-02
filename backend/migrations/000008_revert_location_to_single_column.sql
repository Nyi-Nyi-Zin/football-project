-- +goose Up
-- Revert city/street split back to single location column
ALTER TABLE users.accounts DROP COLUMN IF EXISTS city;
ALTER TABLE users.accounts RENAME COLUMN street TO location;

-- +goose Down
-- Re-apply city/street split
ALTER TABLE users.accounts ADD COLUMN IF NOT EXISTS city VARCHAR(100);
ALTER TABLE users.accounts RENAME COLUMN location TO street;
