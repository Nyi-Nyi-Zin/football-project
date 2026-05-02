-- +goose Up
-- Create NRC reference tables for normalized data storage

-- NRC Regions table (ပြည်နယ်/တိုင်း)
CREATE TABLE IF NOT EXISTS users.nrc_regions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE,
    name_en VARCHAR(100) NOT NULL,
    name_mm VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- NRC Townships table (မြို့နယ်)
CREATE TABLE IF NOT EXISTS users.nrc_townships (
    id SERIAL PRIMARY KEY,
    nrc_code VARCHAR(10) NOT NULL,
    name_en VARCHAR(100) NOT NULL,
    name_mm VARCHAR(100) NOT NULL,
    region_id INTEGER REFERENCES users.nrc_regions(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- NRC Types table (အမျိုးအစား)
CREATE TABLE IF NOT EXISTS users.nrc_types (
    id SERIAL PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE,
    name_mm VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed NRC Regions
INSERT INTO users.nrc_regions (id, code, name_en, name_mm) VALUES
(1, '1', 'Kachin', 'ကချင်ပြည်နယ်'),
(2, '2', 'Kayah', 'ကယားပြည်နယ်'),
(3, '3', 'Kayin', 'ကရင်ပြည်နယ်'),
(4, '4', 'Chin', 'ချင်းပြည်နယ်'),
(5, '5', 'Sagaing', 'စစ်ကိုင်းတိုင်းဒေသကြီး'),
(6, '6', 'Tanintharyi', 'တနင်္သာရီတိုင်းဒေသကြီး'),
(7, '7', 'Bago', 'ပဲခူးတိုင်းဒေသကြီး'),
(8, '8', 'Magway', 'မကွေးတိုင်းဒေသကြီး'),
(9, '9', 'Mandalay', 'မန္တလေးတိုင်းဒေသကြီး'),
(10, '10', 'Mon', 'မွန်ပြည်နယ်'),
(11, '11', 'Rakhine', 'ရခိုင်ပြည်နယ်'),
(12, '12', 'Yangon', 'ရန်ကုန်တိုင်းဒေသကြီး'),
(13, '13', 'Shan', 'ရှမ်းပြည်နယ်'),
(14, '14', 'Ayeyarwady', 'ဧရာဝတီတိုင်းဒေသကြီး')
ON CONFLICT (id) DO NOTHING;

-- Seed NRC Types
INSERT INTO users.nrc_types (id, code, name_mm) VALUES
(1, 'N', '(နိုင်)'),
(2, 'E', '(ဧည့်)'),
(3, 'P', '(ပြု)')
ON CONFLICT (id) DO NOTHING;

-- Note: Townships will be seeded from application or separate migration
-- as there are many townships per region

-- Add foreign key columns to users.accounts (nullable for backward compatibility)
ALTER TABLE users.accounts 
    ADD COLUMN IF NOT EXISTS nrc_region_id INTEGER REFERENCES users.nrc_regions(id),
    ADD COLUMN IF NOT EXISTS nrc_township_id INTEGER REFERENCES users.nrc_townships(id),
    ADD COLUMN IF NOT EXISTS nrc_type_id INTEGER REFERENCES users.nrc_types(id);

-- Create indexes for foreign keys
CREATE INDEX IF NOT EXISTS idx_accounts_nrc_region_id ON users.accounts(nrc_region_id);
CREATE INDEX IF NOT EXISTS idx_accounts_nrc_township_id ON users.accounts(nrc_township_id);
CREATE INDEX IF NOT EXISTS idx_accounts_nrc_type_id ON users.accounts(nrc_type_id);

-- +goose Down
-- Drop foreign key columns from users.accounts
ALTER TABLE users.accounts 
    DROP COLUMN IF EXISTS nrc_region_id,
    DROP COLUMN IF EXISTS nrc_township_id,
    DROP COLUMN IF EXISTS nrc_type_id;

-- Drop tables
DROP TABLE IF EXISTS users.nrc_townships;
DROP TABLE IF EXISTS users.nrc_types;
DROP TABLE IF EXISTS users.nrc_regions;
