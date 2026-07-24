-- Room visibility for public lobby vs invite/group-gated tables.
ALTER TABLE game_rooms
    ADD COLUMN visibility VARCHAR(16) NOT NULL DEFAULT 'PUBLIC',
    ADD COLUMN source_group_id BIGINT NULL;

ALTER TABLE game_rooms
    ADD CONSTRAINT chk_game_rooms_visibility
        CHECK (visibility IN ('PUBLIC', 'PRIVATE', 'GROUP_ONLY')),
    ADD CONSTRAINT fk_game_rooms_source_group
        FOREIGN KEY (source_group_id) REFERENCES play_groups (id);

CREATE INDEX idx_game_rooms_status_visibility ON game_rooms (status, visibility);
