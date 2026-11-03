export const config = {
  aiEnabled: Boolean(import.meta.env.VITE_AI_GATEWAY_URL?.trim()),
  engineUrl: import.meta.env.VITE_ENGINE_URL ?? 'http://localhost:8000',
  gatewayUrl: import.meta.env.VITE_AI_GATEWAY_URL ?? 'http://localhost:8787',
  deployMode: (import.meta.env.VITE_DEPLOY_MODE ?? 'local') as 'local' | 'online',
};
