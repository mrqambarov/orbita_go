# ─── Stage 1: Build ───────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Dependencies oldin nusxalanadi (cache uchun)
COPY package*.json ./
RUN npm ci --only=production && npm ci

COPY tsconfig.json ./
COPY src ./src
COPY prisma ./prisma

# Prisma client generate
RUN npx prisma generate

# TypeScript compile
RUN npm run build

# ─── Stage 2: Production ──────────────────────────────
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

# Faqat production dependencies
COPY package*.json ./
RUN npm ci --only=production

# Build natijasi va prisma
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY prisma ./prisma

EXPOSE 3001

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3001/api/health || exit 1

CMD ["node", "dist/index.js"]
