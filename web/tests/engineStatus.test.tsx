import { describe, expect, it, vi } from 'vitest';
import { screen, within } from '@testing-library/react';
import { renderApp, jsonResponse } from './renderApp';
import { ApiError, getJson } from '../src/api/client';

// Bu testler motor yanıtını taklit eder; arayüzün gösterdiği her değerin
// yanıttan geldiğini (uydurulmadığını) denetler.
const versions = {
  R: 'R-TEST-1',
  packages: { lavaan: 'lavaan-TEST', psych: 'psych-TEST' },
  missing: [],
  platform: 'test-platform',
  blas: null,
  lapack: null,
  rng_kind: { kind: 'Mersenne-Twister', normal_kind: 'Inversion', sample_kind: 'Rejection' },
};

describe('motor durumu kartı', () => {
  it('yalnızca /versions yanıtındaki değerleri gösterir', async () => {
    const fetchMock = vi.fn(async () => jsonResponse(versions));
    vi.stubGlobal('fetch', fetchMock);
    await renderApp('/');
    expect(await screen.findByTestId('r-version')).toHaveTextContent('R-TEST-1');
    const table = screen.getByRole('table');
    expect(within(table).getByText('lavaan-TEST')).toBeInTheDocument();
    expect(within(table).getByText('psych-TEST')).toBeInTheDocument();
    expect(within(table).getAllByRole('row')).toHaveLength(3);
    expect(fetchMock).toHaveBeenCalledWith('http://localhost:8000/versions', expect.anything());
  });

  it('motor hata verirse hata kodunu gösterir, hiçbir sürüm ya da tablo göstermez', async () => {
    vi.stubGlobal('fetch', vi.fn(async () =>
      jsonResponse({ error: { code: 'engine_error', message_tr: 'R motorunda hata', detail: 'x' } }, 500)));
    await renderApp('/');
    expect(await screen.findByRole('alert')).toHaveTextContent('R motorunda hata');
    expect(screen.getByText(/engine_error/)).toBeInTheDocument();
    expect(screen.queryByTestId('r-version')).not.toBeInTheDocument();
    expect(screen.queryByRole('table')).not.toBeInTheDocument();
  });

  it('ağ hatası network_error olarak gösterilir', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => { throw new TypeError('Failed to fetch'); }));
    await renderApp('/');
    expect(await screen.findByText(/network_error/)).toBeInTheDocument();
  });

  it('eksik paket varsa uyarı gösterilir', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => jsonResponse({ ...versions, missing: ['semTools'] })));
    await renderApp('/');
    const alerts = await screen.findAllByRole('alert');
    expect(alerts.some((a) => a.textContent?.includes('semTools'))).toBe(true);
  });
});

describe('HTTP istemcisi', () => {
  it('standart hata biçimini (SPEC §8) ApiError olarak çözer', async () => {
    vi.stubGlobal('fetch', vi.fn(async () =>
      jsonResponse({ error: { code: 'not_implemented', message_tr: 'Henüz yok', detail: 'POST /analyses/efa' } }, 501)));
    const err = (await getJson('http://e', '/analyses/efa').catch((e: unknown) => e)) as ApiError;
    expect(err).toBeInstanceOf(ApiError);
    expect(err.code).toBe('not_implemented');
    expect(err.status).toBe(501);
    expect(err.detail).toBe('POST /analyses/efa');
  });

  it('JSON olmayan yanıtı invalid_json olarak bildirir', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('<html>', { status: 200 })));
    const err = (await getJson('http://e', '/x').catch((e: unknown) => e)) as ApiError;
    expect(err.code).toBe('invalid_json');
  });

  it('sayıları değiştirmeden döndürür', async () => {
    const body = { a: 0.10000000000000001, b: 281.16800000000001, c: 3.1415926535897931 };
    vi.stubGlobal('fetch', vi.fn(async () => new Response(
      '{"a":0.10000000000000001,"b":281.16800000000001,"c":3.1415926535897931}', { status: 200 })));
    const out = await getJson<typeof body>('http://e', '/x');
    expect(out.a).toBe(0.1);
    expect(out.b).toBe(281.168);
    expect(out.c).toBe(Math.PI);
  });
});
