import { GatewayError } from './errors.js';
import type { InterpretRequest } from './providers/types.js';

// Only generated identifiers leave the gateway, never input labels/raw rows/IDs.
export function placeholders(req: InterpretRequest): Map<string, string> {
  const values = new Map<string, string>();
  const part = /^[a-zA-Z_][a-zA-Z0-9_]*$/;
  for (const table of req.tables) {
    if (!/^T\d+$/.test(table.id)) throw new GatewayError('invalid_table', 'Tablo kimliği geçersiz.', 422);
    table.rows_fmt[req.language].forEach((row, index) => {
      const key = typeof row.key === 'string' && part.test(row.key) ? row.key : `row_${index + 1}`;
      for (const [column, value] of Object.entries(row)) {
        if (['key', 'label', 'item', 'group', 'name', 'parameter', 'factor'].includes(column) || !part.test(column)) continue;
        if (!/^[\s\p{N}.,+−–\-<>≤≥%[\];:()/eE—]+$/u.test(value)) continue;
        const id = `${req.module}.${table.id}.${key}.${column}`;
        if (values.has(id)) throw new GatewayError('duplicate_key', 'Yer tutucu anahtarı yineleniyor.', 422);
        values.set(id, value);
        if (column === 'value') values.set(`${req.module}.${table.id}.${key}`, value);
      }
    });
  }
  if (!values.size || values.size > 2000) throw new GatewayError('placeholder_limit', 'Yorumlanabilir tablo hücresi yok veya sınır aşıldı.', 422);
  return values;
}
