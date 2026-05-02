-- +goose Up
-- Add NRC component fields for structured NRC data storage
ALTER TABLE users.accounts ADD COLUMN IF NOT EXISTS nrc_region VARCHAR(50);
ALTER TABLE users.accounts ADD COLUMN IF NOT EXISTS nrc_township VARCHAR(100);
ALTER TABLE users.accounts ADD COLUMN IF NOT EXISTS nrc_type VARCHAR(50);
ALTER TABLE users.accounts ADD COLUMN IF NOT EXISTS nrc_number VARCHAR(20);

-- +goose Down
-- Drop NRC component fields
ALTER TABLE users.accounts DROP COLUMN IF EXISTS nrc_region;
ALTER TABLE users.accounts DROP COLUMN IF EXISTS nrc_township;
ALTER TABLE users.accounts DROP COLUMN IF EXISTS nrc_type;
ALTER TABLE users.accounts DROP COLUMN IF EXISTS nrc_number;
