import { describe, expect, it, vi } from 'vitest';
import { screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { contrastRatio } from '../src/theme/contrast';
import { contrastPairs, palettes, type ThemeName } from '../src/theme/tokens';
import { applyTheme, initialTheme } from '../src/theme/ThemeContext';
import { renderApp, jsonResponse } from './renderApp';

describe('ARES-1 renkleri', () => {
  it('koyu tema şartnamedeki renkleri aynen kullanır (SPEC §4)', () => {
    expect(palettes.dark.bg).toBe('#070B10');
    expect(palettes.dark.accent).toBe('#00E5FF');
    expect(palettes.dark.accent2).toBe('#FFB300');
  });

  it('kontrast formülü bilinen değerleri verir', () => {
    expect(contrastRatio('#000000', '#FFFFFF')).toBeCloseTo(21, 6);
    expect(contrastRatio('#FFFFFF', '#FFFFFF')).toBeCloseTo(1, 6);
  });

  for (const theme of ['dark', 'light'] as ThemeName[]) {
    for (const [fg, bg, label] of contrastPairs) {
      it(`${theme}: ${label} ≥ 4.5:1`, () => {
        const r = contrastRatio(palettes[theme][fg], palettes[theme][bg]);
        expect(r).toBeGreaterThanOrEqual(4.5);
      });
    }
  }

  it('şartnamedeki vurgular beyaz zeminde 4.5:1 sağlamaz; bu yüzden açık temada kullanılmaz', () => {
    expect(contrastRatio('#00E5FF', '#FFFFFF')).toBeLessThan(4.5);
    expect(contrastRatio('#FFB300', '#FFFFFF')).toBeLessThan(4.5);
    expect(palettes.light.accent).not.toBe('#00E5FF');
    expect(palettes.light.accent2).not.toBe('#FFB300');
  });
});

describe('tema uygulama', () => {
  it('applyTheme CSS değişkenlerini ve data-theme özniteliğini ayarlar', () => {
    const el = document.createElement('div');
    applyTheme('light', el);
    expect(el.dataset.theme).toBe('light');
    expect(el.style.getPropertyValue('--color-accent')).toBe(palettes.light.accent);
  });

  it('localStorage hata fırlatsa bile tema seçilebilir', () => {
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new Error('engelli');
    });
    expect(['dark', 'light']).toContain(initialTheme());
  });

  it('tema düğmesi temayı değiştirir ve tercihi saklar', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => jsonResponse({ error: { code: 'x', message_tr: 'y' } }, 503)));
    await renderApp('/settings', { theme: 'dark' });
    const btn = screen.getAllByRole('button', { name: 'Temayı değiştir' })[0];
    await userEvent.click(btn);
    expect(document.documentElement.dataset.theme).toBe('light');
    expect(window.localStorage.getItem('olceklab.theme')).toBe('light');
  });
});
