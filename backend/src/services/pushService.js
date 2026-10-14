/**
 * Push notifications to the app through Firebase Cloud Messaging (FCM).
 *
 * Dependencies are injected so sending rules can be unit-tested without a
 * database or network (tests/pushService.test.js).
 */
const fs = require('fs');

/** Android notification channel; the app creates a channel with this id. */
const CHAT_CHANNEL_ID = 'chat-messages';

/** Notification icon (app res/drawable) and tint: the Chattiq logo green. */
const ANDROID_ICON = 'ic_notification';
const ANDROID_COLOR = '#00C158';

/** Longest message preview shown in the notification body. */
const PREVIEW_MAX = 140;

/** FCM accepts at most 500 tokens per multicast request. */
const FCM_BATCH = 500;

/**
 * FCM error codes meaning the token will never work again (app uninstalled,
 * token rotated or malformed): the phone is deactivated.
 */
const DEAD_TOKEN_ERRORS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

function clean(value) {
  const text = String(value || '').trim();
  const lower = text.toLowerCase();
  return lower === 'unknown' || lower === 'not provided' || lower === 'n/a' ? '' : text;
}

/**
 * WhatsApp-style notification for a customer message: the sender as the title
 * and the message as the body, e.g. "Rahul Sharma" / "Do you have a slot tomorrow?".
 */
function buildNewMessageNotification({ sessionId, agentId, senderName, text, source }) {
  const fallbackSender = source === 'whatsapp' ? 'WhatsApp user' : 'Website visitor';
  const message = String(text || '').replace(/\s+/g, ' ').trim();
  const body = message.length > PREVIEW_MAX ? `${message.slice(0, PREVIEW_MAX - 1)}…` : message;

  return {
    title: clean(senderName) || fallbackSender,
    body: body || 'Sent a message',
    // FCM data values must be strings.
    data: { type: 'new_message', sessionId: String(sessionId), agentId: agentId ? String(agentId) : '' },
    channelId: CHAT_CHANNEL_ID,
  };
}

/**
 * @param {{
 *   getMessaging: () => ({ sendEachForMulticast: Function } | null),
 *   deviceRepo: {
 *     listActiveTokensForUser: (userId: string) => Promise<string[]>,
 *     deactivateTokens: (tokens: string[]) => Promise<number>,
 *     getNotifyNewLead: (userId: string) => Promise<boolean|null>,
 *   },
 *   logger?: Pick<Console, 'warn'|'error'>,
 * }} deps
 */
function createPushService({ getMessaging, deviceRepo, logger = console }) {
  /**
   * Sends one notification to every active phone of a user.
   * Never throws for delivery problems; returns counts instead.
   */
  async function sendToUser(userId, { title, body, data = {}, channelId }) {
    const tokens = await deviceRepo.listActiveTokensForUser(userId);
    if (!tokens.length) return { sent: 0, failed: 0, deactivated: 0 };

    const messaging = getMessaging();
    if (!messaging) return { skipped: 'push_not_configured' };

    let sent = 0;
    let failed = 0;
    const deadTokens = [];
    for (let start = 0; start < tokens.length; start += FCM_BATCH) {
      const batch = tokens.slice(start, start + FCM_BATCH);
      let result;
      try {
        result = await messaging.sendEachForMulticast({
          tokens: batch,
          notification: { title, body },
          data,
          android: {
            priority: 'high',
            notification: {
              channelId,
              icon: ANDROID_ICON,
              color: ANDROID_COLOR,
              // One notification per chat: a newer message replaces the older one.
              tag: data.sessionId || undefined,
            },
          },
        });
      } catch (err) {
        failed += batch.length;
        logger.error('[push] FCM request failed', err?.message || err);
        continue;
      }
      result.responses.forEach((response, index) => {
        if (response.success) {
          sent += 1;
          return;
        }
        failed += 1;
        const code = response.error?.code;
        if (DEAD_TOKEN_ERRORS.has(code)) deadTokens.push(batch[index]);
        else logger.warn('[push] FCM error', code || response.error?.message);
      });
    }

    if (deadTokens.length) await deviceRepo.deactivateTokens(deadTokens);
    return { sent, failed, deactivated: deadTokens.length };
  }

  /**
   * Notify the agent owner about a new customer message, unless they turned
   * notifications off (Settings > Message notifications in the app).
   */
  async function notifyNewMessage(ownerUserId, message) {
    // The app shows WhatsApp chats only, so website chatbot messages do not notify.
    if (message.source !== 'whatsapp') return { skipped: 'not_whatsapp' };
    const enabled = await deviceRepo.getNotifyNewLead(ownerUserId);
    if (enabled === null) return { skipped: 'unknown_user' };
    if (!enabled) return { skipped: 'alerts_off' };
    return sendToUser(ownerUserId, buildNewMessageNotification(message));
  }

  return { sendToUser, notifyNewMessage };
}

/**
 * Production wiring: Firebase Admin with the service account key file named by
 * FIREBASE_SERVICE_ACCOUNT_FILE. Without it notifications are skipped (logged once).
 */
let messagingClient;
function getFirebaseMessaging() {
  if (messagingClient !== undefined) return messagingClient;
  const keyFile = String(process.env.FIREBASE_SERVICE_ACCOUNT_FILE || '').trim();
  if (!keyFile) {
    console.warn('FIREBASE_SERVICE_ACCOUNT_FILE is not set: message notifications are not sent.');
    messagingClient = null;
    return messagingClient;
  }
  try {
    const { cert, getApps, initializeApp } = require('firebase-admin/app');
    const { getMessaging } = require('firebase-admin/messaging');
    const serviceAccount = JSON.parse(fs.readFileSync(keyFile, 'utf8'));
    const app = getApps()[0] ?? initializeApp({ credential: cert(serviceAccount) });
    messagingClient = getMessaging(app);
  } catch (err) {
    console.error('Firebase could not start; message notifications are not sent:', err.message);
    messagingClient = null;
  }
  return messagingClient;
}

let defaultService = null;
function getPushService() {
  if (!defaultService) {
    defaultService = createPushService({
      deviceRepo: require('../repositories/deviceRepo'),
      getMessaging: getFirebaseMessaging,
    });
  }
  return defaultService;
}

module.exports = {
  CHAT_CHANNEL_ID,
  DEAD_TOKEN_ERRORS,
  buildNewMessageNotification,
  createPushService,
  getPushService,
};
