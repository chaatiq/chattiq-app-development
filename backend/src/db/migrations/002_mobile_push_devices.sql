-- Phones of the Flutter app, which receive notifications through Firebase
-- Cloud Messaging (FCM) tokens. Kept apart from device_tokens (Expo tokens,
-- used by the Chattiq API) so neither service deactivates the other's tokens.
-- Safe to re-run: every statement uses IF NOT EXISTS.

-- One row per phone. The token is unique, so when another user signs in on the
-- same phone the row moves to that user and the previous user stops getting alerts.
CREATE TABLE IF NOT EXISTS mobile_push_devices (
  id            BIGSERIAL PRIMARY KEY,
  user_id       TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  push_token    TEXT NOT NULL UNIQUE,
  platform      TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  device_name   TEXT NOT NULL DEFAULT '',
  app_version   TEXT NOT NULL DEFAULT '',
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mobile_push_devices_user_active ON mobile_push_devices (user_id) WHERE is_active;
