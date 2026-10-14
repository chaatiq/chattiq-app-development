require('dotenv').config();

function required(name) {
  const value = String(process.env[name] || '').trim();
  if (!value) throw new Error(`${name} is not set (see .env.example)`);
  return value;
}

function stripTrailingSlash(url) {
  return url.replace(/\/+$/, '');
}

/** Read once at startup; a missing value stops the server with a clear message. */
function loadConfig() {
  return {
    port: Number(process.env.PORT || 5002),
    jwtSecret: required('JWT_SECRET'),
    chattiqApiUrl: stripTrailingSlash(required('CHATTIQ_API_URL')),
    notifyApiKey: String(process.env.NOTIFY_API_KEY || '').trim(),
  };
}

module.exports = { loadConfig };
