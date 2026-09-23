/* settings.jsx — multi-language selector + country (travel) selector sheets */

function SettingsSheet({ title, children, onClose }) {
  return (
    <>
      <style>{`@keyframes stSlideUp{from{transform:translateY(110%)}to{transform:none}}`}</style>
      <div className="app-scrim" onClick={onClose} style={{ position: 'absolute', inset: 0, zIndex: 40, background: 'rgba(20,32,43,0.36)', backdropFilter: 'blur(2px)' }} />
      <div className="app-sheet" style={{
        position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 41,
        background: '#fff', borderRadius: '20px 20px 0 0',
        maxHeight: '88%', display: 'flex', flexDirection: 'column',
        animation: 'stSlideUp 0.3s cubic-bezier(0.16,1,0.3,1) both',
      }}>
        <div style={{ padding: '10px 20px 0', flexShrink: 0 }}>
          <div className="sheet-grab" style={{ margin: '0 auto 12px' }} />
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: 12, borderBottom: '1px solid var(--balsm-ink-100)' }}>
            <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-lg)', color: 'var(--fg1)' }}>{title}</div>
            <button className="round-btn ghost" onClick={onClose}><Icon name="x" size={17} /></button>
          </div>
        </div>
        <div style={{ flex: 1, overflowY: 'auto', padding: '8px 20px 34px' }}>{children}</div>
      </div>
    </>
  );
}

/* ── Terms & privacy sheet (linked from auth footer) ────── */
function LegalSheet({ kind, onClose }) {
  const { t, lang } = useApp();
  const sections = kind === 'terms'
    ? [['legal_terms_1h', 'legal_terms_1b'], ['legal_terms_2h', 'legal_terms_2b'], ['legal_terms_3h', 'legal_terms_3b']]
    : [['legal_priv_1h', 'legal_priv_1b'], ['legal_priv_2h', 'legal_priv_2b'], ['legal_priv_3h', 'legal_priv_3b']];
  return (
    <SettingsSheet title={t(kind === 'terms' ? 'legal_terms_t' : 'legal_priv_t')} onClose={onClose}>
      <div style={{ padding: '6px 0 0' }}>
        {sections.map(([h, b], i) => (
          <div key={h} style={{ marginBottom: i < sections.length - 1 ? 22 : 8 }}>
            <div style={{ fontFamily: lang === 'ar' ? 'var(--font-arabic)' : 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)', marginBottom: 6 }}>{t(h)}</div>
            <p className="body-sm" style={{ margin: 0, lineHeight: 1.65, color: 'var(--fg2)' }}>{t(b)}</p>
          </div>
        ))}
        <div style={{ marginTop: 18, paddingTop: 14, borderTop: '1px solid var(--balsm-ink-100)', fontSize: 'var(--pt-2xs)', color: 'var(--fg3)' }}>
          {t('legal_updated')} <span className="num">01/06/2026</span>
        </div>
      </div>
    </SettingsSheet>
  );
}

/* Auth-footer consent line with tappable terms / privacy links */
function TermsLine() {
  const { t, lang } = useApp();
  const [legal, setLegal] = useState(null); /* null | 'terms' | 'privacy' */
  const link = { background: 'none', border: 'none', padding: 0, font: 'inherit', color: 'var(--app-accent-600)', fontWeight: 600, textDecoration: 'underline', textUnderlineOffset: 2, cursor: 'pointer' };
  return (
    <>
      <p className="meta" style={{ textAlign: 'center', margin: 0, lineHeight: 1.5 }}>
        {t('ph_terms_pre')}{' '}
        <button type="button" style={link} onClick={() => setLegal('terms')}>{t('ph_terms_link')}</button>
        {lang === 'ar' ? ' ' : ` ${t('ph_terms_and')} `}
        <button type="button" style={link} onClick={() => setLegal('privacy')}>{lang === 'ar' ? 'و' + t('ph_priv_link') : t('ph_priv_link')}</button>.
      </p>
      {legal && <LegalSheet kind={legal} onClose={() => setLegal(null)} />}
    </>
  );
}

/* ── Language selector ──────────────────────────────────── */
function LanguageSheet({ onClose }) {
  const { t, lang, setLang } = useApp();
  return (
    <SettingsSheet title={t('choose_lang')} onClose={onClose}>
      <div style={{ display: 'flex', flexDirection: 'column' }}>
        {LANGUAGES.map((l, i) => {
          const active = lang === l.code;
          return (
            <div key={l.code} onClick={() => { setLang(l.code); onClose(); }} style={{
              display: 'flex', alignItems: 'center', gap: 14, padding: '14px 0',
              borderBottom: i < LANGUAGES.length - 1 ? '1px solid var(--balsm-ink-50)' : 'none',
              cursor: 'pointer',
            }}>
              <div style={{
                width: 44, height: 44, borderRadius: 'var(--radius-md)', flexShrink: 0,
                background: active ? 'var(--app-accent-50)' : 'var(--balsm-ink-50)',
                color: active ? 'var(--app-accent-600)' : 'var(--fg2)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontFamily: l.rtl ? 'var(--font-arabic)' : 'var(--font-display)',
                fontWeight: 700, fontSize: 17,
              }}>{l.code.toUpperCase()}</div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)', fontFamily: l.rtl ? 'var(--font-arabic)' : 'var(--font-body)', direction: l.rtl ? 'rtl' : 'ltr' }}>{l.native}</div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginTop: 3 }}>
                  <span style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)' }}>{l.en}</span>
                  {!l.full && (
                    <span className="b-badge" style={{ background: 'var(--balsm-sun-500)', color: '#fff', fontSize: 'var(--pt-2xs)', padding: '1px 7px', fontWeight: 700 }}>{t('lang_beta')}</span>
                  )}
                </div>
              </div>
              {active && <Icon name="check-circle-2" size={22} style={{ color: 'var(--app-accent)', flexShrink: 0 }} />}
            </div>
          );
        })}
      </div>
    </SettingsSheet>
  );
}

/* ── Country / travel selector ──────────────────────────── */
function CountrySheet({ onClose }) {
  const { t, lang, country, setCountry } = useApp();
  return (
    <SettingsSheet title={t('choose_country')} onClose={onClose}>
      <p className="meta" style={{ margin: '4px 0 14px', lineHeight: 1.5 }}>{t('travel_help')}</p>
      <div style={{ display: 'flex', flexDirection: 'column' }}>
        {COUNTRIES.map((c, i) => {
          const active = country.code === c.code;
          return (
            <div key={c.code} onClick={() => { setCountry(c.code); onClose(); }} style={{
              display: 'flex', alignItems: 'center', gap: 14, padding: '13px 0',
              borderBottom: i < COUNTRIES.length - 1 ? '1px solid var(--balsm-ink-50)' : 'none',
              cursor: 'pointer',
            }}>
              <div style={{
                width: 44, height: 44, borderRadius: 'var(--radius-md)', flexShrink: 0,
                background: active ? 'var(--app-accent-50)' : 'var(--balsm-ink-50)',
                color: active ? 'var(--app-accent-600)' : 'var(--fg2)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontFamily: 'var(--font-mono)', fontWeight: 600, fontSize: 15, letterSpacing: '0.02em',
              }}>{c.code}</div>
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{c.name[lang]}</span>
                  {c.home && <span className="b-badge b-badge--neutral" style={{ fontSize: 'var(--pt-2xs)', padding: '1px 8px' }}>{t('home_country')}</span>}
                </div>
                <div style={{ display: 'flex', gap: 14, marginTop: 3, fontSize: 'var(--pt-sm)', color: 'var(--fg3)' }}>
                  <span className="num">{c.dial}</span>
                  <span style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                    <Icon name="phone-call" size={12} style={{ color: 'var(--balsm-danger)' }} />{t('emergency')} <b className="num" style={{ color: 'var(--fg2)' }}>{c.emergency}</b>
                  </span>
                </div>
              </div>
              {active && <Icon name="check-circle-2" size={22} style={{ color: 'var(--app-accent)', flexShrink: 0 }} />}
            </div>
          );
        })}
      </div>
    </SettingsSheet>
  );
}

Object.assign(window, { SettingsSheet, LanguageSheet, CountrySheet, LegalSheet, TermsLine });
