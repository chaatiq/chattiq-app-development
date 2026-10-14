const crypto = require('crypto');

/** How long a mobile sign-in lasts without the app being opened. */
const REFRESH_TOKEN_TTL_DAYS = 30;
const REFRESH_TOKEN_TTL_MS = REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000;

/** 48 random bytes, URL-safe: 64 characters, unguessable. */
function generateRefreshToken() {
  return crypto.randomBytes(48).toString('base64url');
}

/**
 * Only this hash is stored. A leaked database row cannot be used to sign in,
 * and a fast hash is fine because the token itself has 384 bits of entropy.
 */
function hashRefreshToken(token) {
  return crypto.createHash('sha256').update(String(token), 'utf8').digest('hex');
}

/** Groups every token issued from one sign-in, so a stolen chain can be revoked at once. */
function newTokenFamilyId() {
  return crypto.randomUUID();
}

function refreshTokenExpiry(now = new Date()) {
  return new Date(now.getTime() + REFRESH_TOKEN_TTL_MS);
}

module.exports = {
  REFRESH_TOKEN_TTL_DAYS,
  REFRESH_TOKEN_TTL_MS,
  generateRefreshToken,
  hashRefreshToken,
  newTokenFamilyId,
  refreshTokenExpiry,
};
