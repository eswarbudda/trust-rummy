-- Allow pending membership invites (owner invites; user must accept).
ALTER TABLE play_group_members DROP CONSTRAINT IF EXISTS chk_play_group_members_status;
ALTER TABLE play_group_members
    ADD CONSTRAINT chk_play_group_members_status
    CHECK (status IN ('PENDING', 'ACTIVE', 'REMOVED', 'LEFT'));
