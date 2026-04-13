-- Users module tables
CREATE TABLE IF NOT EXISTS users.accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    username VARCHAR(30) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    phone VARCHAR(20),
    role VARCHAR(20) DEFAULT 'user',
    status VARCHAR(20) DEFAULT 'active',
    balance DECIMAL(18,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Betting module tables
CREATE TABLE IF NOT EXISTS betting.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sport VARCHAR(50) NOT NULL,
    league VARCHAR(100) NOT NULL,
    home_team VARCHAR(100) NOT NULL,
    away_team VARCHAR(100) NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) DEFAULT 'upcoming',
    home_score INTEGER,
    away_score INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_matches_sport ON betting.matches(sport);
CREATE INDEX IF NOT EXISTS idx_matches_start_time ON betting.matches(start_time);

CREATE TABLE IF NOT EXISTS betting.bets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    match_id UUID NOT NULL REFERENCES betting.matches(id),
    bet_type VARCHAR(20) NOT NULL,
    selection VARCHAR(20) NOT NULL,
    odds DECIMAL(10,2) NOT NULL,
    stake DECIMAL(18,2) NOT NULL,
    potential_payout DECIMAL(18,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    settled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bets_user_id ON betting.bets(user_id);
CREATE INDEX IF NOT EXISTS idx_bets_match_id ON betting.bets(match_id);

-- Payment module tables
CREATE TABLE IF NOT EXISTS payments.wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE,
    balance DECIMAL(18,2) DEFAULT 0,
    currency VARCHAR(10) DEFAULT 'USD',
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payments.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    type VARCHAR(20) NOT NULL,
    amount DECIMAL(18,2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'USD',
    status VARCHAR(20) DEFAULT 'pending',
    idempotency_key VARCHAR(255) UNIQUE,
    reference VARCHAR(255),
    description TEXT,
    balance_before DECIMAL(18,2),
    balance_after DECIMAL(18,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON payments.transactions(user_id);

-- Odds module tables
CREATE TABLE IF NOT EXISTS odds.match_odds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL UNIQUE,
    home_odds DECIMAL(10,2) NOT NULL,
    away_odds DECIMAL(10,2) NOT NULL,
    draw_odds DECIMAL(10,2),
    is_active BOOLEAN DEFAULT true,
    source VARCHAR(50) DEFAULT 'system',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS odds.odds_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL,
    home_odds DECIMAL(10,2) NOT NULL,
    away_odds DECIMAL(10,2) NOT NULL,
    draw_odds DECIMAL(10,2),
    timestamp TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_odds_history_match_id ON odds.odds_history(match_id);

-- Notification module tables
CREATE TABLE IF NOT EXISTS notifications.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    type VARCHAR(30) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications.notifications(user_id);
