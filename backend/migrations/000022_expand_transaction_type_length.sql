-- +goose Up
ALTER TABLE payments.transactions
    ALTER COLUMN type TYPE VARCHAR(50);

-- +goose Down
ALTER TABLE payments.transactions
    ALTER COLUMN type TYPE VARCHAR(20)
    USING LEFT(type, 20);
