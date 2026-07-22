-- Speeds logout-all / revoke-on-password-change without changing refresh_tokens columns.
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens (user_id);
