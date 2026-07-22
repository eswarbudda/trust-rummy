-- Refresh tokens are stored as SHA-256 hex of the opaque client secret
-- (see AuthService). Existing plaintext rows cannot be verified after the
-- cutover — revoke them so clients obtain a new hashed refresh via login.
-- Index supports revoke-all-by-user (password change / reuse detection).

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens (user_id);

UPDATE refresh_tokens SET revoked = true WHERE revoked = false;
