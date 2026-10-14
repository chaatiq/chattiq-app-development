const { loadConfig } = require('./config');
const { createApp } = require('./app');
const userRepo = require('./repositories/userRepo');
const deviceRepo = require('./repositories/deviceRepo');
const refreshTokenRepo = require('./repositories/refreshTokenRepo');
const { createMobileSessionService } = require('./services/mobileSession');
const { getPushService } = require('./services/pushService');
const { createChattiqClient } = require('./services/chattiqClient');

const config = loadConfig();

if (!config.notifyApiKey) {
  console.warn('NOTIFY_API_KEY is not set: message notifications from the AI runtime are disabled.');
}

const app = createApp({
  config,
  userRepo,
  deviceRepo,
  mobileSessions: createMobileSessionService({ tokenRepo: refreshTokenRepo, findUserById: userRepo.findById }),
  pushService: getPushService(),
  chattiqClient: createChattiqClient({ chattiqApiUrl: config.chattiqApiUrl }),
});

app.listen(config.port, () => {
  console.log(`mobile backend on port ${config.port}, forwarding other requests to ${config.chattiqApiUrl}`);
});
