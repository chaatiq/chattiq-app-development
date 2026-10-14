const { getPool, query } = require('../db/pool');

/** Table: refresh_tokens (db/migrations/001_mobile_tables.sql). */

function mapRow(row) {
  if (!row) return null;
  return {
    id: row.id,
    userId: row.user_id,
    tokenHash: row.token_hash,
    familyId: row.family_id,
    deviceName: row.device_name,
    createdAt: row.created_at,
    expiresAt: row.expires_at,
    lastUsedAt: row.last_used_at,
    revokedAt: row.revoked_at,
    revokedReason: row.revoked_reason,
  };
}

/**
 * Repository bound to one connection (the pool, or a transaction client), so
 * the same functions work inside and outside a transaction.
 */
function bind(run) {
  return {
    async create({ userId, tokenHash, familyId, deviceName = '', expiresAt }) {
      const { rows } = await run(
        `INSERT INTO refresh_tokens (user_id, token_hash, family_id, device_name, expires_at)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [String(userId), tokenHash, familyId, String(deviceName || '').slice(0, 120), expiresAt],
      );
      return mapRow(rows[0]);
    },

    /** Locks the row until the transaction ends, so one token can't be rotated twice in parallel. */
    async findByHashForUpdate(tokenHash) {
      const { rows } = await run(`SELECT * FROM refresh_tokens WHERE token_hash = $1 LIMIT 1 FOR UPDATE`, [
        tokenHash,
      ]);
      return mapRow(rows[0]);
    },

    async findByHash(tokenHash) {
      const { rows } = await run(`SELECT * FROM refresh_tokens WHERE token_hash = $1 LIMIT 1`, [tokenHash]);
      return mapRow(rows[0]);
    },

    async markUsedAndRevoke(id, reason) {
      await run(
        `UPDATE refresh_tokens
            SET revoked_at = COALESCE(revoked_at, now()),
                revoked_reason = COALESCE(revoked_reason, $2),
                last_used_at = now()
          WHERE id = $1`,
        [id, reason],
      );
    },

    /** Revokes every still-active token issued from the same sign-in. */
    async revokeFamily(familyId, reason) {
      const { rowCount } = await run(
        `UPDATE refresh_tokens
            SET revoked_at = now(), revoked_reason = $2
          WHERE family_id = $1 AND revoked_at IS NULL`,
        [familyId, reason],
      );
      return rowCount;
    },
  };
}

const repo = bind((text, params) => query(text, params));

/** Runs `fn(txRepo)` in one transaction; rolls back if it throws. */
async function transaction(fn) {
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    const result = await fn(bind((text, params) => client.query(text, params)));
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { ...repo, transaction };
