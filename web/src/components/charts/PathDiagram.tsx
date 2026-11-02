import { useTranslation } from 'react-i18next';
import type { PathData } from '../../api/types';
import { useTheme } from '../../theme/ThemeContext';
import { palettes } from '../../theme/tokens';
import { useLang } from '../../useLang';

// DFA yol şeması (SPEC §7 M6). Yalnızca yerleşim burada hesaplanır; bütün etiketler R'nin
// biçimlediği metinlerdir (standardize yükler, faktör korelasyonları, hata kovaryansları, R²).

const ROW = 34;
const TOP = 24;

export interface PathLayout {
  width: number;
  height: number;
  items: Record<string, { x: number; y: number }>;
  factors: Record<string, { x: number; y: number }>;
}

export function layoutPath(data: PathData): PathLayout {
  const items: PathLayout['items'] = {};
  const factors: PathLayout['factors'] = {};
  let row = 0;
  const seen = new Set<string>();
  for (const f of data.factors) {
    const ys: number[] = [];
    for (const it of f.items) {
      if (!seen.has(it)) { items[it] = { x: 460, y: TOP + row * ROW + ROW / 2 }; seen.add(it); row += 1; }
      ys.push(items[it].y);
    }
    row += 0.5;
    factors[f.name] = { x: 190, y: ys.length ? (Math.min(...ys) + Math.max(...ys)) / 2 : TOP };
  }
  return { width: 640, height: Math.max(120, TOP * 2 + row * ROW), items, factors };
}

export function PathDiagram({ data }: { data: PathData }) {
  const { t } = useTranslation();
  const lang = useLang();
  const { theme } = useTheme();
  const c = palettes[theme];
  const L = layoutPath(data);
  const lab = (o: { label_tr: string; label_en: string }) => (lang === 'tr' ? o.label_tr : o.label_en);
  const rx = 62; const ry = 20; const bw = 64; const bh = 24;
  return (
    <figure className="chart-figure">
      <figcaption className="rtable-title">{t('cfa.pathTitle')}</figcaption>
      <svg className="path-diagram" role="img" aria-label={t('cfa.pathAria')} viewBox={`0 0 ${L.width} ${L.height}`}
           width="100%" style={{ maxWidth: L.width, background: c.bg }} data-testid="path-diagram">
        <defs>
          <marker id="arrow" viewBox="0 0 10 10" refX="10" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
            <path d="M0,0 L10,5 L0,10 z" fill={c.textMuted} />
          </marker>
        </defs>
        {data.correlations.map((r) => {
          const a = L.factors[r.a]; const b = L.factors[r.b];
          if (!a || !b) return null;
          const bend = 40 + Math.abs(a.y - b.y) * 0.25;
          const mx = Math.min(a.x, b.x) - rx - bend; const my = (a.y + b.y) / 2;
          return (
            <g key={`r-${r.a}-${r.b}`} data-kind="correlation">
              <path d={`M${a.x - rx},${a.y} Q${mx},${my} ${b.x - rx},${b.y}`} fill="none" stroke={c.accent2} strokeWidth={1.2}
                    markerStart="url(#arrow)" markerEnd="url(#arrow)" />
              <text x={mx + 22} y={my + 4} fontSize={11} fill={c.accent2} textAnchor="middle">{lab(r)}</text>
            </g>
          );
        })}
        {data.loadings.map((l) => {
          const f = L.factors[l.factor]; const it = L.items[l.item];
          if (!f || !it) return null;
          const x1 = f.x + rx; const x2 = it.x - bw / 2;
          const lx = x1 + (x2 - x1) * 0.55; const ly = f.y + (it.y - f.y) * 0.55;
          return (
            <g key={`l-${l.factor}-${l.item}`} data-kind="loading">
              <line x1={x1} y1={f.y} x2={x2} y2={it.y} stroke={c.textMuted} strokeWidth={1} markerEnd="url(#arrow)" />
              <text x={lx} y={ly - 3} fontSize={11} fill={c.text} textAnchor="middle" data-testid={`load-${l.factor}-${l.item}`}>{lab(l)}</text>
            </g>
          );
        })}
        {data.covariances.map((cv) => {
          const a = L.items[cv.a]; const b = L.items[cv.b];
          if (!a || !b) return null;
          const mx = a.x + bw / 2 + 40 + Math.abs(a.y - b.y) * 0.2; const my = (a.y + b.y) / 2;
          return (
            <g key={`c-${cv.a}-${cv.b}`} data-kind="covariance">
              <path d={`M${a.x + bw / 2},${a.y} Q${mx},${my} ${b.x + bw / 2},${b.y}`} fill="none" stroke={c.accent} strokeDasharray="4 3"
                    markerStart="url(#arrow)" markerEnd="url(#arrow)" />
              <text x={mx - 6} y={my + 4} fontSize={11} fill={c.accent}>{lab(cv)}</text>
            </g>
          );
        })}
        {Object.entries(L.factors).map(([name, p]) => (
          <g key={`f-${name}`}>
            <ellipse cx={p.x} cy={p.y} rx={rx} ry={ry} fill={c.surfaceRaised} stroke={c.accent} strokeWidth={1.5} />
            <text x={p.x} y={p.y + 4} fontSize={12} fontWeight={600} fill={c.text} textAnchor="middle">{name}</text>
          </g>
        ))}
        {data.loadings.map((l) => {
          const it = L.items[l.item];
          return it ? (
            <g key={`i-${l.factor}-${l.item}`}>
              <rect x={it.x - bw / 2} y={it.y - bh / 2} width={bw} height={bh} fill={c.surface} stroke={c.border} />
              <text x={it.x} y={it.y + 4} fontSize={12} fill={c.text} textAnchor="middle">{l.item}</text>
              <text x={it.x + bw / 2 + 8} y={it.y + 4} fontSize={10} fill={c.textMuted}>R² {lang === 'tr' ? l.r2_label_tr : l.r2_label_en}</text>
            </g>
          ) : null;
        })}
      </svg>
      <p className="table-note">{t('cfa.pathNote')}</p>
    </figure>
  );
}
