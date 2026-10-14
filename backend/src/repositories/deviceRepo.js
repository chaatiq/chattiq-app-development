const { query } = require('../db/pool');

/** Table mobile_push_devices (one row per phone, FCM token) and the users.notify_new_lead setting. */

function mapRow(row) {
  if (!row) return null;
  return {
    id: row.id,
    userId: row.user_id,
    pushToken: row.push_token,
    platform: row.platform,
    deviceName: row.device_name,
    appVersion: row.app_version,
    isActive: row.is_active,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    lastSeenAt: row.last_seen_at,
  };
}

/**
 * Registers a phone for a user. The push token is unique, so a phone that was
 * registered to another user moves to this user (and is reactivated).
 */
async function upsert({ userId, pushToken, platform, deviceName = '', appVersion = '' }) {
  const { rows } = await query(
    `INSERT INTO mobile_push_devices (user_id, push_token, platform, device_name, app_version)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (push_token) DO UPDATE
        SET user_id = EXCLUDED.user_id,
            platform = EXCLUDED.platform,
            -- Keep the known name/version when a re-registration leaves them out.
            device_name = COALESCE(NULLIF(EXCLUDED.device_name, ''), mobile_push_devices.device_name),
            app_version = COALESCE(NULLIF(EXCLUDED.app_version, ''), mobile_push_devices.app_version),
            is_active = true,
            updated_at = now(),
            last_seen_at = now()
     RETURNING *`,
    [String(userId), pushToken, platform, String(deviceName || '').slice(0, 120), String(appVersion || '').slice(0, 40)],
  );
  return mapRow(rows[0]);
}

/** Logout: only the owner can turn off their own phone. Returns true when a row changed. */
async function deactivateForUser(userId, pushToken) {
  const { rowCount } = await query(
    `UPDATE mobile_push_devices
        SET is_active = false, updated_at = now()
      WHERE user_id = $1 AND push_token = $2 AND is_active`,
    [String(userId), pushToken],
  );
  return rowCount > 0;
}

/** Called when Firebase reports the app was uninstalled or the token is invalid. */
async function deactivateTokens(pushTokens) {
  if (!pushTokens.length) return 0;
  const { rowCount } = await query(
    `UPDATE mobile_push_devices
        SET is_active = false, updated_at = now()
      WHERE push_token = ANY($1::text[]) AND is_active`,
    [pushTokens],
  );
  return rowCount;
}

async function listActiveTokensForUser(userId) {
  const { rows } = await query(
    `SELECT push_token FROM mobile_push_devices WHERE user_id = $1 AND is_active ORDER BY last_seen_at DESC`,
    [String(userId)],
  );
  return rows.map((row) => row.push_token);
}

/**
 * Message notifications on/off (users.notify_new_lead, the column the Chattiq
 * API also reads before sending). Null when the user does not exist.
 */
async function getNotifyNewLead(userId) {
  const { rows } = await query(`SELECT notify_new_lead FROM users WHERE id = $1 LIMIT 1`, [String(userId)]);
  return rows[0] ? Boolean(rows[0].notify_new_lead) : null;
}

async function setNotifyNewLead(userId, enabled) {
  const { rows } = await query(
    `UPDATE users SET notify_new_lead = $2, updated_at = now() WHERE id = $1 RETURNING notify_new_lead`,
    [String(userId), Boolean(enabled)],
  );
  return rows[0] ? Boolean(rows[0].notify_new_lead) : null;
}

module.exports = {
  upsert,
  deactivateForUser,
  deactivateTokens,
  listActiveTokensForUser,
  getNotifyNewLead,
  setNotifyNewLead,
};
