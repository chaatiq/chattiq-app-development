const { query } = require('../db/pool');

/**
 * Read-only access to the Chattiq users table: only the fields needed to sign
 * a user in and to check that the account may still use the app.
 */
async function findById(id) {
  const { rows } = await query(
    `SELECT id, email, user_name, role, phone, avatar_url,
            is_email_verified, account_status, is_blocked, blocked_until
       FROM users
      WHERE id = $1
      LIMIT 1`,
    [String(id)],
  );
  const row = rows[0];
  if (!row) return null;
  return {
    id: row.id,
    email: row.email,
    userName: row.user_name,
    role: row.role,
    phone: row.phone || '',
    avatarUrl: row.avatar_url || '',
    isEmailVerified: Boolean(row.is_email_verified),
    // A missing status (older rows) counts as approved, like the Chattiq API.
    accountStatus: row.account_status == null ? 'approved' : row.account_status,
    isBlocked: Boolean(row.is_blocked),
    blockedUntil: row.blocked_until,
  };
}

module.exports = { findById };
