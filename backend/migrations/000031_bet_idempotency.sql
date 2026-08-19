-- +goose Up
ALTER TABLE betting.bets
    ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(120);

ALTER TABLE betting.bet_slips
    ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(120);

CREATE UNIQUE INDEX IF NOT EXISTS idx_bets_user_idempotency_key
    ON betting.bets(user_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL AND idempotency_key <> '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_bet_slips_user_idempotency_key
    ON betting.bet_slips(user_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL AND idempotency_key <> '';

-- +goose Down
DROP INDEX IF EXISTS betting.idx_bets_user_idempotency_key;
DROP INDEX IF EXISTS betting.idx_bet_slips_user_idempotency_key;
ALTER TABLE betting.bets DROP COLUMN IF EXISTS idempotency_key;
ALTER TABLE betting.bet_slips DROP COLUMN IF EXISTS idempotency_key;
