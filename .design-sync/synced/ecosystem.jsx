/* ecosystem.jsx — "Balsm is bigger than this app" sheet.
   Ecosystem story + concrete ways a patient can contribute & spread Balsm. */

const ECO_PARTS = [
  { icon: 'smartphone',  h: 'eco_p1h', b: 'eco_p1b', color: 'var(--petal-blue)',    bg: 'var(--petal-blue-50, #E4F0FF)' },
  { icon: 'building-2',  h: 'eco_p2h', b: 'eco_p2b', color: 'var(--petal-aqua)',    bg: '#E0F7F6', roadmap: true },
];

const ECO_ACTIONS = [
  { icon: 'share-2',      h: 'eco_a1h', b: 'eco_a1b', share: true },
  { icon: 'message-square-heart', h: 'eco_a2h', b: 'eco_a2b' },
  { icon: 'building-2',   h: 'eco_a3h', b: 'eco_a3b', href: 'https://balsm.health/providers' },
  { icon: 'code-2',       h: 'eco_a4h', b: 'eco_a4b', href: 'https://balsm.health/contributors' },
];

/* Social links — outline glyphs drawn on Lucide's 24px grid / 1.9 stroke so they sit with the rest of the icon set. */
const ECO_DOWNLOAD_URL = 'https://balsm.health/download';

const ECO_SOCIAL = [
  { id: 'website', label: 'balsm.health', href: 'https://balsm.health',
    g: <><circle cx="12" cy="12" r="10" /><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20" /><path d="M2 12h20" /></> },
  { id: 'linkedin', label: 'LinkedIn', href: 'https://www.linkedin.com/company/balsm-health',
    g: <><path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-4 0v7h-4v-7a6 6 0 0 1 6-6z" /><rect x="2" y="9" width="4" height="12" /><circle cx="4" cy="4" r="2" /></> },
  { id: 'facebook', label: 'Facebook', href: 'https://www.facebook.com/balsm.health',
    g: <path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z" /> },
  { id: 'instagram', label: 'Instagram', href: 'https://www.instagram.com/balsm.health',
    g: <><rect x="2" y="2" width="20" height="20" rx="5" /><circle cx="12" cy="12" r="4" /><path d="M17.5 6.5h.01" /></> },
  { id: 'tiktok', label: 'TikTok', href: 'https://www.tiktok.com/@balsm.health',
    g: <path d="M13 3v12.5a3 3 0 1 1-3-3M13 3c.4 2.6 2.4 4.6 5 5" /> },
  { id: 'patreon', label: 'Patreon', href: 'https://www.patreon.com/balsm',
    g: <><circle cx="14.5" cy="9.5" r="6" /><path d="M4 3.5v17" /></> },
  { id: 'github', label: 'GitHub', href: 'https://github.com/balsm-health',
    g: <><path d="M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 1.5-2.64-.5-5.36-.5-8 0C6 2 5 2 5 2c-.3 1.15-.3 2.35 0 3.5A5.4 5.4 0 0 0 4 9c0 3.5 3 5.5 6 5.5-.39.49-.68 1.05-.85 1.65-.17.6-.22 1.23-.15 1.85v4" /><path d="M9 18c-4.51 2-5-2-7-2" /></> },
];

function EcosystemSheet({ onClose, onFeedback }) {
  const { t, lang } = useApp();
  const [copied, setCopied] = useState(false);
  const shareApp = async () => {
    const text = lang === 'ar'
      ? 'أستخدم بلسم لمتابعة صحتي — مجاني، ومفتوح، وبياناتك على جهازك. حمّله من هنا:'
      : 'I use Balsm to keep track of my health — free, open, and your data stays on your phone. Get it here:';
    try {
      if (navigator.share) { await navigator.share({ title: 'Balsm', text, url: ECO_DOWNLOAD_URL }); return; }
    } catch (e) { if (e && e.name === 'AbortError') return; }
    try { await navigator.clipboard.writeText(text + ' ' + ECO_DOWNLOAD_URL); } catch (e) {}
    setCopied(true); setTimeout(() => setCopied(false), 2200);
  };
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
          <div key={p.h} style={{ display: 'flex', gap: 12, alignItems: 'flex-start', padding: '12px 14px', background: 'var(--balsm-ink-50)', borderRadius: 'var(--radius-md)' }}>
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
          <div key={a.h} className="list-row" style={{ alignItems: 'flex-start', cursor: (a.href || a.share || a.h === 'eco_a2h') ? 'pointer' : undefined }}
            onClick={a.share ? shareApp : a.href ? () => window.open(a.href, '_blank', 'noopener,noreferrer') : a.h === 'eco_a2h' ? () => { onClose(); onFeedback && onFeedback(); } : undefined}>
            <div className="lico" style={{ flexShrink: 0 }}><Icon name={a.icon} /></div>
            <div className="grow">
              <div style={{ fontWeight: 600, color: 'var(--fg1)', fontSize: 'var(--pt-sm)' }}>{t(a.h)}</div>
              <div className="meta" style={{ marginTop: 2, lineHeight: 1.5 }}>{t(a.b)}</div>
              {a.share && (
                <div dir="ltr" style={{ marginTop: 6, fontSize: 'var(--pt-xs)', fontWeight: 700, color: copied ? 'var(--petal-mint-700, var(--balsm-success))' : 'var(--app-accent-600)', display: 'flex', alignItems: 'center', gap: 5, justifyContent: lang === 'ar' ? 'flex-end' : 'flex-start' }}>
                  <Icon name={copied ? 'check' : 'link'} size={12} />
                  {copied ? (lang === 'ar' ? 'تم نسخ الرابط' : 'Link copied') : 'balsm.health/download'}
                </div>
              )}
            </div>
            {a.h === 'eco_a2h' && <span className="rchev"><Icon name="chevron-right" /></span>}
            {a.href && <span className="rchev"><Icon name="external-link" size={16} /></span>}
            {a.share && <span className="rchev"><Icon name="share" size={16} /></span>}
          </div>
        ))}
      </div>

      {/* Follow Balsm */}
      <div style={{ ...head, fontSize: 'var(--pt-md)', margin: '24px 0 4px' }}>{lang === 'ar' ? 'تابع بلسم' : 'Follow Balsm'}</div>
      <p className="meta" style={{ margin: '0 0 12px', lineHeight: 1.55 }}>
        {lang === 'ar' ? 'أخبار المشروع، الكود المفتوح، وطرق دعمه.' : 'Project news, the open code, and ways to support it.'}
      </p>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, minmax(0, 1fr))', gap: 8 }}>
        {ECO_SOCIAL.map(s => (
          <a key={s.id} href={s.href} target="_blank" rel="noopener noreferrer" aria-label={s.label} title={s.label}
            className="eco-social"
            style={{ height: 44, borderRadius: 'var(--radius-md)', background: 'var(--balsm-ink-50)', color: 'var(--fg2)', display: 'flex', alignItems: 'center', justifyContent: 'center', textDecoration: 'none', transition: 'background var(--dur-fast) var(--ease-out), color var(--dur-fast) var(--ease-out)' }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{s.g}</svg>
          </a>
        ))}
      </div>
      <style>{`.eco-social:hover{background:var(--app-accent-50) !important;color:var(--app-accent-600) !important}.eco-social:active{transform:scale(.98)}`}</style>

      <p style={{ textAlign: 'center', margin: '20px 0 6px', fontSize: 'var(--pt-2xs)', color: 'var(--fg3)', letterSpacing: '0.16em', textTransform: 'uppercase', fontWeight: 600 }}>
        {lang === 'ar' ? 'مفتوح · عربي · موثوق' : 'Open · Arab · Trusted'}
      </p>
    </SettingsSheet>
  );
}

window.EcosystemSheet = EcosystemSheet;
