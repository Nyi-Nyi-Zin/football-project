-- +goose Up
-- Fix custom_code unique constraint by converting empty strings to NULL
-- First, drop the existing unique constraint
ALTER TABLE users.accounts DROP CONSTRAINT IF EXISTS accounts_custom_code_key;

-- Convert all empty strings to NULL
UPDATE users.accounts SET custom_code = NULL WHERE custom_code = '';

-- Recreate the unique constraint (NULL values are allowed and don't violate uniqueness)
ALTER TABLE users.accounts ADD CONSTRAINT accounts_custom_code_key UNIQUE (custom_code);

-- +goose Down
-- Revert: drop constraint and convert NULL back to empty string
ALTER TABLE users.accounts DROP CONSTRAINT IF EXISTS accounts_custom_code_key;

-- Convert NULL back to empty string
UPDATE users.accounts SET custom_code = '' WHERE custom_code IS NULL;

-- Recreate the unique constraint
ALTER TABLE users.accounts ADD CONSTRAINT accounts_custom_code_key UNIQUE (custom_code);
