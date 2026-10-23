/**
 * HTTP tests for the mobile backend (src/app.js) against a fake Chattiq API.
 * Run: npm test   (no database needed)
 */
const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const jwt = require('jsonwebtoken');

const { createApp } = require('../src/app');

const JWT_SECRET = 'test-secret';
const NOTIFY_KEY = 'test-notify-key';
const USER = {
  id: 'user-1',
  email: 'owner@example.com',
  userName: 'Owner',
  role: 'user',
  isEmailVerified: true,
  accountStatus: 'approved',
  isBlocked: false,
};

function listen(app) {
  return new Promise((resolve) => {
    const server = http.createServer(app).listen(0, '127.0.0.1', () => resolve(server));
  });
}

const baseUrl = (server) => `http://127.0.0.1:${server.address().port}`;
const silentLogger = { error() {}, warn() {}, log() {} };

describe('mobile backend', () => {
  let chattiq;
  let mobile;
  let url;
  const seen = { forwarded: [], notified: [], registered: [], logins: [] };

  before(async () => {
    // Fake Chattiq API: one data route, and echoes what it receives.
    const fake = express();
    fake.use(express.json());
    fake.get('/api/dashboard/sessions', (req, res) => {
      seen.forwarded.push({ path: req.originalUrl, auth: req.headers.authorization, xff: req.headers['x-forwarded-for'] });
      res.json([{ session_id: 's1' }]);
    });
    fake.post('/api/auth/forgot-password', (req, res) => res.json({ echoed: req.body }));
    chattiq = await listen(fake);

    const app = createApp({
      config: { jwtSecret: JWT_SECRET, notifyApiKey: NOTIFY_KEY, chattiqApiUrl: `${baseUrl(chattiq)}/api` },
      userRepo: { findById: async (id) => (id === USER.id ? USER : null) },
      deviceRepo: {
        upsert: async (device) => {
          seen.registered.push(device);
          return { ...device, isActive: true };
        },
        deactivateForUser: async () => true,
        getNotifyNewLead: async () => true,
        setNotifyNewLead: async (_id, enabled) => enabled,
      },
      mobileSessions: {
        issueForLogin: async () => 'r'.repeat(64),
        rotate: async () => ({ user: USER, refreshToken: 'n'.repeat(64) }),
        revoke: async () => true,
      },
      pushService: {
        notifyNewMessage: async (owner, message) => {
          seen.notified.push({ owner, message });
          if (seen.slowPush) await new Promise((resolve) => setTimeout(resolve, 3000));
          return { sent: 1, failed: 0, deactivated: 0 };
        },
      },
      chattiqClient: {
        login: async ({ password, forwardedFor }) => {
          seen.logins.push({ forwardedFor });
          return password === 'correct-password'
            ? { status: 200, body: { success: true, accessToken: 'chattiq-token', user: { id: USER.id } } }
            : { status: 401, body: { success: false, message: 'Incorrect password' } };
        },
      },
      logger: silentLogger,
    });
    mobile = await listen(app);
    url = baseUrl(mobile);
  });

  after(() => {
    chattiq.close();
    mobile.close();
  });

  const post = (path, body, headers = {}) =>
    fetch(`${url}${path}`, { method: 'POST', headers: { 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(body) });

  test('mobile login returns the Chattiq response plus a refresh token', async () => {
    const res = await post('/api/auth/login', { email: 'owner@example.com', password: 'correct-password', client: 'mobile' });
    const body = await res.json();
    assert.equal(res.status, 200);
    assert.equal(body.accessToken, 'chattiq-token');
    assert.equal(body.refreshToken.length, 64);
  });

  test('wrong password: Chattiq error is passed through, no refresh token', async () => {
    const res = await post('/api/auth/login', { email: 'owner@example.com', password: 'wrong-password', client: 'mobile' });
    const body = await res.json();
    assert.equal(res.status, 401);
    assert.equal(body.message, 'Incorrect password');
    assert.equal(body.refreshToken, undefined);
  });

  test('refresh issues an access token the Chattiq API accepts (same secret and payload)', async () => {
    const res = await post('/api/auth/refresh', { refreshToken: 'x'.repeat(64) });
    const body = await res.json();
    assert.equal(res.status, 200);
    const payload = jwt.verify(body.accessToken, JWT_SECRET);
    assert.equal(payload.id, USER.id);
    assert.equal(payload.email, USER.email);
  });

  test('device registration needs a valid access token', async () => {
    const device = { pushToken: 'fcm-token-abcdefghijklmnopqrstuvwxyz:123', platform: 'android' };
    assert.equal((await post('/api/devices', device)).status, 401);

    const token = jwt.sign({ id: USER.id }, JWT_SECRET);
    const res = await post('/api/devices', device, { Authorization: `Bearer ${token}` });
    assert.equal(res.status, 200);
    assert.equal(seen.registered.at(-1).userId, USER.id);
  });

  test('internal notify requires the key', async () => {
    const message = { ownerUserId: USER.id, sessionId: 's1', text: 'Hi', source: 'website' };
    assert.equal((await post('/api/internal/notify-message', message)).status, 401);
    assert.equal((await post('/api/internal/notify-message', message, { 'x-internal-api-key': 'wrong' })).status, 401);

    const res = await post('/api/internal/notify-message', message, { 'x-internal-api-key': NOTIFY_KEY });
    assert.equal(res.status, 202);
    assert.deepEqual(await res.json(), { success: true, queued: true });
    assert.equal(seen.notified.at(-1).owner, USER.id);
  });

  test('internal notify answers at once even when sending is slow', async () => {
    seen.slowPush = true;
    const started = Date.now();
    const res = await post(
      '/api/internal/notify-message',
      { ownerUserId: USER.id, sessionId: 's2', text: 'Hi', source: 'whatsapp' },
      { 'x-internal-api-key': NOTIFY_KEY },
    );
    seen.slowPush = false;
    assert.equal(res.status, 202);
    assert.ok(Date.now() - started < 1000, 'the AI runtime must not wait for Firebase');
  });

  test('other requests are forwarded to Chattiq with the Authorization header', async () => {
    const res = await fetch(`${url}/api/dashboard/sessions?limit=200`, { headers: { Authorization: 'Bearer abc' } });
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), [{ session_id: 's1' }]);
    assert.deepEqual(seen.forwarded.at(-1), { path: '/api/dashboard/sessions?limit=200', auth: 'Bearer abc', xff: undefined });
  });

  test('forwarded requests keep the X-Forwarded-For from nginx unchanged', async () => {
    await fetch(`${url}/api/dashboard/sessions`, { headers: { 'X-Forwarded-For': '203.0.113.7, 10.0.0.5' } });
    assert.equal(seen.forwarded.at(-1).xff, '203.0.113.7, 10.0.0.5');
  });

  test('login passes the X-Forwarded-For on to the Chattiq API', async () => {
    await post(
      '/api/auth/login',
      { email: 'owner@example.com', password: 'correct-password', client: 'mobile' },
      { 'X-Forwarded-For': '203.0.113.7, 10.0.0.5' },
    );
    assert.equal(seen.logins.at(-1).forwardedFor, '203.0.113.7, 10.0.0.5');
  });

  test('forwarded POST requests keep their body (even under /api/auth)', async () => {
    const res = await post('/api/auth/forgot-password', { email: 'owner@example.com' });
    assert.deepEqual(await res.json(), { echoed: { email: 'owner@example.com' } });
  });
});
