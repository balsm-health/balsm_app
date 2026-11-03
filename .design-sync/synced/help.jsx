/* help.jsx — Profile › Help & support */
const HELP_FAQ = [
  { q: { en: 'Where is my data stored?', ar: 'أين تُحفظ بياناتي؟' },
    a: { en: 'On this device by default. If you turn on sync, a copy is kept in the storage you choose in Profile › Storage. Nobody else can see it unless you share it.',
         ar: 'على هذا الجهاز افتراضيًا. إذا فعّلت المزامنة، تُحفظ نسخة في المكان الذي تختاره من الملف الشخصي › التخزين. لا يراها أحد إلا إذا شاركتها.' } },
  { q: { en: 'Does Balsm work without internet?', ar: 'هل يعمل بلسم بدون إنترنت؟' },
    a: { en: 'Yes. You can log readings, take medications and open your emergency card offline. Sync resumes on its own when you reconnect.',
         ar: 'نعم. يمكنك تسجيل القراءات وتناول الأدوية وفتح بطاقة الطوارئ بدون اتصال. تُستأنف المزامنة تلقائيًا عند عودة الاتصال.' } },
  { q: { en: 'How do I share my readings with my doctor?', ar: 'كيف أشارك قراءاتي مع طبيبي؟' },
    a: { en: 'Add your doctor in Profile › Care team, then turn on sharing in Privacy & data. You can also show your QR code at the clinic.',
         ar: 'أضف طبيبك من الملف الشخصي › فريق الرعاية، ثم فعّل المشاركة من الخصوصية والبيانات. يمكنك أيضًا عرض رمز QR في العيادة.' } },
  { q: { en: 'I forgot my password', ar: 'نسيت كلمة المرور' },
    a: { en: 'On the sign-in screen, tap "Forgot password?" and we’ll send a 6-digit code to your email.',
         ar: 'في شاشة تسجيل الدخول، انقر "نسيت كلمة المرور؟" وسنرسل رمزًا من 6 أرقام إلى بريدك.' } },
  { q: { en: 'How do I delete my account?', ar: 'كيف أحذف حسابي؟' },
    a: { en: 'Go to Profile › Privacy & data › Delete account. Your data is erased from this device and from any synced storage.',
         ar: 'من الملف الشخصي › الخصوصية والبيانات › حذف الحساب. تُمحى بياناتك من هذا الجهاز ومن أي تخزين متزامن.' } },
];

function HelpSupportScreen({ onBack }) {
  const { t, lang, setNavHidden } = useApp();
  const ar = lang === 'ar';
  useEffect(() => { setNavHidden(true); return () => setNavHidden(false); }, []);
  const [open, setOpen] = useState(null);
  const [report, setReport] = useState(false);
  const [msg, setMsg] = useState('');
  const [logs, setLogs] = useState(true);
  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState(false);
  const { Switch } = window.BalsmDesignSystem_1cf4c7 || {};

  const send = () => {
    if (!msg.trim() || sending) return;
    setSending(true);
    setTimeout(() => { setSending(false); setSent(true); setReport(false); setMsg(''); }, 900);
  };

  const Section = ({ icon, title }) => (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '18px 0 10px', color: 'var(--fg2)', fontWeight: 700, fontSize: 'var(--pt-sm)' }}>
      <Icon name={icon} size={16} style={{ color: 'var(--app-accent)' }} />{title}
    </div>
  );
  const Row = ({ icon, title, desc, onClick, href, last }) => {
    const inner = (<>
      <div style={{ width: 38, height: 38, borderRadius: 'var(--radius-md)', background: 'var(--balsm-ink-50)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <Icon name={icon} size={18} style={{ color: 'var(--fg2)' }} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontWeight: 600, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{title}</div>
        {desc && <div style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg3)', marginTop: 2 }}>{desc}</div>}
      </div>
      <Icon name={href ? 'external-link' : (ar ? 'chevron-left' : 'chevron-right')} size={href ? 16 : 18} style={{ color: 'var(--fg3)', flexShrink: 0 }} />
    </>);
    const st = { display: 'flex', alignItems: 'center', gap: 14, padding: '14px 16px', cursor: 'pointer', borderBottom: last ? 'none' : '1px solid var(--balsm-ink-100)', textDecoration: 'none', color: 'inherit' };
    return href ? <a href={href} target="_blank" rel="noopener" style={st}>{inner}</a> : <div onClick={onClick} style={st}>{inner}</div>;
  };

  return (
    <div className="screen fade-in">
      <div className="pad-top" />
      <div className="appbar">
        <button className="round-btn" onClick={onBack} aria-label={ar ? 'رجوع' : 'Back'}>
          <Icon name="arrow-left" style={{ transform: ar ? 'scaleX(-1)' : 'none' }} />
        </button>
        <h1 style={{ flex: 1, margin: 0, fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', letterSpacing: '-0.01em', color: 'var(--fg1)' }}>{t('p_help')}</h1>
      </div>
      <div className="screen-scroll" style={{ padding: '0 20px 28px' }}>

        <div className="card" style={{ display: 'flex', gap: 12, alignItems: 'flex-start', padding: 14, background: 'var(--balsm-danger-bg)', border: 'none', marginTop: 4 }}>
          <Icon name="siren" size={20} style={{ color: 'var(--balsm-danger)', flexShrink: 0, marginTop: 1 }} />
          <div style={{ flex: 1, fontSize: 'var(--pt-sm)', color: 'var(--fg1)', lineHeight: 1.5 }}>
            {ar ? 'بلسم ليس خدمة طوارئ. في حالة الطوارئ اتصل بالإسعاف على ' : 'Balsm isn’t an emergency service. In an emergency, call an ambulance on '}
            <a href="tel:123" dir="ltr" style={{ fontWeight: 700, color: 'var(--balsm-danger)' }}>123</a>.
          </div>
        </div>

        <Section icon="circle-help" title={ar ? 'الأسئلة الشائعة' : 'Common questions'} />
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          {HELP_FAQ.map((f, i) => {
            const on = open === i;
            return (
              <div key={i} style={{ borderBottom: i < HELP_FAQ.length - 1 ? '1px solid var(--balsm-ink-100)' : 'none' }}>
                <button type="button" onClick={() => setOpen(on ? null : i)} aria-expanded={on}
                  style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px', background: 'none', border: 'none', cursor: 'pointer', textAlign: 'start', fontFamily: 'inherit' }}>
                  <span style={{ flex: 1, fontWeight: 600, fontSize: 'var(--pt-md)', color: 'var(--fg1)', lineHeight: 1.4 }}>{f.q[lang]}</span>
                  <Icon name="chevron-down" size={18} style={{ color: 'var(--fg3)', flexShrink: 0, transform: on ? 'rotate(180deg)' : 'none', transition: 'transform var(--dur-fast) var(--ease-out)' }} />
                </button>
                {on && <div style={{ padding: '0 16px 16px', fontSize: 'var(--pt-sm)', color: 'var(--fg2)', lineHeight: 1.6 }}>{f.a[lang]}</div>}
              </div>
            );
          })}
        </div>

        <Section icon="message-circle" title={ar ? 'تواصل معنا' : 'Contact us'} />
        {sent && (
          <div role="status" className="card" style={{ display: 'flex', gap: 10, alignItems: 'center', padding: 12, marginBottom: 10, background: 'var(--petal-mint-50)', border: 'none' }}>
            <Icon name="circle-check" size={18} style={{ color: 'var(--petal-mint-600)', flexShrink: 0 }} />
            <span style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg1)' }}>{ar ? 'وصلتنا رسالتك. سنرد على بريدك خلال يومي عمل.' : 'We got your message. We’ll reply to your email within 2 working days.'}</span>
          </div>
        )}
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          {!report ? (
            <Row icon="bug" title={ar ? 'الإبلاغ عن مشكلة' : 'Report a problem'} desc={ar ? 'أخبرنا بما حدث وسنتابع معك' : 'Tell us what happened and we’ll follow up'} onClick={() => { setReport(true); setSent(false); }} />
          ) : (
            <div style={{ padding: 16, borderBottom: '1px solid var(--balsm-ink-100)', display: 'flex', flexDirection: 'column', gap: 12 }}>
              <div className="field" style={{ margin: 0 }}>
                <label>{ar ? 'ما الذي حدث؟' : 'What happened?'}</label>
                <textarea className="b-input" rows={4} autoFocus value={msg} onChange={e => setMsg(e.target.value)}
                  placeholder={ar ? 'مثال: لا تظهر قراءة الضغط بعد الحفظ' : 'e.g. My blood pressure reading doesn’t appear after saving'}
                  style={{ resize: 'vertical', minHeight: 96, fontFamily: 'inherit' }} />
              </div>
              {Switch && <Switch between checked={logs} onChange={() => setLogs(v => !v)}
                label={<span style={{ fontWeight: 600, fontSize: 'var(--pt-sm)', color: 'var(--fg1)' }}>{ar ? 'إرفاق معلومات الجهاز' : 'Include device info'}</span>}
                hint={<span style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg3)', lineHeight: 1.4 }}>{ar ? 'نسخة التطبيق ونوع الجهاز فقط. لا تُرسل أي بيانات صحية.' : 'App version and device type only. No health data is sent.'}</span>} />}
              <div style={{ display: 'flex', gap: 8 }}>
                <button className="b-btn b-btn-md b-btn-ghost" style={{ flex: 1 }} onClick={() => { setReport(false); setMsg(''); }}>{ar ? 'إلغاء' : 'Cancel'}</button>
                <button className={cx('b-btn b-btn-md b-btn-primary', (!msg.trim() || sending) && 'is-disabled')} disabled={!msg.trim() || sending} style={{ flex: 2 }} onClick={send}>
                  {sending ? (ar ? 'جارٍ الإرسال…' : 'Sending…') : (ar ? 'إرسال' : 'Send')}
                </button>
              </div>
            </div>
          )}
          <Row icon="mail" title={ar ? 'راسلنا عبر البريد' : 'Email us'} desc="support@balsm.health" href="mailto:support@balsm.health" />
          <Row icon="github" title={ar ? 'المجتمع على GitHub' : 'Community on GitHub'} desc={ar ? 'بلسم مفتوح المصدر. اقترح ميزة أو ساهم' : 'Balsm is open source. Suggest a feature or contribute'} href="https://github.com/balsm-health/Balsm-Core" last />
        </div>

        <div style={{ textAlign: 'center', marginTop: 24, fontSize: 'var(--pt-xs)', color: 'var(--fg4)', lineHeight: 1.6 }}>
          <div>Balsm.health · <span dir="ltr" style={{ fontFamily: 'var(--font-mono)' }}>v1.0.0 (build 42)</span></div>
          <div>{ar ? 'مفتوح المصدر' : 'Open source'}</div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { HelpSupportScreen });
