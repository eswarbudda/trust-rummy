-- Generic persistent notification inbox (Friends / Invites / future wallet & admin).
CREATE TABLE notifications (
    id              UUID PRIMARY KEY,
    user_id         BIGINT NOT NULL,
    type            VARCHAR(64) NOT NULL,
    payload         JSONB NOT NULL DEFAULT '{}'::jsonb,
    status          VARCHAR(16) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL,
    read_at         TIMESTAMPTZ,
    dedupe_key      VARCHAR(128),
    CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT chk_notifications_status CHECK (status IN ('UNREAD', 'READ', 'ARCHIVED'))
);

CREATE INDEX idx_notifications_user_created ON notifications (user_id, created_at DESC);
CREATE INDEX idx_notifications_user_status ON notifications (user_id, status);
CREATE UNIQUE INDEX uk_notifications_user_dedupe
    ON notifications (user_id, dedupe_key)
    WHERE dedupe_key IS NOT NULL;
