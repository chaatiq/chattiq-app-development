/**
 * Unit tests for new-message notifications over FCM (src/services/pushService.js).
 * Run: npm test   (no database or network needed)
 */
const { test, describe } = require('node:test');
const assert = require('node:assert/strict');

const { buildNewMessageNotification, createPushService, CHAT_CHANNEL_ID } = require('../src/services/pushService');

const PHONE_A = 'fcm-token-aaaaaaaaaaaaaaaaaaaa';
const PHONE_B = 'fcm-token-bbbbbbbbbbbbbbbbbbbb';

/** Fake repo + fake FCM. `results(token)` decides each phone's outcome. */
function createFakes({ tokens = [PHONE_A], notify = true, results, fcmDown = false, configured = true } = {}) {
  const state = { requests: [], deactivated: [] };
  const deviceRepo = {
    async listActiveTokensForUser() {
      return tokens.filter((token) => !state.deactivated.includes(token));
    },
    async deactivateTokens(list) {
      state.deactivated.push(...list);
      return list.length;
    },
    async getNotifyNewLead() {
      return notify;
    },
  };
  const messaging = {
    async sendEachForMulticast(message) {
      state.requests.push(message);
      if (fcmDown) throw new Error('network down');
      return { responses: message.tokens.map((token) => (results ? results(token) : { success: true })) };
    },
  };
  const service = createPushService({
    deviceRepo,
    getMessaging: () => (configured ? messaging : null),
    logger: { warn() {}, error() {} },
  });
  return { service, state };
}

const message = { sessionId: 's1', agentId: 'a1', senderName: 'Asha', text: 'Hi', source: 'whatsapp' };

describe('new message notification text', () => {
  test('sender as title, message as body, chat id in data (strings only)', () => {
    const n = buildNewMessageNotification({
      sessionId: 's1',
      agentId: 'a1',
      senderName: 'Rahul Sharma',
      text: 'Do you have a slot tomorrow?',
      source: 'whatsapp',
    });
    assert.equal(n.title, 'Rahul Sharma');
    assert.equal(n.body, 'Do you have a slot tomorrow?');
    assert.deepEqual(n.data, { type: 'new_message', sessionId: 's1', agentId: 'a1' });
    assert.equal(n.channelId, CHAT_CHANNEL_ID);
    assert.equal(buildNewMessageNotification({ sessionId: 's1', text: 'x', source: 'website' }).data.agentId, '');
  });

  test('unknown sender falls back to the channel name', () => {
    assert.equal(
      buildNewMessageNotification({ sessionId: 's1', senderName: 'Unknown', text: 'hi', source: 'whatsapp' }).title,
      'WhatsApp user',
    );
    assert.equal(buildNewMessageNotification({ sessionId: 's1', text: 'hi', source: 'website' }).title, 'Website visitor');
  });

  test('long messages are shortened and whitespace collapsed', () => {
    const n = buildNewMessageNotification({ sessionId: 's1', text: `hello\n\n${'a'.repeat(300)}`, source: 'website' });
    assert.ok(n.body.length <= 140);
    assert.ok(n.body.endsWith('…'));
    assert.ok(!n.body.includes('\n'));
  });
});

describe('sending over FCM', () => {
  test('one request to every active phone: high priority, chat channel, Chattiq icon', async () => {
    const { service, state } = createFakes({ tokens: [PHONE_A, PHONE_B] });
    assert.deepEqual(await service.notifyNewMessage('user-1', message), { sent: 2, failed: 0, deactivated: 0 });
    const request = state.requests[0];
    assert.deepEqual(request.tokens, [PHONE_A, PHONE_B]);
    assert.deepEqual(request.notification, { title: 'Asha', body: 'Hi' });
    assert.equal(request.android.priority, 'high');
    assert.equal(request.android.notification.channelId, CHAT_CHANNEL_ID);
    assert.equal(request.android.notification.icon, 'ic_notification');
    assert.equal(request.android.notification.tag, 's1');
  });

  test('website chatbot message: nothing is sent (the app shows WhatsApp chats only)', async () => {
    const { service, state } = createFakes({ tokens: [PHONE_A] });
    assert.deepEqual(await service.notifyNewMessage('user-1', { ...message, source: 'website' }), {
      skipped: 'not_whatsapp',
    });
    assert.equal(state.requests.length, 0);
  });

  test('notifications turned off: nothing is sent', async () => {
    const { service, state } = createFakes({ notify: false });
    assert.deepEqual(await service.notifyNewMessage('user-1', message), { skipped: 'alerts_off' });
    assert.equal(state.requests.length, 0);
  });

  test('unknown user: nothing is sent', async () => {
    const { service } = createFakes({ notify: null });
    assert.deepEqual(await service.notifyNewMessage('ghost', message), { skipped: 'unknown_user' });
  });

  test('no registered phone: nothing is sent, no error', async () => {
    const { service, state } = createFakes({ tokens: [] });
    assert.deepEqual(await service.notifyNewMessage('user-1', message), { sent: 0, failed: 0, deactivated: 0 });
    assert.equal(state.requests.length, 0);
  });

  test('uninstalled app (token not registered) is deactivated at once', async () => {
    const { service, state } = createFakes({
      tokens: [PHONE_A, PHONE_B],
      results: (token) =>
        token === PHONE_B
          ? { success: false, error: { code: 'messaging/registration-token-not-registered' } }
          : { success: true },
    });
    assert.deepEqual(await service.notifyNewMessage('user-1', message), { sent: 1, failed: 1, deactivated: 1 });
    assert.deepEqual(state.deactivated, [PHONE_B]);
  });

  test('a temporary FCM error keeps the phone', async () => {
    const { service, state } = createFakes({
      results: () => ({ success: false, error: { code: 'messaging/internal-error' } }),
    });
    assert.deepEqual(await service.notifyNewMessage('user-1', message), { sent: 0, failed: 1, deactivated: 0 });
    assert.deepEqual(state.deactivated, []);
  });

  test('FCM outage is reported, not thrown', async () => {
    const { service } = createFakes({ fcmDown: true });
    assert.deepEqual(await service.notifyNewMessage('user-1', message), { sent: 0, failed: 1, deactivated: 0 });
  });

  test('Firebase not configured: skipped, not thrown', async () => {
    const { service } = createFakes({ configured: false });
    assert.deepEqual(await service.notifyNewMessage('user-1', message), { skipped: 'push_not_configured' });
  });
});
