-- Play groups and membership (friend-gated adds).
CREATE TABLE play_groups (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(64) NOT NULL,
    owner_id        BIGINT NOT NULL,
    status          VARCHAR(16) NOT NULL,
    type            VARCHAR(16) NOT NULL DEFAULT 'GROUP',
    max_members     INT NOT NULL DEFAULT 20,
    created_at      TIMESTAMPTZ NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL,
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT fk_play_groups_owner FOREIGN KEY (owner_id) REFERENCES users (id),
    CONSTRAINT chk_play_groups_status CHECK (status IN ('ACTIVE', 'ARCHIVED', 'DELETED')),
    CONSTRAINT chk_play_groups_type CHECK (type IN ('GROUP', 'CLUB')),
    CONSTRAINT chk_play_groups_max_members CHECK (max_members >= 2 AND max_members <= 50)
);

CREATE INDEX idx_play_groups_owner_status ON play_groups (owner_id, status);

CREATE TABLE play_group_members (
    id              BIGSERIAL PRIMARY KEY,
    group_id        BIGINT NOT NULL,
    user_id         BIGINT NOT NULL,
    role            VARCHAR(16) NOT NULL,
    status          VARCHAR(16) NOT NULL,
    added_by_id     BIGINT,
    joined_at       TIMESTAMPTZ NOT NULL,
    left_at         TIMESTAMPTZ,
    CONSTRAINT fk_play_group_members_group FOREIGN KEY (group_id) REFERENCES play_groups (id),
    CONSTRAINT fk_play_group_members_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_play_group_members_added_by FOREIGN KEY (added_by_id) REFERENCES users (id),
    CONSTRAINT chk_play_group_members_role CHECK (role IN ('OWNER', 'ADMIN', 'MEMBER')),
    CONSTRAINT chk_play_group_members_status CHECK (status IN ('ACTIVE', 'REMOVED', 'LEFT')),
    CONSTRAINT uk_play_group_member UNIQUE (group_id, user_id)
);

CREATE INDEX idx_play_group_members_user_status ON play_group_members (user_id, status);
CREATE INDEX idx_play_group_members_group_status ON play_group_members (group_id, status);
