import type { ReactNode } from 'react';

// Basit form alanları. Sayı alanları metin olarak tutulur: geçersiz metin R'ye olduğu gibi gider ve
// R motoru 422 ile reddeder; ön yüz sessizce varsayılana dönmez (Faz 1 dersleri).

export function toNum(v: string): number {
  return v.trim() !== '' && Number.isFinite(Number(v)) ? Number(v) : (v as unknown as number);
}

export function SelectField<T extends string>({ label, value, options, onChange, disabled, optionLabel, optionDisabled, name }: {
  label: string; value: T; options: readonly T[]; onChange: (v: T) => void; disabled?: boolean;
  optionLabel: (v: T) => string; optionDisabled?: (v: T) => boolean; name?: string;
}) {
  return (
    <label className="field">
      <span>{label}</span>
      <select name={name} value={value} disabled={disabled} onChange={(e) => onChange(e.target.value as T)}>
        {options.map((o) => <option key={o} value={o} disabled={optionDisabled?.(o)}>{optionLabel(o)}</option>)}
      </select>
    </label>
  );
}

export function NumField({ label, value, onChange, step, min, max, disabled }: {
  label: string; value: string; onChange: (v: string) => void; step?: number; min?: number; max?: number; disabled?: boolean;
}) {
  return (
    <label className="field">
      <span>{label}</span>
      <input className="num-input" type="number" step={step} min={min} max={max} value={value} disabled={disabled}
             onChange={(e) => onChange(e.target.value)} />
    </label>
  );
}

export function CheckField({ label, checked, onChange, disabled, hint }: {
  label: string; checked: boolean; onChange: (v: boolean) => void; disabled?: boolean; hint?: ReactNode;
}) {
  return (
    <div className="field check-field">
      <label className="rule">
        <input type="checkbox" checked={checked} disabled={disabled} onChange={(e) => onChange(e.target.checked)} />
        <span>{label}</span>
      </label>
      {hint && <span className="muted small">{hint}</span>}
    </div>
  );
}
