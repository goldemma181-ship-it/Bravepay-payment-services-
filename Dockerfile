FROM node:22-alpine

ENV NODE_ENV=production
WORKDIR /app

# curl is needed for the container HEALTHCHECK (not included in alpine images)
RUN apk add --no-cache curl

# Install exact dependency versions from the lockfile first (better layer caching)
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY server.js ./
COPY public ./public

# Writable data directory for orders.json / admin-security.json / security.log
RUN mkdir -p /data && chown -R node:node /data
ENV DATA_DIR=/data

# Run as the unprivileged node user
USER node

EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=4s --start-period=5s --retries=3 \
  CMD curl -fsS http://127.0.0.1:3000/api/health || exit 1

CMD ["node", "server.js"]
