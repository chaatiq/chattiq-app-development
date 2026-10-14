const express = require('express');
const helmet = require('helmet');
const { createProxyMiddleware } = require('http-proxy-middleware');

const { requireUser } = require('./middleware/auth');
const { createAuthRouter } = require('./routes/auth');
const { createDevicesRouter } = require('./routes/devices');
const { createInternalRouter } = require('./routes/internal');

const PROXY_TIMEOUT_MS = 60_000;

/**
 * The app talks to one URL: this service. Mobile-only endpoints are handled
 * here; every other /api request (chats, messages, takeover...) is forwarded
 * unchanged to the Chattiq API, including the Authorization header.
 *
 * Dependencies are passed in so tests can replace the database and network.
 */
function createApp({ config, userRepo, deviceRepo, mobileSessions, pushService, chattiqClient, logger = console }) {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', 1);
  app.use(helmet());

  // One line per request: method, full path, status, time. No query string (it
  // can hold ids) and no push token (it identifies a phone).
  app.use((req, res, next) => {
    const started = process.hrtime.bigint();
    const path = req.originalUrl.split('?')[0].replace(/^\/api\/devices\/[^/]+$/, '/api/devices/:token');
    res.on('finish', () => {
      const ms = Number(process.hrtime.bigint() - started) / 1e6;
      logger.log(`${req.method} ${path} ${res.statusCode} ${ms.toFixed(0)}ms`);
    });
    next();
  });

  app.get('/health', (req, res) => res.json({ ok: true }));

  const authUser = requireUser({ jwtSecret: config.jwtSecret, userRepo });

  app.use('/api/auth', createAuthRouter({ jwtSecret: config.jwtSecret, chattiqClient, mobileSessions, logger }));
  app.use('/api', createDevicesRouter({ requireUser: authUser, deviceRepo, logger }));
  app.use('/api', createInternalRouter({ notifyApiKey: config.notifyApiKey, pushService, logger }));

  app.use(
    '/api',
    createProxyMiddleware({
      target: config.chattiqApiUrl,
      changeOrigin: true,
      xfwd: true,
      proxyTimeout: PROXY_TIMEOUT_MS,
      on: {
        error(err, req, res) {
          logger.error('proxy to Chattiq API failed', req.method, req.originalUrl, err?.code || err?.message);
          if (res.headersSent || typeof res.status !== 'function') return;
          res.status(502).json({ success: false, message: 'The Chattiq API is not reachable. Please try again.' });
        },
      },
    }),
  );

  app.use((req, res) => res.status(404).json({ success: false, message: 'Not found' }));

  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    logger.error('unhandled error', err);
    if (res.headersSent) return;
    res.status(500).json({ success: false, message: 'Server error' });
  });

  return app;
}

module.exports = { createApp };
