const crypto = require('crypto');

/** Constant-time check of the x-internal-api-key header against the configured key. */
function internalKeyMatches(configuredKey, providedKey) {
  const configured = String(configuredKey || '').trim();
  const provided = String(providedKey || '').trim();
  if (!configured || !provided) return false;
  const a = Buffer.from(configured);
  const b = Buffer.from(provided);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

/** For server-to-server calls only. Rejects before the body is read or validated. */
function requireInternalKey(configuredKey) {
  return function requireInternalKeyMiddleware(req, res, next) {
    if (!internalKeyMatches(configuredKey, req.headers['x-internal-api-key'])) {
      return res.status(401).json({ success: false, message: 'Unauthorised internal request' });
    }
    return next();
  };
}

module.exports = { requireInternalKey, internalKeyMatches };
