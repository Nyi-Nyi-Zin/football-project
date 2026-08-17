-- +goose Up

CREATE TABLE IF NOT EXISTS betting.bet_slips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    bet_type VARCHAR(20) NOT NULL,
    stake DECIMAL(18,2) NOT NULL,
    combined_odds DECIMAL(10,2) NOT NULL,
    potential_payout DECIMAL(18,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    settled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bet_slips_user_id
    ON betting.bet_slips(user_id);
CREATE INDEX IF NOT EXISTS idx_bet_slips_status
    ON betting.bet_slips(status);

CREATE TABLE IF NOT EXISTS betting.bet_legs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slip_id UUID NOT NULL REFERENCES betting.bet_slips(id) ON DELETE CASCADE,
    match_id UUID NOT NULL REFERENCES betting.matches(id),
    market_key VARCHAR(50) NOT NULL,
    selection_key VARCHAR(50) NOT NULL,
    selection_label VARCHAR(255) NOT NULL,
    odds DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bet_legs_slip_id
    ON betting.bet_legs(slip_id);
CREATE INDEX IF NOT EXISTS idx_bet_legs_match_id
    ON betting.bet_legs(match_id);

-- +goose Down
DROP TABLE IF EXISTS betting.bet_legs;
DROP TABLE IF EXISTS betting.bet_slips;
