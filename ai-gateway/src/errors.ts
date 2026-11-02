// Hata biçimi R motoruyla aynıdır (SPEC §8).
export interface ErrorBody {
  error: { code: string; message_tr: string; detail: string | null };
}

export class GatewayError extends Error {
  readonly code: string;
  readonly statusCode: number;
  readonly detail: string | null;

  constructor(code: string, messageTr: string, statusCode: number, detail: string | null = null) {
    super(messageTr);
    this.name = 'GatewayError';
    this.code = code;
    this.statusCode = statusCode;
    this.detail = detail;
  }

  toBody(): ErrorBody {
    return { error: { code: this.code, message_tr: this.message, detail: this.detail } };
  }
}
