-- Game invitations are intent only — they never create room_players.
CREATE TABLE game_invitations (
    id              UUID PRIMARY KEY,
    room_id         BIGINT NOT NULL,
    group_id        BIGINT,
    inviter_id      BIGINT NOT NULL,
    invitee_id      BIGINT NOT NULL,
    status          VARCHAR(16) NOT NULL,
    channel         VARCHAR(16) NOT NULL DEFAULT 'IN_APP',
    expires_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL,
    responded_at    TIMESTAMPTZ,
    CONSTRAINT fk_game_invitations_room FOREIGN KEY (room_id) REFERENCES game_rooms (id),
    CONSTRAINT fk_game_invitations_group FOREIGN KEY (group_id) REFERENCES play_groups (id),
    CONSTRAINT fk_game_invitations_inviter FOREIGN KEY (inviter_id) REFERENCES users (id),
    CONSTRAINT fk_game_invitations_invitee FOREIGN KEY (invitee_id) REFERENCES users (id),
    CONSTRAINT chk_game_invitations_status CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED', 'EXPIRED', 'CANCELLED')),
    CONSTRAINT chk_game_invitations_channel CHECK (channel IN ('IN_APP')),
    CONSTRAINT uk_game_invite_room_invitee UNIQUE (room_id, invitee_id)
);

CREATE INDEX idx_game_invitations_invitee_status ON game_invitations (invitee_id, status);
CREATE INDEX idx_game_invitations_room_status ON game_invitations (room_id, status);
CREATE INDEX idx_game_invitations_expires ON game_invitations (expires_at);
