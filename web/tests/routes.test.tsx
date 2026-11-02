import { describe, expect, it, vi, beforeEach } from 'vitest';
import { screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import tr from '../src/i18n/locales/tr.json';
import en from '../src/i18n/locales/en.json';
import { pages } from '../src/routes';
import { renderApp, jsonResponse } from './renderApp';

beforeEach(() => {
  // Ağa çıkılmaz: motor yanıtı her testte açıkça taklit edilir.
  vi.stubGlobal('fetch', vi.fn(async () => jsonResponse({ error: { code: 'not_running', message_tr: 'test' } }, 503)));
});

describe('SPEC §9 rotaları', () => {
  it('11 sayfa tanımlı ve yollar benzersiz', () => {
    expect(pages).toHaveLength(11);
    expect(new Set(pages.map((p) => p.path)).size).toBe(11);
  });

  for (const p of pages) {
    it(`${p.path} sayfası Türkçe başlığıyla açılır`, async () => {
      await renderApp(p.path);
      const title = (tr.pages as Record<string, { title: string }>)[p.key].title;
      expect(await screen.findByRole('heading', { level: 1, name: title })).toBeInTheDocument();
    });
  }

  it('henüz uygulanmamış sayfa analiz sonucu göstermez, faz bilgisini gösterir', async () => {
    await renderApp('/invariance');
    expect(screen.getByText(/Faz 3 kapsamında etkinleşecek/)).toBeInTheDocument();
    expect(screen.queryByRole('table')).not.toBeInTheDocument();
  });

  it('simülasyon sayfası kalıcı SİMÜLASYON etiketini taşır (SPEC 9.9)', async () => {
    await renderApp('/simulation');
    expect(screen.getByRole('note')).toHaveTextContent(tr.simulation.banner);
  });

  it('bilinmeyen yol "Sayfa bulunamadı" gösterir', async () => {
    await renderApp('/boyle-bir-sayfa-yok');
    expect(screen.getByRole('heading', { level: 1, name: tr.pages.notFound.title })).toBeInTheDocument();
  });

  it('dil düğmesi arayüzü İngilizceye çevirir', async () => {
    await renderApp('/factor-number');
    await userEvent.click(screen.getAllByRole('button', { name: 'EN' })[0]);
    expect(await screen.findByRole('heading', { level: 1, name: en.pages.factorNumber.title })).toBeInTheDocument();
    expect(document.documentElement.lang).toBe('en');
    await userEvent.click(screen.getAllByRole('button', { name: 'TR' })[0]);
  });

  it('gezinme bağlantıları her sayfaya gider', async () => {
    await renderApp('/');
    await userEvent.click(screen.getByRole('link', { name: /Değişmezlik/ }));
    expect(await screen.findByRole('heading', { level: 1, name: tr.pages.invariance.title })).toBeInTheDocument();
  });
});
