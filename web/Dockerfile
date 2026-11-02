# syntax=docker/dockerfile:1
FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
ARG VITE_ENGINE_URL=http://localhost:8000
ARG VITE_AI_GATEWAY_URL=http://localhost:8787
ARG VITE_DEPLOY_MODE=local
ENV VITE_ENGINE_URL=$VITE_ENGINE_URL VITE_AI_GATEWAY_URL=$VITE_AI_GATEWAY_URL VITE_DEPLOY_MODE=$VITE_DEPLOY_MODE
RUN npm run typecheck && npm test && npm run build

FROM nginx:stable-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 5173
HEALTHCHECK --interval=15s --timeout=5s --retries=5 CMD wget -qO- http://127.0.0.1:5173/ >/dev/null || exit 1
