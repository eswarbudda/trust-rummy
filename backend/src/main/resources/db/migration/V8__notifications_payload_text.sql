-- Store notification payload as TEXT JSON for Hibernate validate compatibility across PG versions.
-- Safe if column is already jsonb (casts) or already text.
ALTER TABLE notifications
    ALTER COLUMN payload TYPE TEXT
    USING payload::text;

ALTER TABLE notifications
    ALTER COLUMN payload SET DEFAULT '{}';
