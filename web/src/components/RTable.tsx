import { useMemo, useState } from 'react';
import {
  flexRender, getCoreRowModel, getSortedRowModel, useReactTable, type ColumnDef, type SortingState,
} from '@tanstack/react-table';
import { useTranslation } from 'react-i18next';
import type { RTable as RTableData } from '../api/types';
import { useLang } from '../useLang';

interface Row {
  raw: Record<string, unknown>;
  fmt: Record<string, string>;
}

// Hücrede R'nin biçimlediği metin gösterilir; sıralama ham değere göre yapılır.
function compareRaw(a: unknown, b: unknown): number {
  if (a === b) return 0;
  if (a === null || a === undefined) return 1;
  if (b === null || b === undefined) return -1;
  if (typeof a === 'number' && typeof b === 'number') return a - b;
  return String(a).localeCompare(String(b), 'tr');
}

export function RTable({ table }: { table: RTableData }) {
  const lang = useLang();
  const { t } = useTranslation();
  const [sorting, setSorting] = useState<SortingState>([]);
  const fmtRows = table.rows_fmt[lang];

  const data = useMemo<Row[]>(
    () => table.rows.map((raw, i) => ({ raw, fmt: fmtRows[i] ?? {} })),
    [table.rows, fmtRows],
  );
  const columns = useMemo<ColumnDef<Row>[]>(
    () =>
      table.columns.map((c) => ({
        id: c.key,
        header: lang === 'tr' ? c.label_tr : c.label_en,
        accessorFn: (row) => row.raw[c.key],
        cell: ({ row }) => row.original.fmt[c.key] ?? '',
        sortingFn: (a, b) => compareRaw(a.original.raw[c.key], b.original.raw[c.key]),
        meta: { numeric: c.type === 'number' },
      })),
    [table.columns, lang],
  );

  const rt = useReactTable({
    data, columns, state: { sorting }, onSortingChange: setSorting, sortDescFirst: false,
    getCoreRowModel: getCoreRowModel(), getSortedRowModel: getSortedRowModel(),
  });
  const title = lang === 'tr' ? table.title_tr : table.title_en;
  const note = lang === 'tr' ? table.note_tr : table.note_en;

  return (
    <figure className="rtable" data-table-id={table.id}>
      <figcaption className="rtable-title">{title}</figcaption>
      <div className="table-wrap">
        <table>
          <thead>
            {rt.getHeaderGroups().map((hg) => (
              <tr key={hg.id}>
                {hg.headers.map((h) => {
                  const numeric = (h.column.columnDef.meta as { numeric?: boolean } | undefined)?.numeric;
                  const dir = h.column.getIsSorted();
                  return (
                    <th key={h.id} scope="col" className={numeric ? 'num' : undefined}
                        aria-sort={dir === 'asc' ? 'ascending' : dir === 'desc' ? 'descending' : 'none'}>
                      <button type="button" className="th-sort" onClick={h.column.getToggleSortingHandler()}
                              title={t('table.sort')}>
                        {flexRender(h.column.columnDef.header, h.getContext())}
                        <span aria-hidden="true">{dir === 'asc' ? ' ▲' : dir === 'desc' ? ' ▼' : ''}</span>
                      </button>
                    </th>
                  );
                })}
              </tr>
            ))}
          </thead>
          <tbody>
            {rt.getRowModel().rows.map((r) => (
              <tr key={r.id}>
                {r.getVisibleCells().map((cell) => {
                  const numeric = (cell.column.columnDef.meta as { numeric?: boolean } | undefined)?.numeric;
                  return (
                    <td key={cell.id} className={numeric ? 'num mono' : undefined}>
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {note && <p className="table-note">{note}</p>}
    </figure>
  );
}
