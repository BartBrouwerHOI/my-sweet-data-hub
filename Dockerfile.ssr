# === Lovable Frontend Build ===
# Multi-stage build: Node.js build → Node.js server (TanStack Start SSR)

# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

# Install bun for faster installs
RUN npm install -g bun

# Copy package files
COPY package.json bun.lockb* ./

# Install dependencies
RUN bun install --frozen-lockfile || npm install

# Copy source
COPY . .

# Build the app (TanStack Start outputs to .output/)
RUN npm run build

# Stage 2: Run with Node.js
FROM node:20-alpine

WORKDIR /app

# Copy built output and node_modules
COPY --from=builder /app/.output ./.output
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

EXPOSE 3000

ENV HOST=0.0.0.0
ENV PORT=3000

CMD ["node", ".output/server/index.mjs"]
