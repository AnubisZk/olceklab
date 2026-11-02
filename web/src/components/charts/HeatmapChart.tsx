import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import type { EChartsCoreOption } from 'echarts/core';
import type { HeatmapData, Lang } from '../../api/types';
import { useTheme } from '../../theme/ThemeContext';
import { palettes } from '../../theme/tokens';
import { EChart } from './EChart';

export function buildHeatmapOption(data: HeatmapData, lang: Lang, colors: { low: string; high: string; text: string; muted: string }): EChartsCoreOption {
  const cells: [number, number, number | null][] = [];
  data.items.forEach((_, i) => data.categories.forEach((_c, j) => cells.push([j, i, data.proportions[i]?.[j] ?? null])));
  return {
    animation: false,
    textStyle: { fontFamily: 'JetBrains Mono, monospace', color: colors.text },
    grid: { left: 56, right: 16, top: 16, bottom: 56 },
    tooltip: {
      // İpucundaki yüzde, R'nin biçimlediği metindir; sayım tam sayıdır.
      formatter: (p: { data: [number, number, number | null] }) => {
        const [j, i] = p.data;
        const count = data.counts[i]?.[j];
        return `${data.items[i]} · ${data.categories[j]}: ${count ?? '—'} (${data.labels[lang][i]?.[j] ?? '—'})`;
      },
    },
    xAxis: { type: 'category', data: data.categories, axisLabel: { color: colors.muted }, splitArea: { show: false } },
    yAxis: { type: 'category', data: data.items, inverse: true, axisLabel: { color: colors.muted } },
    visualMap: { min: 0, max: 1, calculable: false, show: false, inRange: { color: [colors.low, colors.high] } },
    series: [{ type: 'heatmap', data: cells, emphasis: { itemStyle: { borderColor: colors.text, borderWidth: 1 } } }],
  };
}

export function HeatmapChart({ data }: { data: HeatmapData }) {
  const { t, i18n } = useTranslation();
  const { theme } = useTheme();
  const lang: Lang = i18n.language === 'en' ? 'en' : 'tr';
  const option = useMemo(() => buildHeatmapOption(data, lang, {
    low: palettes[theme].surfaceRaised, high: palettes[theme].accent,
    text: palettes[theme].text, muted: palettes[theme].textMuted,
  }), [data, lang, theme]);
  return <EChart option={option} ariaLabel={t('items.heatmapAria')} height={Math.max(220, 26 * data.items.length + 72)} />;
}
