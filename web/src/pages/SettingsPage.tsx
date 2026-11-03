import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { fetchGatewayHealth } from '../api/engine';
import { config } from '../config';
import { LanguageSwitch, ThemeToggle } from '../components/Controls';
import { PageHeader } from './PageHeader';
import { useReport } from '../state/ReportContext';
import { exportAiLog } from '../api/ai';
import { saveBlob } from '../api/client';

export function SettingsPage() {
  const { t } = useTranslation();
  const report = useReport();
  const gw = useQuery({ queryKey: ['gateway', 'health'], queryFn: ({ signal }) => fetchGatewayHealth(signal), enabled: config.aiEnabled, retry: false });

  return (
    <>
      <PageHeader pageKey="settings" />
      <section className="card">
        <dl className="kv">
          <dt>{t('language.label')}</dt>
          <dd><LanguageSwitch /></dd>
          <dt>{t('theme.label')}</dt>
          <dd><ThemeToggle /></dd>
          <dt>{t('settings.decimal')}</dt>
          <dd className="muted">{t('settings.decimalNote')}</dd>
          <dt>{t('settings.ai')}</dt>
          <dd className="mono" data-testid="ai-provider">
            {!config.aiEnabled ? 'none' : gw.isSuccess ? `${gw.data.provider}${gw.data.model ? ` · ${gw.data.model}` : ''}` : gw.isError ? t('settings.aiUnavailable') : '…'}
          </dd>
          <dt>{t('settings.mode')}</dt>
          <dd>{config.deployMode === 'online' ? t('settings.modeOnline') : t('settings.modeLocal')}</dd>
        </dl>
      </section>
      <section className="card" aria-labelledby="privacy-title">
        <h2>{t('ai.logTitle')}</h2>
        <p className="muted small">{t('ai.logNote')}</p>
        <div className="actions">
          {(['json', 'md'] as const).map(format => <button type="button" className="btn" key={format} disabled={!report.aiLog.length}
            onClick={() => saveBlob(exportAiLog(report.aiLog, format), `olceklab_ai_log.${format}`)}>{t('ai.exportLog')} ({format === 'json' ? 'JSON' : 'Markdown'})</button>)}
          <button type="button" className="btn" disabled={!report.aiLog.length} onClick={report.clearAiLog}>{t('ai.clearLog')}</button>
        </div>
        <h2 id="privacy-title">{t('settings.privacyTitle')}</h2>
        <ul className="list">
          <li>{t('settings.privacy1')}</li>
          <li>{t('settings.privacy2')}</li>
          <li>{t('settings.privacy3')}</li>
          <li>{t('settings.privacy4')}</li>
        </ul>
      </section>
    </>
  );
}
