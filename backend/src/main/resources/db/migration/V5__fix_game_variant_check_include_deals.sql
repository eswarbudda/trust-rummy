-- V3 only dropped the named constraint chk_game_rooms_game_variant.
-- Some databases still have PostgreSQL's auto-named
-- game_rooms_game_variant_check (from an unnamed CHECK), which rejects DEALS.
-- Drop every known name, then recreate a single authoritative constraint.

ALTER TABLE game_rooms DROP CONSTRAINT IF EXISTS chk_game_rooms_game_variant;
ALTER TABLE game_rooms DROP CONSTRAINT IF EXISTS game_rooms_game_variant_check;

ALTER TABLE game_rooms
    ADD CONSTRAINT chk_game_rooms_game_variant
        CHECK (game_variant IN ('POOL_101', 'POOL_201', 'POINTS', 'DEALS'));
