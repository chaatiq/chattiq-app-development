const jwt = require('jsonwebtoken');

const { accountCanSignIn } = require('../services/mobileSession');

function readBearerToken(req) {
  const raw = req.headers.authorization;
  if (!raw || typeof raw !== 'string') return null;
  const match = /^Bearer\s+(\S+)$/i.exec(raw.trim());
  return match ? match[1] : null;
}

/**
 * Requires a valid access token (the same JWT the Chattiq API issues) and an
 * account that may still sign in. Sets req.user.
 */
function requireUser({ jwtSecret, userRepo }) {
  return async function requireUserMiddleware(req, res, next) {
    const token = readBearerToken(req);
    if (!token) return res.status(401).json({ success: false, message: 'Unauthorised' });

    let payload;
    try {
      payload = jwt.verify(token, jwtSecret);
    } catch {
      return res.status(401).json({ success: false, message: 'Unauthorised' });
    }

    try {
      const user = await userRepo.findById(payload.id);
      if (!user) return res.status(401).json({ success: false, message: 'Unauthorised' });
      if (!accountCanSignIn(user, new Date())) {
        return res.status(403).json({ success: false, message: 'This account can no longer sign in.' });
      }
      req.user = user;
      return next();
    } catch (err) {
      return next(err);
    }
  };
}

module.exports = { requireUser, readBearerToken };
