# === Lovable Frontend Build ===
# Multi-stage build: Node.js build → Nginx static serving

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

# Build the app
RUN npm run build

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy built assets
COPY --from=builder /app/.output/public /usr/share/nginx/html

# Copy nginx config for SPA routing
COPY nginx/frontend.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
