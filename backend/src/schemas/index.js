const Joi = require('joi');

const loginSchema = Joi.object({
  // The Chattiq login accepts an email or a username.
  email: Joi.string().trim().min(3).max(254).required(),
  password: Joi.string().min(8).max(128).required(),
  // "mobile" also issues a 30-day refresh token.
  client: Joi.string().valid('web', 'mobile').optional(),
  deviceName: Joi.string().trim().max(120).allow('').optional(),
});

// Refresh tokens are 64 URL-safe characters (services/refreshTokens.js).
const refreshTokenSchema = Joi.object({
  refreshToken: Joi.string().trim().min(32).max(256).required(),
});

// Firebase Cloud Messaging registration token: long, URL-safe characters and ':'.
const pushToken = Joi.string()
  .trim()
  .min(20)
  .max(4096)
  .pattern(/^[A-Za-z0-9_:\-.]+$/)
  .messages({ 'string.pattern.base': 'pushToken must be a Firebase registration token' });

const deviceRegisterSchema = Joi.object({
  pushToken: pushToken.required(),
  platform: Joi.string().valid('android', 'ios').required(),
  deviceName: Joi.string().trim().max(120).allow('').optional(),
  appVersion: Joi.string().trim().max(40).allow('').optional(),
});

const notificationSettingsSchema = Joi.object({
  notifyNewLead: Joi.boolean().required(),
});

/** Sent by the Chattiq AI runtime when a customer sends a message. */
const notifyMessageSchema = Joi.object({
  ownerUserId: Joi.string().trim().max(128).required(),
  sessionId: Joi.string().trim().max(256).required(),
  agentId: Joi.string().trim().max(128).allow('', null).optional(),
  senderName: Joi.string().trim().max(200).allow('', null).optional(),
  text: Joi.string().max(4000).allow('').required(),
  source: Joi.string().valid('whatsapp', 'website').required(),
});

module.exports = {
  loginSchema,
  refreshTokenSchema,
  pushToken,
  deviceRegisterSchema,
  notificationSettingsSchema,
  notifyMessageSchema,
};
