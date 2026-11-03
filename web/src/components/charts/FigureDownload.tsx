import { useTranslation } from 'react-i18next';
import { saveBlob } from '../../api/client';

// Grafikleri SVG ya da PNG olarak indirme (SPEC §7 M10). Çizim R'nin verdiği değerlerle yapılmıştır; burada yalnızca
// mevcut SVG çıktısı dosyaya yazılır (PNG için tuval üzerinde 2× ölçekle rasterleştirilir).
export function svgToPng(svg: string, width: number, height: number, background: string): Promise<Blob> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => {
      const scale = 2;
      const canvas = document.createElement('canvas');
      canvas.width = Math.round(width * scale); canvas.height = Math.round(height * scale);
      const ctx = canvas.getContext('2d');
      if (!ctx) { reject(new Error('canvas')); return; }
      ctx.fillStyle = background; ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
      canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('png'))), 'image/png');
    };
    img.onerror = () => reject(new Error('svg'));
    img.src = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
  });
}

export function FigureDownload({ getSvg, name, size }: { getSvg: () => string | null; name: string; size: () => { width: number; height: number } }) {
  const { t } = useTranslation();
  const bg = () => getComputedStyle(document.body).backgroundColor || '#ffffff';
  return (
    <div className="actions figure-actions">
      <button type="button" className="btn btn-small" onClick={() => { const s = getSvg(); if (s) saveBlob(new Blob([s], { type: 'image/svg+xml' }), `${name}.svg`); }}>
        {t('result.downloadSvg')}
      </button>
      <button type="button" className="btn btn-small" onClick={() => {
        const s = getSvg(); if (!s) return; const { width, height } = size();
        void svgToPng(s, width, height, bg()).then((b) => saveBlob(b, `${name}.png`));
      }}>{t('result.downloadPng')}</button>
    </div>
  );
}

export const slug = (s: string) => s.toLocaleLowerCase('tr').normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/ı/g, 'i').replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '').slice(0, 40) || 'grafik';
