/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_ENGINE_URL?: string;
  readonly VITE_AI_GATEWAY_URL?: string;
  readonly VITE_DEPLOY_MODE?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
