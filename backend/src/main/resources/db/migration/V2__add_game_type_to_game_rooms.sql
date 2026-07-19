-- Workstream 1: top-level GameType discriminator on game_rooms.
-- gameVariant (POOL_101/POOL_201/POINTS) remains a RUMMY-specific sub-selector.

ALTER TABLE game_rooms
    ADD COLUMN game_type VARCHAR(16);

ALTER TABLE game_rooms
    ADD CONSTRAINT chk_game_rooms_game_type CHECK (game_type IN ('RUMMY', 'ANDAR_BAHAR', 'TEEN_PATTI'));

UPDATE game_rooms SET game_type = 'RUMMY' WHERE game_type IS NULL;
