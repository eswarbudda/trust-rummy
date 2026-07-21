-- Deals Rummy variant + optional deals_per_match for POINTS / DEALS rooms.
ALTER TABLE game_rooms
    DROP CONSTRAINT IF EXISTS chk_game_rooms_game_variant;

ALTER TABLE game_rooms
    ADD CONSTRAINT chk_game_rooms_game_variant
        CHECK (game_variant IN ('POOL_101', 'POOL_201', 'POINTS', 'DEALS'));

ALTER TABLE game_rooms
    ADD COLUMN IF NOT EXISTS deals_per_match INTEGER;

ALTER TABLE game_rooms
    DROP CONSTRAINT IF EXISTS chk_game_rooms_deals_per_match;

ALTER TABLE game_rooms
    ADD CONSTRAINT chk_game_rooms_deals_per_match
        CHECK (deals_per_match IS NULL OR (deals_per_match >= 1 AND deals_per_match <= 50));
