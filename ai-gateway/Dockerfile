# syntax=docker/dockerfile:1
FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npm run typecheck && npm test && npm run build && npm prune --omit=dev

FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production AI_PROVIDER=none AI_GATEWAY_PORT=8787
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
USER node
EXPOSE 8787
HEALTHCHECK --interval=15s --timeout=5s --retries=5 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.AI_GATEWAY_PORT||8787)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "dist/server.js"]
