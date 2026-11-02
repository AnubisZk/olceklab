import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { fetchGatewayHealth } from '../api/engine';
import { config } from '../config';
import { LanguageSwitch, ThemeToggle } from '../components/Controls';
import { PageHeader } from './PageHeader';

export function SettingsPage() {
  const { t } = useTranslation();
  const gw = useQuery({ queryKey: ['gateway', 'health'], queryFn: ({ signal }) => fetchGatewayHealth(signal), retry: false });

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
            {gw.isSuccess ? gw.data.provider : gw.isError ? t('settings.aiUnavailable') : '…'}
          </dd>
          <dt>{t('settings.mode')}</dt>
          <dd>{config.deployMode === 'online' ? t('settings.modeOnline') : t('settings.modeLocal')}</dd>
        </dl>
      </section>
      <section className="card" aria-labelledby="privacy-title">
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
