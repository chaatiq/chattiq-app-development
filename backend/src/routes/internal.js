const express = require('express');

const { requireInternalKey } = require('../middleware/internalKey');
const { validateBody } = require('../middleware/validate');
const { notifyMessageSchema } = require('../schemas');

/**
 *   POST /api/internal/notify-message
 * Called by the Chattiq AI runtime (x-internal-api-key) when a customer sends
 * a message, so the agent owner's phones get a notification.
 */
function createInternalRouter({ notifyApiKey, pushService, logger = console }) {
  const router = express.Router();

  router.post(
    '/internal/notify-message',
    // Check the key before reading the body so unauthenticated callers learn nothing.
    requireInternalKey(notifyApiKey),
    express.json({ limit: '50kb' }),
    validateBody(notifyMessageSchema),
    (req, res) => {
      const { ownerUserId, ...message } = req.body;
      // Answer at once and send in the background. The AI runtime waits only a
      // few seconds and retries on a timeout; a slow first Firebase call (it
      // fetches an OAuth token) would otherwise cause duplicate notifications.
      pushService
        .notifyNewMessage(ownerUserId, message)
        .then((result) => {
          if (result?.failed || result?.skipped === 'push_not_configured') {
            logger.warn('[push] notify-message', message.sessionId, result);
          }
        })
        .catch((err) => logger.error('[push] notify-message failed', message.sessionId, err?.message || err));
      return res.status(202).json({ success: true, queued: true });
    },
  );

  return router;
}

module.exports = { createInternalRouter };
