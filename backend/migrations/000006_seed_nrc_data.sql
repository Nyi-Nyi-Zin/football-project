-- +goose Up
-- NRC data is now loaded from JSON file on frontend
-- No database tables needed for NRC reference data
-- NRC is stored as single string column 'nrc' in users.accounts table

-- +goose Down
-- No tables to drop
