/* update.jsx — app version update prompt (optional = skippable, required = blocking) */

const UPDATE_INFO = {
  current: '2.3.1', next: '2.4.0', date: '09/10/2026',
  notes: [
    { icon: 'cloud-upload', en: ['Back up to Google Drive', 'Keep a copy of your records in your own Drive.'], ar: ['النسخ الاحتياطي على Google Drive', 'احتفظ بنسخة من سجلاتك في حسابك الخاص.'] },
    { icon: 'bell-ring',    en: ['Smarter dose reminders', 'Snooze a dose and Balsm reminds you again, even offline.'], ar: ['تذكيرات أذكى للجرعات', 'أجّل الجرعة وسيذكّرك بلسم مرة أخرى، حتى دون إنترنت.'] },
    { icon: 'map-pin',      en: ['Faster nearby search', 'Find clinics, labs and pharmacies in fewer taps.'], ar: ['بحث أسرع عمّا حولك', 'اعثر على العيادات والمعامل والصيدليات بلمسات أقل.'] },
    { icon: 'wrench',       en: ['Fixes and polish', 'Body map and search field alignment.'], ar: ['إصلاحات وتحسينات', 'محاذاة خريطة الجسم وحقل البحث.'] },
  ],
};

function UpdateSheet({ lang, required = false, onClose }) {
  const ar = lang === 'ar';
  const [phase, setPhase] = useState('idle'); // idle · downloading · ready
  const [pct, setPct] = useState(0);
  const u = UPDATE_INFO;
  useEffect(() => {
    if (phase !== 'downloading') return;
    const id = setInterval(() => setPct(p => {
      const n = Math.min(100, p + 7 + Math.random() * 9);
      if (n >= 100) { clearInterval(id); setTimeout(() => setPhase('ready'), 250); }
      return n;
    }), 160);
    return () => clearInterval(id);
  }, [phase]);

  const eyebrow = { fontSize: 'var(--pt-xs)', fontWeight: 700, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--fg3)' };
  const ver = (label, v, on) => (
    <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 2, alignItems: 'center' }}>
      <span style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg3)', fontWeight: 600 }}>{label}</span>
      <span dir="ltr" style={{ fontFamily: 'var(--font-mono)', fontWeight: 600, fontSize: 'var(--pt-md)', color: on ? 'var(--app-accent)' : 'var(--fg2)' }}>v{v}</span>
    </div>
  );
  const iconSrc = (window.__resources && window.__resources.icon) || 'assets/icon.svg?v=7';
  const dismissable = !required && phase === 'idle';

  return (
    <>
      <style>{`@keyframes upSlideUp{from{transform:translateY(110%)}to{transform:none}}`}</style>
      <div className="app-scrim" onClick={dismissable ? onClose : undefined} style={{ position: 'absolute', inset: 0, zIndex: 60, background: 'rgba(20,32,43,0.36)', backdropFilter: 'blur(2px)' }}></div>
      <div className="app-sheet" role="dialog" aria-modal="true" aria-labelledby="up-title" style={{ position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 61, background: '#fff', borderRadius: '20px 20px 0 0', maxHeight: '90%', display: 'flex', flexDirection: 'column', animation: 'upSlideUp 0.3s cubic-bezier(0.16,1,0.3,1) both' }}>
        <div style={{ padding: '10px 20px 0', flexShrink: 0 }}>
          <div className="sheet-grab" style={{ margin: '0 auto 12px' }}></div>
          <div style={{ display: 'flex', justifyContent: 'flex-end', minHeight: 36 }}>
            {dismissable && <button className="round-btn ghost" onClick={onClose} aria-label={ar ? 'إغلاق' : 'Close'}><Icon name="x" size={17} /></button>}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10, textAlign: 'center', marginTop: -12 }}>
            <img src={iconSrc} alt="" style={{ width: 52, height: 52, objectFit: 'contain' }} />
            <div style={{ ...eyebrow, color: required ? '#8A6A10' : 'var(--app-accent)' }}>
              {required ? (ar ? 'تحديث مطلوب' : 'Required update') : (ar ? 'تحديث جديد' : 'New version')}
            </div>
            <div id="up-title" style={{ fontFamily: ar ? 'Cairo, var(--font-arabic)' : 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', color: 'var(--fg1)', lineHeight: 1.25, textWrap: 'balance' }}>
              {phase === 'ready' ? (ar ? 'التحديث جاهز' : 'Update ready')
                : required ? (ar ? 'حدّث بلسم للمتابعة' : 'Update Balsm to continue')
                : (ar ? 'نسخة أحدث من بلسم متاحة' : 'A newer Balsm is available')}
            </div>
            <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg2)', lineHeight: 1.5, maxWidth: 320, textWrap: 'pretty' }}>
              {phase === 'ready' ? (ar ? 'أعد تشغيل التطبيق لاستخدام النسخة الجديدة. بياناتك تبقى كما هي.' : 'Restart to start using the new version. Your data stays exactly as it is.')
                : required ? (ar ? 'هذه النسخة لازمة لمواصلة مزامنة سجلاتك بأمان.' : 'This version is needed to keep your records syncing securely.')
                : (ar ? 'بياناتك تبقى على جهازك أثناء التحديث.' : 'Your data stays on your device while you update.')}
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, margin: '16px 0 14px', padding: '12px 8px', borderRadius: 'var(--radius-lg)', background: 'var(--balsm-ink-50)' }}>
            {ver(ar ? 'نسختك' : 'Current', u.current, false)}
            <Icon name={ar ? 'arrow-left' : 'arrow-right'} size={18} style={{ color: 'var(--fg3)' }} />
            {ver(ar ? 'الجديدة' : 'New', u.next, true)}
          </div>
        </div>

        <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '0 20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8, marginBottom: 8 }}>
            <span style={eyebrow}>{ar ? 'ما الجديد' : 'What’s new'}</span>
            <span style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg3)' }}>{u.date}</span>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            {u.notes.map((n, i) => {
              const [t, d] = n[ar ? 'ar' : 'en'];
              return (
                <div key={i} style={{ display: 'flex', gap: 12, alignItems: 'flex-start', padding: '10px 0', borderTop: i ? '1px solid var(--balsm-ink-100)' : 'none' }}>
                  <div style={{ width: 34, height: 34, borderRadius: 'var(--radius-md)', background: 'var(--app-accent-50)', color: 'var(--app-accent)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Icon name={n.icon} size={17} /></div>
                  <div style={{ minWidth: 0 }}>
                    <div style={{ fontWeight: 600, fontSize: 'var(--pt-sm)', color: 'var(--fg1)' }}>{t}</div>
                    <div style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg2)', lineHeight: 1.5, marginTop: 2 }}>{d}</div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <div style={{ flexShrink: 0, padding: '12px 20px 24px', borderTop: '1px solid var(--balsm-ink-100)', display: 'flex', flexDirection: 'column', gap: 6 }}>
          {phase === 'downloading' ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8, padding: '6px 0' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 'var(--pt-xs)', fontWeight: 600, color: 'var(--fg2)' }}>
                <span>{ar ? 'جارٍ التنزيل…' : 'Downloading…'}</span><span dir="ltr" style={{ fontFamily: 'var(--font-mono)' }}>{Math.round(pct)}%</span>
              </div>
              <div role="progressbar" aria-valuenow={Math.round(pct)} aria-valuemin="0" aria-valuemax="100" style={{ height: 6, borderRadius: 999, background: 'var(--balsm-ink-100)', overflow: 'hidden' }}>
                <div style={{ height: '100%', width: pct + '%', background: 'var(--app-accent)', borderRadius: 999, transition: 'width 160ms linear' }}></div>
              </div>
            </div>
          ) : (
            <button className="b-btn b-btn-lg b-btn-primary" style={{ width: '100%', gap: 8 }}
              onClick={() => phase === 'ready' ? onClose() : (setPct(0), setPhase('downloading'))}>
              <Icon name={phase === 'ready' ? 'rotate-cw' : 'download'} size={17} />
              {phase === 'ready' ? (ar ? 'إعادة التشغيل' : 'Restart now') : (ar ? 'تحديث الآن' : 'Update now')}
            </button>
          )}
          {dismissable && (
            <button className="b-btn b-btn-md b-btn-ghost" style={{ width: '100%', color: 'var(--fg2)' }} onClick={onClose}>
              {ar ? 'تخطّي هذه النسخة' : 'Skip this version'}
            </button>
          )}
        </div>
      </div>
    </>
  );
}

Object.assign(window, { UpdateSheet, UPDATE_INFO });
