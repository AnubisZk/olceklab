import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import type { EChartsCoreOption } from 'echarts/core';
import type { Lang, ScreeData } from '../../api/types';
import { useTheme } from '../../theme/ThemeContext';
import { palettes } from '../../theme/tokens';
import { EChart } from './EChart';

type SeriesKey = 'pc_observed' | 'pc_reference' | 'fa_observed' | 'fa_reference';

export function buildScreeOption(data: ScreeData, lang: Lang, names: Record<SeriesKey, string>, yName: string, colors: {
  accent: string; accent2: string; muted: string; text: string; border: string;
}): EChartsCoreOption {
  const defs: { key: SeriesKey; color: string; dashed: boolean }[] = [
    { key: 'pc_observed', color: colors.accent, dashed: false },
    { key: 'pc_reference', color: colors.accent, dashed: true },
    { key: 'fa_observed', color: colors.accent2, dashed: false },
    { key: 'fa_reference', color: colors.accent2, dashed: true },
  ];
  const present = defs.filter((d) => Array.isArray(data[d.key]));
  const labels = data.labels[lang];
  return {
    animation: false,
    textStyle: { fontFamily: 'JetBrains Mono, monospace', color: colors.text },
    legend: { top: 0, textStyle: { color: colors.text } },
    grid: { left: 48, right: 16, top: 40, bottom: 36 },
    tooltip: {
      trigger: 'axis',
      // İpucundaki sayılar R'nin biçimlediği metinlerdir.
      formatter: (params: { seriesIndex: number; dataIndex: number; marker: string }[]) => {
        const k = data.k[params[0]?.dataIndex ?? 0];
        return [`${k}`, ...params.map((p) => {
          const key = present[p.seriesIndex].key;
          return `${p.marker}${names[key]}: ${labels[key]?.[p.dataIndex] ?? ''}`;
        })].join('<br/>');
      },
    },
    xAxis: {
      type: 'category', data: data.k.map(String), boundaryGap: false,
      axisLine: { lineStyle: { color: colors.border } }, axisLabel: { color: colors.muted },
    },
    yAxis: {
      type: 'value', name: yName, nameTextStyle: { color: colors.muted },
      splitLine: { lineStyle: { color: colors.border } },
      axisLabel: { color: colors.muted, formatter: (v: number) => (lang === 'tr' ? String(v).replace('.', ',') : String(v)) },
    },
    series: present.map((d) => ({
      name: names[d.key], type: 'line', data: data[d.key] as number[], symbol: d.dashed ? 'none' : 'circle', symbolSize: 7,
      lineStyle: { color: d.color, width: 2, type: d.dashed ? 'dashed' : 'solid' }, itemStyle: { color: d.color },
    })),
  };
}

export function ScreeChart({ data }: { data: ScreeData }) {
  const { t, i18n } = useTranslation();
  const { theme } = useTheme();
  const lang: Lang = i18n.language === 'en' ? 'en' : 'tr';
  const option = useMemo(() => buildScreeOption(data, lang, {
    pc_observed: t('fn.chart.pcObserved'), pc_reference: t('fn.chart.pcReference'),
    fa_observed: t('fn.chart.faObserved'), fa_reference: t('fn.chart.faReference'),
  }, t('fn.chart.eigenvalue'), {
    // Renkler tema belirteçlerinden alınır (CSS değişkenleri tema efektinden önce okunabilirdi).
    accent: palettes[theme].accent, accent2: palettes[theme].accent2, muted: palettes[theme].textMuted,
    text: palettes[theme].text, border: palettes[theme].border,
  }), [data, lang, theme, t]);
  return <EChart option={option} ariaLabel={t('fn.chart.aria')} />;
}
