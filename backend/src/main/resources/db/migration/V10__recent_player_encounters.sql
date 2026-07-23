-- Recent opponents encountered in completed matches (directed pair: user → opponent).
CREATE TABLE recent_player_encounters (
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT NOT NULL,
    opponent_id      BIGINT NOT NULL,
    last_room_id     BIGINT,
    last_room_code   VARCHAR(16),
    last_played_at   TIMESTAMPTZ NOT NULL,
    match_count      INT NOT NULL DEFAULT 1,
    CONSTRAINT fk_recent_encounters_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_recent_encounters_opponent FOREIGN KEY (opponent_id) REFERENCES users (id),
    CONSTRAINT fk_recent_encounters_room FOREIGN KEY (last_room_id) REFERENCES game_rooms (id),
    CONSTRAINT chk_recent_encounters_not_self CHECK (user_id <> opponent_id),
    CONSTRAINT uk_recent_encounter_pair UNIQUE (user_id, opponent_id)
);

CREATE INDEX idx_recent_encounters_user_played
    ON recent_player_encounters (user_id, last_played_at DESC);
