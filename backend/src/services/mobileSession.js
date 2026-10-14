/**
 * Long-lived sign-in for the mobile app (refresh token rotation).
 *
 * - Login with `client: "mobile"` issues a refresh token in a new "family".
 * - Each refresh revokes the presented token and issues a new one in the same family.
 * - Presenting a token that was already rotated means it was copied: the whole
 *   family is revoked and the user must sign in again (reuse detection).
 * - Only SHA-256 hashes are stored (services/refreshTokens.js).
 *
 * Dependencies are injected so the rules can be unit-tested without a database.
 */
const {
  generateRefreshToken,
  hashRefreshToken,
  newTokenFamilyId,
  refreshTokenExpiry,
} = require('./refreshTokens');

class RefreshTokenError extends Error {
  /** @param {'INVALID'|'EXPIRED'|'REUSED'|'ACCOUNT_UNAVAILABLE'} code */
  constructor(code, message) {
    super(message);
    this.name = 'RefreshTokenError';
    this.code = code;
  }
}

/** Same account rules as the Chattiq login: verified, approved, not blocked. */
function accountCanSignIn(user, now) {
  if (!user) return false;
  if (!user.isEmailVerified) return false;
  const approved = user.role === 'admin' || String(user.accountStatus || 'approved') === 'approved';
  if (!approved) return false;
  if (user.isBlocked) {
    if (!user.blockedUntil) return false;
    if (new Date(user.blockedUntil).getTime() > now.getTime()) return false;
  }
  return true;
}

/**
 * @param {{
 *   tokenRepo: { transaction: Function, findByHash: Function, revokeFamily: Function },
 *   findUserById: (id: string) => Promise<object|null>,
 *   now?: () => Date,
 * }} deps
 */
function createMobileSessionService({ tokenRepo, findUserById, now = () => new Date() }) {
  async function storeNewToken(repo, { userId, familyId, deviceName }) {
    const token = generateRefreshToken();
    await repo.create({
      userId,
      tokenHash: hashRefreshToken(token),
      familyId,
      deviceName,
      expiresAt: refreshTokenExpiry(now()),
    });
    return token;
  }

  /** Called after a successful mobile login. Returns the raw token for the app. */
  async function issueForLogin(userId, { deviceName = '' } = {}) {
    return tokenRepo.transaction((repo) =>
      storeNewToken(repo, { userId, familyId: newTokenFamilyId(), deviceName }),
    );
  }

  /**
   * Swaps a valid refresh token for a new one.
   * @returns {Promise<{ user: object, refreshToken: string }>}
   * @throws {RefreshTokenError}
   */
  async function rotate(rawToken) {
    const tokenHash = hashRefreshToken(rawToken);
    const outcome = await tokenRepo.transaction(async (repo) => {
      const row = await repo.findByHashForUpdate(tokenHash);
      if (!row) return { error: new RefreshTokenError('INVALID', 'Session not found. Please log in again.') };

      if (row.revokedAt) {
        // A rotated token came back: someone else holds a copy. End that sign-in everywhere.
        await repo.revokeFamily(row.familyId, 'reuse_detected');
        return { error: new RefreshTokenError('REUSED', 'Your session has ended. Please log in again.') };
      }

      const current = now();
      if (new Date(row.expiresAt).getTime() <= current.getTime()) {
        await repo.revokeFamily(row.familyId, 'expired');
        return { error: new RefreshTokenError('EXPIRED', 'Your session has expired. Please log in again.') };
      }

      const user = await findUserById(row.userId);
      if (!accountCanSignIn(user, current)) {
        await repo.revokeFamily(row.familyId, 'account_unavailable');
        return { error: new RefreshTokenError('ACCOUNT_UNAVAILABLE', 'This account can no longer sign in.') };
      }

      await repo.markUsedAndRevoke(row.id, 'rotated');
      const refreshToken = await storeNewToken(repo, {
        userId: row.userId,
        familyId: row.familyId,
        deviceName: row.deviceName,
      });
      return { user, refreshToken };
    });

    // Errors are returned, not thrown, inside the transaction so the family
    // revocation above is committed instead of rolled back.
    if (outcome.error) throw outcome.error;
    return outcome;
  }

  /** Logout: ends this sign-in on the device. Unknown tokens are ignored. */
  async function revoke(rawToken) {
    const row = await tokenRepo.findByHash(hashRefreshToken(rawToken));
    if (!row) return false;
    await tokenRepo.revokeFamily(row.familyId, 'logout');
    return true;
  }

  return { issueForLogin, rotate, revoke };
}

module.exports = { createMobileSessionService, RefreshTokenError, accountCanSignIn };
