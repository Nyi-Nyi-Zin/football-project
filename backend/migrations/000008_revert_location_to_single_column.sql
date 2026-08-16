-- Revert city/street split back to a single location column.
-- This migration must also be safe on fresh databases where migration 000005
-- already created `location` and no `street` column ever existed.
-- +goose Up
-- +goose StatementBegin
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'users'
          AND table_name = 'accounts'
          AND column_name = 'city'
    ) THEN
        ALTER TABLE users.accounts DROP COLUMN city;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'users'
          AND table_name = 'accounts'
          AND column_name = 'street'
    ) THEN
        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'users'
              AND table_name = 'accounts'
              AND column_name = 'location'
        ) THEN
            ALTER TABLE users.accounts RENAME COLUMN street TO location;
        ELSE
            UPDATE users.accounts
            SET location = COALESCE(NULLIF(location, ''), street)
            WHERE street IS NOT NULL;
            ALTER TABLE users.accounts DROP COLUMN street;
        END IF;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'users'
          AND table_name = 'accounts'
          AND column_name = 'location'
    ) THEN
        ALTER TABLE users.accounts ADD COLUMN location TEXT;
    END IF;
END
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'users'
          AND table_name = 'accounts'
          AND column_name = 'location'
    ) THEN
        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'users'
              AND table_name = 'accounts'
              AND column_name = 'street'
        ) THEN
            ALTER TABLE users.accounts RENAME COLUMN location TO street;
        ELSE
            UPDATE users.accounts
            SET street = COALESCE(NULLIF(street, ''), location)
            WHERE location IS NOT NULL;
            ALTER TABLE users.accounts DROP COLUMN location;
        END IF;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'users'
          AND table_name = 'accounts'
          AND column_name = 'city'
    ) THEN
        ALTER TABLE users.accounts ADD COLUMN city VARCHAR(100);
    END IF;
END
$$;
-- +goose StatementEnd
