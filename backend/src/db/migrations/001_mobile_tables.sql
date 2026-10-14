-- Mobile app tables, in the same database as the Chattiq API.
-- These are the same tables the Chattiq API uses for the mobile app, so both
-- services can run side by side. Safe to re-run: every statement uses IF NOT EXISTS.

-- ── Sign-in sessions (refresh tokens) ──────────────────────────────
-- Only a SHA-256 hash of each token is stored, never the token itself.
-- Every refresh rotates the token; all tokens issued from one login share a
-- family_id, so reuse of a rotated (revoked) token revokes the whole family.
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id              BIGSERIAL PRIMARY KEY,
  user_id         TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  token_hash      TEXT NOT NULL UNIQUE,
  family_id       TEXT NOT NULL,
  device_name     TEXT NOT NULL DEFAULT '',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at      TIMESTAMPTZ NOT NULL,
  last_used_at    TIMESTAMPTZ,
  revoked_at      TIMESTAMPTZ,
  revoked_reason  TEXT
);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens (user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_family ON refresh_tokens (family_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires ON refresh_tokens (expires_at);

-- ── Phones that receive push notifications ────────────────────────
-- The Expo push token is unique, so when another user signs in on the same
-- phone the row moves to that user and the previous user stops getting alerts.
CREATE TABLE IF NOT EXISTS device_tokens (
  id               BIGSERIAL PRIMARY KEY,
  user_id          TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  expo_push_token  TEXT NOT NULL UNIQUE,
  platform         TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  device_name      TEXT NOT NULL DEFAULT '',
  app_version      TEXT NOT NULL DEFAULT '',
  is_active        BOOLEAN NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_active ON device_tokens (user_id) WHERE is_active;

-- ── Message notifications on/off (per user) ───────────────────────
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS notify_new_lead BOOLEAN NOT NULL DEFAULT true;
