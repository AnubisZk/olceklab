// Yalnızca R biçimli yer tutucular sayısal metin üretebilir. Modelin aynı değeri
// elle yazması da reddedilir: eşleşen bir sayı farklı istatistiğe ait olabilir.
export interface NumberIssue { start: number; end: number; text: string; reason: 'number' | 'unknown_placeholder' }
export interface NumberCheck { passed: boolean; issues: NumberIssue[] }
const words = new Set(('sıfır bir iki üç dört beş altı yedi sekiz dokuz on yirmi otuz kırk elli altmış yetmiş seksen doksan yüz bin milyon milyar trilyon yüzde yarım çeyrek ' +
  'zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty thirty forty fifty sixty seventy eighty ninety hundred thousand million billion trillion percent half quarter first second third fourth fifth').split(' '));
export function checkNumbers(text: string): NumberCheck {
  const issues: NumberIssue[] = [];
  for (const m of text.matchAll(/[+\-−–]?\s*%?\s*(?:\p{N}+(?:[.,]\p{N}+)*|[.,]\p{N}+)(?:[eE][+\-−]?\p{N}+)?\s*%?/gu)) {
    const lead = m[0].length - m[0].trimStart().length;
    const value = m[0].trim();
    issues.push({ start: m.index + lead, end: m.index + lead + value.length, text: value, reason: 'number' });
  }
  for (const m of text.matchAll(/\p{L}+/gu)) {
    if (words.has(m[0].toLocaleLowerCase('tr-TR')) || words.has(m[0].toLowerCase())) issues.push({ start: m.index, end: m.index + m[0].length, text: m[0], reason: 'number' });
  }
  issues.sort((a, b) => a.start - b.start);
  return { passed: issues.length === 0, issues };
}
export function fillAndCheck(template: string, values: Map<string, string>): { text: string; check: NumberCheck } {
  let text = ''; let from = 0; const issues: NumberIssue[] = [];
  function literal(s: string) {
    const offset = text.length;
    issues.push(...checkNumbers(s).issues.map(i => ({ ...i, start: i.start + offset, end: i.end + offset })));
    text += s;
  }
  for (const m of template.matchAll(/\{\{([^{}]+)\}\}/g)) {
    literal(template.slice(from, m.index));
    const value = values.get(m[1].trim());
    if (value === undefined) {
      issues.push({ start: text.length, end: text.length + m[0].length, text: m[0], reason: 'unknown_placeholder' });
      text += m[0];
    } else text += value;
    from = m.index + m[0].length;
  }
  literal(template.slice(from));
  if ((text.includes('{{') || text.includes('}}')) && !issues.some(i => i.reason === 'unknown_placeholder')) issues.push({ start: 0, end: text.length, text, reason: 'unknown_placeholder' });
  return { text, check: { passed: issues.length === 0, issues: issues.sort((a, b) => a.start - b.start) } };
}
