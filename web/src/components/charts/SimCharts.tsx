import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import type { EChartsCoreOption } from 'echarts/core';
import type { BiasHeatmapData, Lang, PowerCurveData } from '../../api/types';
import { useTheme } from '../../theme/ThemeContext';
import { palettes, type Palette } from '../../theme/tokens';
import { useLang } from '../../useLang';
import { EChart } from './EChart';

// Simülasyon grafikleri. Değerler ve etiketler R'den gelir; burada yalnızca çizim seçenekleri kurulur.
// Çok seri olduğunda nokta etiketleri üst üste biner; o zaman etiketler ipucunda ve T4 tablosundadır.

const seriesColors = (c: Palette) => [c.accent, c.accent2, c.success, c.danger, c.textMuted, c.text];

export function buildPowerOption(d: PowerCurveData, lang: Lang, c: Palette, xName: string, yName: string): EChartsCoreOption {
  return {
    animation: false,
    textStyle: { fontFamily: 'JetBrains Mono, monospace', color: c.text },
    grid: { left: 56, right: 24, top: 72, bottom: 48 },
    legend: { type: 'scroll', top: 0, textStyle: { color: c.text } },
    tooltip: { trigger: 'item', formatter: (p: { seriesIndex: number; dataIndex: number; seriesName: string }) => {
      const s = d.series[p.seriesIndex]; return `${p.seriesName}<br/>N = ${s.N[p.dataIndex]}: ${(lang === 'tr' ? s.labels_tr : s.labels_en)[p.dataIndex]}`;
    } },
    xAxis: { type: 'category', data: d.Ns.map(String), name: xName, nameLocation: 'middle', nameGap: 28, axisLabel: { color: c.textMuted }, axisLine: { lineStyle: { color: c.border } } },
    yAxis: { type: 'value', min: 0, max: 1, interval: 0.2, name: yName, nameGap: 14, nameTextStyle: { color: c.textMuted, align: 'left' }, splitLine: { lineStyle: { color: c.border } },
      axisLabel: { color: c.textMuted, formatter: (v: number) => (lang === 'tr' ? d.y_labels_tr : d.y_labels_en)[d.y_ticks.findIndex((x) => Math.abs(x - v) < 1e-9)] ?? '' } },
    color: seriesColors(c),
    labelLayout: { hideOverlap: true },
    series: d.series.map((s, k) => ({ name: lang === 'tr' ? s.name_tr : s.name_en, type: 'line', labelLayout: { hideOverlap: true }, data: d.Ns.map((n) => { const i = s.N.indexOf(n); return i >= 0 ? s.rate[i] : null; }),
      ...(k === 0 ? { markLine: { silent: true, symbol: 'none', lineStyle: { color: c.textMuted, type: 'dashed' },
        data: [{ yAxis: d.target, label: { position: 'insideEndTop', formatter: lang === 'tr' ? d.target_label_tr : d.target_label_en, color: c.textMuted } }] } } : {}),
      label: { show: d.series.length <= 2, color: c.text, fontSize: 10, formatter: (p: { dataIndex: number }) => (lang === 'tr' ? s.labels_tr : s.labels_en)[p.dataIndex] ?? '' } })),
  };
}

export function buildBiasOption(d: BiasHeatmapData, lang: Lang, c: Palette): EChartsCoreOption {
  const cells: [number, number, number | null][] = [];
  d.params.forEach((_, i) => d.conditions.forEach((_c, j) => cells.push([j, i, d.values[i]?.[j] ?? null])));
  const labels = lang === 'tr' ? d.labels_tr : d.labels_en;
  return {
    animation: false,
    textStyle: { fontFamily: 'JetBrains Mono, monospace', color: c.text },
    grid: { left: 90, right: 16, top: 16, bottom: 90 },
    tooltip: { formatter: (p: { value: [number, number, number | null] }) => `${d.params[p.value[1]]} · ${d.conditions[p.value[0]]}: ${labels[p.value[1]]?.[p.value[0]] ?? ''}` },
    xAxis: { type: 'category', data: d.conditions, axisLabel: { color: c.textMuted, rotate: 30, fontSize: 10 } },
    yAxis: { type: 'category', data: d.params, axisLabel: { color: c.textMuted } },
    visualMap: { min: -0.2, max: 0.2, calculable: false, show: false, inRange: { color: [c.accent2, c.surfaceRaised, c.accent] } },
    series: [{ type: 'heatmap', data: cells, label: { show: true, fontSize: 9, color: c.text, formatter: (p: { value: [number, number] }) => labels[p.value[1]]?.[p.value[0]] ?? '' } }],
  };
}

export function PowerChart({ data }: { data: PowerCurveData }) {
  const { t } = useTranslation(); const lang = useLang(); const { theme } = useTheme();
  const option = useMemo(() => buildPowerOption(data, lang, palettes[theme], t('sim.powerAxis'), t('sim.powerYAxis')), [data, lang, theme, t]);
  return <EChart option={option} ariaLabel={t('sim.powerAria')} height={360} />;
}

export function BiasHeatmap({ data }: { data: BiasHeatmapData }) {
  const { t } = useTranslation(); const lang = useLang(); const { theme } = useTheme();
  const option = useMemo(() => buildBiasOption(data, lang, palettes[theme]), [data, lang, theme]);
  return <EChart option={option} ariaLabel={t('sim.biasAria')} height={Math.max(260, 28 * data.params.length + 120)} />;
}
