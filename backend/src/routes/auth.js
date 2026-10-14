const express = require('express');
const jwt = require('jsonwebtoken');

const { validateBody } = require('../middleware/validate');
const { loginSchema, refreshTokenSchema } = require('../schemas');
const { RefreshTokenError } = require('../services/mobileSession');

/** Same lifetime and payload as the Chattiq API, so either side accepts the token. */
function signAccessToken(user, jwtSecret) {
  const payload = { id: user.id, role: user.role, email: user.email, userName: user.userName };
  return jwt.sign(payload, jwtSecret, { expiresIn: '2h' });
}

function publicUser(user) {
  return {
    id: user.id,
    email: user.email,
    role: user.role,
    userName: user.userName,
    phone: user.phone || '',
    avatarUrl: user.avatarUrl || '',
    isEmailVerified: Boolean(user.isEmailVerified),
    accountStatus: user.accountStatus || 'approved',
  };
}

/**
 *   POST /api/auth/login          Chattiq login + a 30-day refresh token for the app
 *   POST /api/auth/refresh        swap a refresh token for new tokens
 *   POST /api/auth/logout-mobile  end this phone's sign-in
 */
function createAuthRouter({ jwtSecret, chattiqClient, mobileSessions, logger = console }) {
  const router = express.Router();
  // Body parsing only on these routes: other /api/auth/* requests are forwarded with their body intact.
  const json = express.json({ limit: '20kb' });

  router.post('/login', json, validateBody(loginSchema), async (req, res) => {
    const { email, password, client, deviceName } = req.body;
    let result;
    try {
      result = await chattiqClient.login({ email, password });
    } catch (err) {
      logger.error('login: Chattiq API unreachable', err?.message || err);
      return res.status(502).json({ success: false, message: 'Login is temporarily unavailable. Please try again.' });
    }

    const { status, body } = result;
    const userId = body?.user?.id;
    if (status !== 200 || !body?.success || !body?.accessToken || !userId || client !== 'mobile') {
      return res.status(status).json(body);
    }

    try {
      const refreshToken = await mobileSessions.issueForLogin(userId, { deviceName });
      return res.json({ ...body, refreshToken });
    } catch (err) {
      logger.error('login: could not issue refresh token', err);
      return res.status(500).json({ success: false, message: 'Server error' });
    }
  });

  router.post('/refresh', json, validateBody(refreshTokenSchema), async (req, res) => {
    try {
      const { user, refreshToken } = await mobileSessions.rotate(req.body.refreshToken);
      return res.json({
        success: true,
        accessToken: signAccessToken(user, jwtSecret),
        refreshToken,
        user: publicUser(user),
      });
    } catch (err) {
      if (err instanceof RefreshTokenError) {
        // Same 401 for every case so the app simply returns to the login screen.
        return res.status(401).json({ success: false, code: `REFRESH_${err.code}`, message: err.message });
      }
      logger.error('refresh failed', err);
      return res.status(500).json({ success: false, message: 'Server error' });
    }
  });

  router.post('/logout-mobile', json, validateBody(refreshTokenSchema), async (req, res) => {
    try {
      await mobileSessions.revoke(req.body.refreshToken);
    } catch (err) {
      // Logout must always succeed for the app; the token simply expires later.
      logger.error('logout-mobile failed', err);
    }
    return res.json({ success: true, message: 'Logged out' });
  });

  return router;
}

module.exports = { createAuthRouter, signAccessToken };
