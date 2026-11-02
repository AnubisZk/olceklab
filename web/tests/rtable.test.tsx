import { describe, expect, it } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { I18nextProvider } from 'react-i18next';
import { RTable } from '../src/components/RTable';
import { initI18n } from '../src/i18n';
import itemRec from './fixtures/bfi_item.json';
import type { RTable as RTableData } from '../src/api/types';

const t1 = itemRec.tables[0] as unknown as RTableData;

async function renderTable(lng: 'tr' | 'en') {
  const i18n = await initI18n(lng);
  render(<I18nextProvider i18n={i18n}><RTable table={t1} /></I18nextProvider>);
}

describe('R tablosu', () => {
  it('hücrelerde geçerli dilin R metnini gösterir', async () => {
    await renderTable('tr');
    expect(screen.getByText(t1.title_tr)).toBeInTheDocument();
    const first = within(screen.getAllByRole('row')[1]);
    expect(first.getByText(t1.rows_fmt.tr[0].r_drop)).toBeInTheDocument();
    await (await initI18n('en')).changeLanguage('en');
    expect(await screen.findByText(t1.title_en)).toBeInTheDocument();
    expect(within(screen.getAllByRole('row')[1]).getByText(t1.rows_fmt.en[0].r_drop)).toBeInTheDocument();
    await (await initI18n('tr')).changeLanguage('tr');
  });

  it('sıralama ham değere göre yapılır, gösterim R metni kalır', async () => {
    await renderTable('tr');
    await userEvent.click(screen.getByRole('button', { name: /Düzeltilmiş madde-toplam r/ }));
    const rawSorted = [...t1.rows.map((r, i) => ({ v: r.r_drop as number, i }))].sort((a, b) => a.v - b.v);
    const rows = screen.getAllByRole('row').slice(1);
    expect(within(rows[0]).getByText(t1.rows_fmt.tr[rawSorted[0].i].item)).toBeInTheDocument();
    expect(within(rows.at(-1)!).getByText(t1.rows_fmt.tr[rawSorted.at(-1)!.i].item)).toBeInTheDocument();
  });

  it('tablo notu (kaynak satırı) gösterilir', async () => {
    await renderTable('tr');
    expect(screen.getByText(t1.note_tr as string)).toBeInTheDocument();
  });
});
