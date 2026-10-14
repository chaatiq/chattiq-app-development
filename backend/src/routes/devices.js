const express = require('express');

const { validateBody } = require('../middleware/validate');
const { pushToken, deviceRegisterSchema, notificationSettingsSchema } = require('../schemas');

/**
 *   POST   /api/devices                     register this phone for notifications
 *   DELETE /api/devices/:token              unregister it on logout
 *   GET    /api/me/notification-settings    message notifications on/off
 *   PATCH  /api/me/notification-settings
 */
function createDevicesRouter({ requireUser, deviceRepo, logger = console }) {
  const router = express.Router();
  // Body parsing only on these routes: every other request is forwarded with its body intact.
  const json = express.json({ limit: '20kb' });

  router.post('/devices', requireUser, json, validateBody(deviceRegisterSchema), async (req, res) => {
    try {
      const device = await deviceRepo.upsert({ userId: req.user.id, ...req.body });
      return res.json({
        success: true,
        device: { platform: device.platform, deviceName: device.deviceName, isActive: device.isActive },
      });
    } catch (err) {
      logger.error('register device', err);
      return res.status(500).json({ success: false, message: 'Failed to register device' });
    }
  });

  router.delete('/devices/:token', requireUser, async (req, res) => {
    const { error, value: token } = pushToken.validate(req.params.token);
    if (error) return res.status(400).json({ success: false, code: 'VALIDATION_ERROR', message: error.message });
    try {
      const removed = await deviceRepo.deactivateForUser(req.user.id, token);
      // Idempotent: logging out twice, or after the phone moved to another user, is not an error.
      return res.json({ success: true, removed });
    } catch (err) {
      logger.error('unregister device', err);
      return res.status(500).json({ success: false, message: 'Failed to remove device' });
    }
  });

  router.get('/me/notification-settings', requireUser, async (req, res) => {
    try {
      const notifyNewLead = await deviceRepo.getNotifyNewLead(req.user.id);
      if (notifyNewLead === null) return res.status(404).json({ success: false, message: 'User not found' });
      return res.json({ success: true, notifyNewLead });
    } catch (err) {
      logger.error('get notification settings', err);
      return res.status(500).json({ success: false, message: 'Failed to load notification settings' });
    }
  });

  router.patch('/me/notification-settings', requireUser, json, validateBody(notificationSettingsSchema), async (req, res) => {
    try {
      const notifyNewLead = await deviceRepo.setNotifyNewLead(req.user.id, req.body.notifyNewLead);
      if (notifyNewLead === null) return res.status(404).json({ success: false, message: 'User not found' });
      return res.json({ success: true, notifyNewLead });
    } catch (err) {
      logger.error('update notification settings', err);
      return res.status(500).json({ success: false, message: 'Failed to update notification settings' });
    }
  });

  return router;
}

module.exports = { createDevicesRouter };
