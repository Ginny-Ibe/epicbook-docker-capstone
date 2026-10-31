# ---------- Stage 1: dependencies ----------
FROM node:20-alpine AS deps
WORKDIR /app
# Copy only the package files first, so this layer is cached
# and npm ci re-runs only when dependencies change
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ---------- Stage 2: minimal runtime ----------
FROM node:20-alpine AS runtime
ENV NODE_ENV=production \
    PORT=8080
WORKDIR /app
COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node . .
# Run as the built-in non-root "node" user
USER node
EXPOSE 8080
CMD ["node", "server.js"]
