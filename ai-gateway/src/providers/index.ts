import type { GatewayConfig } from '../config.js';
import type { AiProvider } from './types.js';
import { noneProvider } from './none.js';
import { createLocalProvider } from './local.js';
import { createEvrenProvider } from './evren.js';

export function createProvider(config: GatewayConfig): AiProvider {
  switch (config.provider) {
    case 'none':
      return noneProvider;
    case 'local':
      return createLocalProvider(config);
    case 'evren':
      return createEvrenProvider(config);
  }
}
