// R motoru ve ağ geçidi için ince bir HTTP istemcisi. Hiçbir istatistik hesaplamaz;
// yanıtı olduğu gibi döndürür ve standart hata biçimini (SPEC §8) çözümler.

export interface ApiErrorBody {
  error: { code: string; message_tr: string; detail?: string | null };
}

export class ApiError extends Error {
  readonly code: string;
  readonly status: number | null;
  readonly detail: string | null;

  constructor(code: string, message: string, status: number | null = null, detail: string | null = null) {
    super(message);
    this.name = 'ApiError';
    this.code = code;
    this.status = status;
    this.detail = detail;
  }
}

export function isApiErrorBody(x: unknown): x is ApiErrorBody {
  if (typeof x !== 'object' || x === null || !('error' in x)) return false;
  const e = (x as { error: unknown }).error;
  return (
    typeof e === 'object' &&
    e !== null &&
    typeof (e as { code?: unknown }).code === 'string' &&
    typeof (e as { message_tr?: unknown }).message_tr === 'string'
  );
}

interface RequestOptions {
  method?: 'GET' | 'POST';
  json?: unknown;
  raw?: Blob | ArrayBuffer;
  query?: Record<string, string>;
  signal?: AbortSignal;
}

export async function request<T>(baseUrl: string, path: string, opts: RequestOptions = {}): Promise<T> {
  const url = new URL(`${baseUrl.replace(/\/$/, '')}${path}`);
  for (const [k, v] of Object.entries(opts.query ?? {})) url.searchParams.set(k, v);
  const headers: Record<string, string> = { Accept: 'application/json' };
  let body: BodyInit | undefined;
  if (opts.json !== undefined) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(opts.json);
  } else if (opts.raw !== undefined) {
    headers['Content-Type'] = 'application/octet-stream';
    body = opts.raw;
  }

  let res: Response;
  try {
    res = await fetch(url.toString(), { method: opts.method ?? 'GET', headers, body, signal: opts.signal });
  } catch (e) {
    if (e instanceof DOMException && e.name === 'AbortError') throw e;
    throw new ApiError('network_error', 'Sunucuya ulaşılamadı.', null, e instanceof Error ? e.message : String(e));
  }

  const text = await res.text();
  let parsed: unknown = null;
  if (text) {
    try {
      parsed = JSON.parse(text);
    } catch {
      throw new ApiError('invalid_json', 'Sunucudan geçersiz yanıt geldi.', res.status, text.slice(0, 200));
    }
  }

  if (!res.ok) {
    if (isApiErrorBody(parsed)) {
      throw new ApiError(parsed.error.code, parsed.error.message_tr, res.status, parsed.error.detail ?? null);
    }
    throw new ApiError(`http_${res.status}`, `Sunucu ${res.status} durum koduyla yanıt verdi.`, res.status);
  }
  return parsed as T;
}

export function getJson<T>(baseUrl: string, path: string, signal?: AbortSignal): Promise<T> {
  return request<T>(baseUrl, path, { signal });
}
