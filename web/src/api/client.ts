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

export async function getJson<T>(baseUrl: string, path: string, signal?: AbortSignal): Promise<T> {
  let res: Response;
  try {
    res = await fetch(`${baseUrl.replace(/\/$/, '')}${path}`, {
      signal,
      headers: { Accept: 'application/json' },
    });
  } catch (e) {
    if (e instanceof DOMException && e.name === 'AbortError') throw e;
    throw new ApiError('network_error', 'Sunucuya ulaşılamadı.', null, e instanceof Error ? e.message : String(e));
  }

  const text = await res.text();
  let body: unknown = null;
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      throw new ApiError('invalid_json', 'Sunucudan geçersiz yanıt geldi.', res.status, text.slice(0, 200));
    }
  }

  if (!res.ok) {
    if (isApiErrorBody(body)) {
      throw new ApiError(body.error.code, body.error.message_tr, res.status, body.error.detail ?? null);
    }
    throw new ApiError(`http_${res.status}`, `Sunucu ${res.status} durum koduyla yanıt verdi.`, res.status);
  }
  return body as T;
}
