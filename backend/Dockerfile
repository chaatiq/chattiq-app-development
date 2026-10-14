FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=5002

COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src

# The official image ships a non-root "node" user.
USER node
EXPOSE 5002

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- http://127.0.0.1:5002/health || exit 1

# Apply new migrations (each file runs once), then start the API.
CMD ["sh", "-c", "node src/db/migrate.js && exec node src/server.js"]
