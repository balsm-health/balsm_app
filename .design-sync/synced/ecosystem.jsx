/* ecosystem.jsx — "Balsm is bigger than this app" sheet.
   Ecosystem story + concrete ways a patient can contribute & spread Balsm. */

const ECO_PARTS = [
  { icon: 'smartphone',  h: 'eco_p1h', b: 'eco_p1b', color: 'var(--petal-blue)',    bg: 'var(--petal-blue-50, #E4F0FF)' },
  { icon: 'building-2',  h: 'eco_p2h', b: 'eco_p2b', color: 'var(--petal-aqua)',    bg: '#E0F7F6', roadmap: true },
];

const ECO_ACTIONS = [
  { icon: 'share-2',      h: 'eco_a1h', b: 'eco_a1b' },
  { icon: 'message-square-heart', h: 'eco_a2h', b: 'eco_a2b' },
  { icon: 'building-2',   h: 'eco_a3h', b: 'eco_a3b' },
  { icon: 'code-2',       h: 'eco_a4h', b: 'eco_a4b' },
];

function EcosystemSheet({ onClose, onFeedback }) {
  const { t, lang } = useApp();
  const head = { fontFamily: lang === 'ar' ? 'var(--font-arabic)' : 'var(--font-display)', fontWeight: 700, color: 'var(--fg1)' };
  return (
    <SettingsSheet title={t('eco_title')} onClose={onClose}>
      {/* Brand moment — the one place all five petals may appear */}
      <div style={{ textAlign: 'center', padding: '10px 0 18px' }}>
        <PetalMark style={{ width: 54, height: 54, display: 'block', margin: '0 auto 12px' }} />
        <div style={{ ...head, fontSize: 'var(--pt-xl)', lineHeight: 1.3 }}>{t('eco_hero')}</div>
        <p className="meta" style={{ margin: '8px auto 0', maxWidth: 280, lineHeight: 1.55 }}>{t('eco_sub')}</p>
      </div>

      {/* The ecosystem */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {ECO_PARTS.map(p => (
          <div key={p.h} style={{ display: 'flex', gap: 12, alignItems: 'flex-start', padding: '12px 14px', background: 'var(--bg2)', borderRadius: 'var(--radius-md)' }}>
            <div className="lico" style={{ background: p.bg, color: p.color, flexShrink: 0 }}><Icon name={p.icon} /></div>
            <div>
              <div style={{ ...head, fontSize: 'var(--pt-sm)', display: 'flex', alignItems: 'center', gap: 6 }}>
                {t(p.h)}
                {p.roadmap && <span style={{ fontSize: 'var(--pt-2xs)', fontWeight: 700, letterSpacing: '0.05em', color: 'var(--fg3)', background: 'var(--bg3, var(--balsm-ink-50))', borderRadius: 999, padding: '2px 8px' }}>{lang === 'ar' ? 'قريباً' : 'Roadmap'}</span>}
              </div>
              <div className="meta" style={{ marginTop: 2, lineHeight: 1.5 }}>{t(p.b)}</div>
            </div>
          </div>
        ))}
      </div>

      {/* How you can help */}
      <div style={{ ...head, fontSize: 'var(--pt-md)', margin: '24px 0 4px' }}>{t('eco_help_t')}</div>
      <p className="meta" style={{ margin: '0 0 12px', lineHeight: 1.55 }}>{t('eco_help_sub')}</p>
      <div className="card list-card" style={{ margin: 0 }}>
        {ECO_ACTIONS.map(a => (
          <div key={a.h} className="list-row" style={{ alignItems: 'flex-start' }}
            onClick={a.h === 'eco_a2h' ? () => { onClose(); onFeedback && onFeedback(); } : undefined}>
            <div className="lico" style={{ flexShrink: 0 }}><Icon name={a.icon} /></div>
            <div className="grow">
              <div style={{ fontWeight: 600, color: 'var(--fg1)', fontSize: 'var(--pt-sm)' }}>{t(a.h)}</div>
              <div className="meta" style={{ marginTop: 2, lineHeight: 1.5 }}>{t(a.b)}</div>
            </div>
            {a.h === 'eco_a2h' && <span className="rchev"><Icon name="chevron-right" /></span>}
          </div>
        ))}
      </div>

      <p style={{ textAlign: 'center', margin: '20px 0 6px', fontSize: 'var(--pt-2xs)', color: 'var(--fg3)', letterSpacing: '0.16em', textTransform: 'uppercase', fontWeight: 600 }}>
        {lang === 'ar' ? 'مفتوح · عربي · موثوق' : 'Open · Arab · Trusted'}
      </p>
    </SettingsSheet>
  );
}

window.EcosystemSheet = EcosystemSheet;
