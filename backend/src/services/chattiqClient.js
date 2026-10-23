/** Calls to the Chattiq API that this service makes itself (not plain forwarding). */

const LOGIN_TIMEOUT_MS = 15_000;

function createChattiqClient({ chattiqApiUrl, fetchImpl = fetch }) {
  /**
   * Checks the email/password with the Chattiq API (its own rules: verified,
   * approved, not blocked) and returns its response unchanged. forwardedFor is
   * the X-Forwarded-For header of the app's request, passed on so the Chattiq
   * API rate-limits each phone by its own address.
   * @returns {Promise<{ status: number, body: any }>}
   */
  async function login({ email, password, forwardedFor }) {
    const headers = { 'Content-Type': 'application/json', Accept: 'application/json' };
    if (forwardedFor) headers['X-Forwarded-For'] = forwardedFor;
    const response = await fetchImpl(`${chattiqApiUrl}/auth/login`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ email, password }),
      signal: AbortSignal.timeout(LOGIN_TIMEOUT_MS),
    });
    const text = await response.text();
    let body = null;
    try {
      body = text ? JSON.parse(text) : null;
    } catch {
      body = { success: false, message: 'Unexpected response from the Chattiq API' };
    }
    return { status: response.status, body };
  }

  return { login };
}

module.exports = { createChattiqClient };
