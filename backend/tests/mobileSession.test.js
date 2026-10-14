/**
 * Unit tests for mobile refresh-token rotation (src/services/mobileSession.js).
 * Run: npm test   (Node's built-in test runner, no database needed)
 */
const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert/strict');

const { createMobileSessionService, RefreshTokenError } = require('../src/services/mobileSession');
const { hashRefreshToken, REFRESH_TOKEN_TTL_MS } = require('../src/services/refreshTokens');

/** In-memory stand-in for repositories/refreshTokenRepo.js with the same methods. */
function createFakeRepo() {
  const rows = [];
  let nextId = 1;
  const api = {
    rows,
    async create({ userId, tokenHash, familyId, deviceName = '', expiresAt }) {
      const row = { id: nextId++, userId, tokenHash, familyId, deviceName, expiresAt, revokedAt: null, revokedReason: null };
      rows.push(row);
      return row;
    },
    async findByHashForUpdate(tokenHash) {
      return rows.find((row) => row.tokenHash === tokenHash) ?? null;
    },
    async findByHash(tokenHash) {
      return rows.find((row) => row.tokenHash === tokenHash) ?? null;
    },
    async markUsedAndRevoke(id, reason) {
      const row = rows.find((item) => item.id === id);
      row.revokedAt = row.revokedAt ?? new Date();
      row.revokedReason = row.revokedReason ?? reason;
    },
    async revokeFamily(familyId, reason) {
      let count = 0;
      rows.forEach((row) => {
        if (row.familyId === familyId && !row.revokedAt) {
          row.revokedAt = new Date();
          row.revokedReason = reason;
          count += 1;
        }
      });
      return count;
    },
    async transaction(fn) {
      return fn(api);
    },
  };
  return api;
}

const activeUser = {
  id: 'user-1',
  email: 'owner@example.com',
  role: 'user',
  isEmailVerified: true,
  accountStatus: 'approved',
  isBlocked: false,
};

describe('mobile refresh tokens', () => {
  let repo;
  let users;
  let clock;
  let service;

  beforeEach(() => {
    repo = createFakeRepo();
    users = new Map([[activeUser.id, { ...activeUser }]]);
    clock = new Date('2026-10-05T10:00:00Z');
    service = createMobileSessionService({
      tokenRepo: repo,
      findUserById: async (id) => users.get(id) ?? null,
      now: () => clock,
    });
  });

  test('login stores only a hash and expires in 30 days', async () => {
    const token = await service.issueForLogin('user-1', { deviceName: 'Pixel 8' });

    assert.equal(repo.rows.length, 1);
    const row = repo.rows[0];
    assert.notEqual(row.tokenHash, token, 'raw token must never be stored');
    assert.equal(row.tokenHash, hashRefreshToken(token));
    assert.equal(row.deviceName, 'Pixel 8');
    assert.equal(new Date(row.expiresAt).getTime(), clock.getTime() + REFRESH_TOKEN_TTL_MS);
    assert.ok(token.length >= 64);
  });

  test('refresh rotates: old token revoked, new one in the same family', async () => {
    const first = await service.issueForLogin('user-1');
    const { user, refreshToken: second } = await service.rotate(first);

    assert.equal(user.id, 'user-1');
    assert.notEqual(second, first);
    assert.equal(repo.rows.length, 2);
    assert.equal(repo.rows[0].revokedReason, 'rotated');
    assert.equal(repo.rows[1].revokedAt, null);
    assert.equal(repo.rows[1].familyId, repo.rows[0].familyId);
  });

  test('reusing a rotated token revokes the whole family', async () => {
    const first = await service.issueForLogin('user-1');
    const { refreshToken: second } = await service.rotate(first);

    await assert.rejects(service.rotate(first), (err) => err instanceof RefreshTokenError && err.code === 'REUSED');
    // The legitimate newer token is cut off too.
    await assert.rejects(service.rotate(second), (err) => err.code === 'REUSED');
    assert.ok(repo.rows.every((row) => row.revokedAt));
  });

  test('unknown token is rejected', async () => {
    await assert.rejects(service.rotate('x'.repeat(64)), (err) => err.code === 'INVALID');
  });

  test('expired token is rejected and revoked', async () => {
    const token = await service.issueForLogin('user-1');
    clock = new Date(clock.getTime() + REFRESH_TOKEN_TTL_MS + 1000);

    await assert.rejects(service.rotate(token), (err) => err.code === 'EXPIRED');
    assert.ok(repo.rows[0].revokedAt);
  });

  test('blocked, unverified or deleted accounts cannot refresh', async () => {
    const cases = [
      { isBlocked: true, blockedUntil: null },
      { isBlocked: true, blockedUntil: '2026-12-01T00:00:00Z' },
      { isEmailVerified: false },
      { accountStatus: 'pending' },
    ];
    for (const change of cases) {
      users.set('user-1', { ...activeUser, ...change });
      const token = await service.issueForLogin('user-1');
      await assert.rejects(service.rotate(token), (err) => err.code === 'ACCOUNT_UNAVAILABLE', JSON.stringify(change));
    }

    users.delete('user-1');
    const orphan = await service.issueForLogin('user-1');
    await assert.rejects(service.rotate(orphan), (err) => err.code === 'ACCOUNT_UNAVAILABLE');
  });

  test('an expired timed block no longer stops refresh', async () => {
    users.set('user-1', { ...activeUser, isBlocked: true, blockedUntil: '2026-10-01T00:00:00Z' });
    const token = await service.issueForLogin('user-1');
    const { refreshToken } = await service.rotate(token);
    assert.ok(refreshToken);
  });

  test('logout revokes the sign-in; unknown tokens are ignored', async () => {
    const token = await service.issueForLogin('user-1');
    const { refreshToken } = await service.rotate(token);

    assert.equal(await service.revoke(refreshToken), true);
    await assert.rejects(service.rotate(refreshToken), (err) => err.code === 'REUSED');
    assert.equal(await service.revoke('y'.repeat(64)), false);
  });

  test('signing in on two phones keeps the sessions separate', async () => {
    const phoneA = await service.issueForLogin('user-1', { deviceName: 'A' });
    const phoneB = await service.issueForLogin('user-1', { deviceName: 'B' });

    await service.revoke(phoneA);
    const { refreshToken } = await service.rotate(phoneB);
    assert.ok(refreshToken, 'logging out phone A must not log out phone B');
  });
});
