import { useEffect, useRef } from 'react';
import * as echarts from 'echarts/core';
import { HeatmapChart, LineChart } from 'echarts/charts';
import { GridComponent, LegendComponent, TooltipComponent, VisualMapComponent } from 'echarts/components';
import { SVGRenderer } from 'echarts/renderers';
import type { EChartsCoreOption } from 'echarts/core';

echarts.use([LineChart, HeatmapChart, GridComponent, LegendComponent, TooltipComponent, VisualMapComponent, SVGRenderer]);

// Grafik yalnızca R'den gelen verilerle çizilir; bu bileşen hesap yapmaz.
export function EChart({ option, ariaLabel, height = 340 }: { option: EChartsCoreOption; ariaLabel: string; height?: number }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const chart = echarts.init(el, undefined, { renderer: 'svg' });
    chart.setOption(option);
    let ro: ResizeObserver | undefined;
    if (typeof ResizeObserver !== 'undefined') {
      ro = new ResizeObserver(() => chart.resize());
      ro.observe(el);
    }
    return () => {
      ro?.disconnect();
      chart.dispose();
    };
  }, [option]);
  return <div ref={ref} className="chart" role="img" aria-label={ariaLabel} style={{ width: '100%', height }} />;
}
