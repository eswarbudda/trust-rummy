-- Friendships (unordered pair: one row per unordered user pair).
CREATE TABLE friendships (
    id              BIGSERIAL PRIMARY KEY,
    requester_id    BIGINT NOT NULL,
    addressee_id    BIGINT NOT NULL,
    status          VARCHAR(16) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL,
    responded_at    TIMESTAMPTZ,
    updated_at      TIMESTAMPTZ NOT NULL,
    CONSTRAINT fk_friendships_requester FOREIGN KEY (requester_id) REFERENCES users (id),
    CONSTRAINT fk_friendships_addressee FOREIGN KEY (addressee_id) REFERENCES users (id),
    CONSTRAINT chk_friendships_not_self CHECK (requester_id <> addressee_id),
    CONSTRAINT chk_friendships_status CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED', 'BLOCKED', 'REMOVED'))
);

CREATE UNIQUE INDEX uk_friendship_pair
    ON friendships (LEAST(requester_id, addressee_id), GREATEST(requester_id, addressee_id));

CREATE INDEX idx_friendships_requester_status ON friendships (requester_id, status);
CREATE INDEX idx_friendships_addressee_status ON friendships (addressee_id, status);
