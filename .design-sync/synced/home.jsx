/* home.jsx — main app screens: Home, Trends, Meds, Profile */

const { Switch } = window.BalsmDesignSystem_51cdbf;

function LineChart({ series, rtl, yPad = 8, height = 96 }) {
  const W = 320, H = height;
  const all = series.flatMap(s => s.data);
  const min = Math.min(...all), max = Math.max(...all);
  const range = max - min || 1;
  const n = series[0].data.length;
  const x = (i) => { const r = n === 1 ? 0.5 : i / (n - 1); return (rtl ? 1 - r : r) * (W - 16) + 8; };
  const y = (v) => yPad + (1 - (v - min) / range) * (H - yPad * 2);
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} preserveAspectRatio="none" style={{ display: 'block', overflow: 'visible' }}>
      {[0.5].map(g => <line key={g} x1="0" x2={W} y1={H * g} y2={H * g} stroke="var(--balsm-ink-100)" strokeWidth="1" />)}
      {series.map((s, si) => {
        const pts = s.data.map((v, i) => `${x(i)},${y(v)}`).join(' ');
        return (
          <g key={si}>
            <polyline points={pts} fill="none" stroke={s.color} strokeWidth="2.5" strokeLinejoin="round" strokeLinecap="round" />
            {s.data.map((v, i) => <circle key={i} cx={x(i)} cy={y(v)} r={i === (rtl ? 0 : n - 1) ? 4 : 2.5} fill="#fff" stroke={s.color} strokeWidth="2" />)}
          </g>
        );
      })}
    </svg>
  );
}

/* ── Account switcher sheet ─────────────────────────────── */
function AccountSwitcherSheet({ onClose }) {
  const { t, lang, account, switchAccount, familyAccounts, addFamilyMember, linkRequests, approveLinkRequest, declineLinkRequest, cancelPendingLink } = useApp();
  const [adding, setAdding] = useState(false);

  const handleSwitch = (id) => { switchAccount(id); onClose(); };

  return (
    <>
      <style>{`@keyframes qlSlideUp{from{transform:translateY(110%)}to{transform:none}}`}</style>
      <div className="app-scrim" onClick={onClose} style={{ position: 'absolute', inset: 0, zIndex: 40, background: 'rgba(20,32,43,0.36)', backdropFilter: 'blur(2px)' }} />
      <div className="app-sheet" style={{
        position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 41,
        background: '#fff', borderRadius: '20px 20px 0 0',
        animation: 'qlSlideUp 0.3s cubic-bezier(0.16,1,0.3,1) both',
        paddingBottom: 38,
      }}>
        {/* Handle + title */}
        <div style={{ padding: '10px 20px 0' }}>
          <div className="sheet-grab" style={{ margin: '0 auto 12px' }} />
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: 12, borderBottom: '1px solid var(--balsm-ink-100)' }}>
            <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-lg)', color: 'var(--fg1)' }}>
              {t('your_accounts')}
            </div>
            <button className="round-btn ghost" onClick={onClose}><Icon name="x" size={17} /></button>
          </div>
        </div>

        {/* Accounts list */}
        <div style={{ padding: '4px 20px' }}>
          {familyAccounts.map((acc, idx) => {
            const isActive = acc.id === account.id;
            const pending = acc.status === 'pending';
            return (
              <div key={acc.id} onClick={() => !pending && handleSwitch(acc.id)} style={{
                display: 'flex', alignItems: 'center', gap: 14, padding: '13px 0',
                borderBottom: idx < familyAccounts.length - 1 ? '1px solid var(--balsm-ink-50)' : 'none',
                cursor: pending ? 'default' : 'pointer', opacity: pending ? 0.72 : 1,
              }}>
                <div style={{
                  width: 48, height: 48, borderRadius: 9999,
                  background: acc.color, color: '#fff', flexShrink: 0,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 16,
                  boxShadow: isActive && !pending ? `0 0 0 3px ${acc.color}33` : 'none',
                  transition: 'box-shadow 0.2s',
                }}>{acc.initials}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{acc.name[lang]}</div>
                  {pending ? (
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 4 }}>
                      <span className="b-badge b-badge--warning" style={{ gap: 5 }}><Icon name="clock" size={12} />{lang === 'ar' ? 'بانتظار الموافقة' : 'Awaiting approval'}</span>
                    </div>
                  ) : (
                    <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', marginTop: 3 }}>
                      {[
                        acc.relation[lang],
                        acc.age ? `${acc.age} ${lang === 'ar' ? 'سنة' : 'yrs'}` : '',
                        acc.conditions.length > 0 ? acc.conditions[0][lang] : '',
                      ].filter(Boolean).join(' · ')}
                    </div>
                  )}
                </div>
                {pending ? (
                  <button className="b-btn b-btn-md b-btn-ghost" style={{ flexShrink: 0, height: 34, padding: '0 10px', fontSize: 'var(--pt-xs)', color: 'var(--fg3)' }}
                    onClick={e => { e.stopPropagation(); cancelPendingLink(acc.id); }}>
                    {lang === 'ar' ? 'إلغاء' : 'Cancel'}
                  </button>
                ) : isActive && <Icon name="check-circle-2" size={22} style={{ color: 'var(--app-accent)', flexShrink: 0 }} />}
              </div>
            );
          })}
        </div>

        {/* Incoming link requests — someone asking to connect with you */}
        {linkRequests.length > 0 && (
          <div style={{ padding: '8px 20px 0' }}>
            <div style={{ fontSize: 'var(--pt-xs)', fontWeight: 700, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--fg3)', marginBottom: 10 }}>
              {lang === 'ar' ? 'طلبات الربط' : 'Link requests'}
            </div>
            {linkRequests.map(r => (
              <div key={r.id} style={{ padding: 14, background: 'var(--app-accent-50)', border: '1px solid var(--balsm-border)', borderRadius: 'var(--radius-lg)', marginBottom: 8 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{ width: 42, height: 42, borderRadius: 999, background: r.color, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 15, flexShrink: 0 }}>{r.initials}</div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{r.name[lang]}</div>
                    <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg2)', marginTop: 2 }}>{r.asks[lang]}</div>
                    <div style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg4)', marginTop: 3 }}>{r.relation[lang]} · {r.when[lang]}</div>
                  </div>
                </div>
                <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
                  <button className="b-btn b-btn-md b-btn-secondary" style={{ flex: 1 }} onClick={() => declineLinkRequest(r.id)}>
                    {lang === 'ar' ? 'رفض' : 'Decline'}
                  </button>
                  <button className="b-btn b-btn-md b-btn-primary" style={{ flex: 1, gap: 6 }} onClick={() => approveLinkRequest(r.id)}>
                    <Icon name="check" size={16} />{lang === 'ar' ? 'موافقة' : 'Approve'}
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Add family member */}
        <div style={{ padding: '12px 20px 0' }}>
          <button className="b-btn b-btn-md b-btn-secondary b-btn--full" style={{ height: 48 }} onClick={() => setAdding(true)}>
            <Icon name="user-plus" size={18} />{t('add_member')}
          </button>
        </div>
      </div>
      {adding && <AddFamilyMemberSheet onClose={() => setAdding(false)} onAdd={(vals) => { addFamilyMember(vals); setAdding(false); if (!vals.handle) onClose(); }} />}
    </>
  );
}

/* ── Add family member sheet ──────────────────────────────── */
const RELATIONS = [
  { en: 'Spouse', ar: 'الزوج/الزوجة' },
  { en: 'Son', ar: 'الابن' },
  { en: 'Daughter', ar: 'الابنة' },
  { en: 'Father', ar: 'الأب' },
  { en: 'Mother', ar: 'الأم' },
  { en: 'Sibling', ar: 'الأخ/الأخت' },
  { en: 'Grandparent', ar: 'الجد/الجدة' },
  { en: 'Other', ar: 'أخرى' },
];
/* Current user's handle — shared by Account details (editor) and Profile (QR share). */
const HANDLE_STORE = window.__balsmHandle || (window.__balsmHandle = { value: 'layla_hassan58' });

/* Handles that resolve when scanned — existing Balsm profiles */
const SCANNABLE = [
  { handle: 'omar.hassan',  name: { en: 'Omar Hassan',  ar: 'عمر حسن'   }, initials: 'OH', color: 'var(--petal-blue)',    dob: '1994-07-12', relation: { en: 'Son', ar: 'الابن' } },
  { handle: 'huda.mansour', name: { en: 'Huda Mansour', ar: 'هدى منصور' }, initials: 'HM', color: 'var(--petal-violet)',  dob: '1958-02-03', relation: { en: 'Mother', ar: 'الأم' } },
  { handle: 'samir.hassan', name: { en: 'Samir Hassan', ar: 'سمير حسن' }, initials: 'SH', color: 'var(--petal-emerald)', dob: '1962-11-28', relation: { en: 'Spouse', ar: 'الزوج/الزوجة' } },
];

/* Simulated QR viewfinder — resolves to a Balsm profile after a beat */
function QRScanView({ onFound, onManual }) {
  const { lang, familyAccounts } = useApp();
  const [state, setState] = useState('scanning');
  useEffect(() => {
    const taken = new Set(familyAccounts.map(a => a.handle).filter(Boolean));
    const pool = SCANNABLE.filter(p => !taken.has(p.handle));
    const hit = (pool.length ? pool : SCANNABLE)[Math.floor(Math.random() * (pool.length || SCANNABLE.length))];
    const id = setTimeout(() => { setState('found'); setTimeout(() => onFound(hit), 620); }, 2300);
    return () => clearTimeout(id);
  }, []);
  const brk = (c) => ({
    position: 'absolute', width: 42, height: 42,
    top: c[0] === 't' ? 26 : 'auto', bottom: c[0] === 'b' ? 26 : 'auto',
    left: c[1] === 'l' ? 26 : 'auto', right: c[1] === 'r' ? 26 : 'auto',
    borderTop: c[0] === 't' ? `3px solid ${state === 'found' ? 'var(--petal-mint)' : '#fff'}` : 'none',
    borderBottom: c[0] === 'b' ? `3px solid ${state === 'found' ? 'var(--petal-mint)' : '#fff'}` : 'none',
    borderLeft: c[1] === 'l' ? `3px solid ${state === 'found' ? 'var(--petal-mint)' : '#fff'}` : 'none',
    borderRight: c[1] === 'r' ? `3px solid ${state === 'found' ? 'var(--petal-mint)' : '#fff'}` : 'none',
    borderRadius: c === 'tl' ? '12px 0 0 0' : c === 'tr' ? '0 12px 0 0' : c === 'bl' ? '0 0 0 12px' : '0 0 12px 0',
    transition: 'border-color 200ms var(--ease-out)',
  });
  return (
    <div>
      <style>{`@keyframes scanLine{0%{top:8%}50%{top:88%}100%{top:8%}}@keyframes scanPulse{0%,100%{opacity:.45}50%{opacity:1}}`}</style>
      <div style={{ position: 'relative', aspectRatio: '1 / 1', borderRadius: 'var(--radius-xl)', overflow: 'hidden', background: 'var(--balsm-ink-800)' }}>
        <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(120% 90% at 50% 40%, #2C3A47 0%, #14202B 100%)' }} />
        {['tl', 'tr', 'bl', 'br'].map(c => <span key={c} style={brk(c)} />)}
        {state === 'scanning' && (
          <div style={{ position: 'absolute', left: 26, right: 26, height: 2, background: 'linear-gradient(90deg, transparent, var(--petal-aqua), transparent)', animation: 'scanLine 2.2s var(--ease-out) infinite, scanPulse 1.1s ease-in-out infinite' }} />
        )}
        {state === 'found' && (
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <div style={{ width: 62, height: 62, borderRadius: 999, background: 'var(--petal-mint)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="check" size={32} stroke={2.6} />
            </div>
          </div>
        )}
        <div style={{ position: 'absolute', insetInline: 0, bottom: 0, padding: '28px 22px 18px', background: 'linear-gradient(transparent, rgba(20,32,43,0.85))', color: '#fff', textAlign: 'center', fontSize: 'var(--pt-sm)', fontWeight: 500 }}>
          {state === 'found'
            ? (lang === 'ar' ? 'تم التعرّف على الرمز' : 'Code recognised')
            : (lang === 'ar' ? 'وجّه الكاميرا إلى رمز بلسم الخاص بهم' : 'Point the camera at their Balsm QR code')}
        </div>
      </div>
      <p className="body" style={{ margin: '14px 2px 0', fontSize: 'var(--pt-sm)', color: 'var(--fg3)' }}>
        {lang === 'ar' ? 'يجد كل فرد رمزه في الملف الشخصي ← رمز المشاركة.' : 'They can find their code in Profile → My QR code.'}
      </p>
      <button className="b-btn b-btn-md b-btn-ghost b-btn--full" style={{ marginTop: 10 }} onClick={onManual}>
        {lang === 'ar' ? 'الإدخال يدويًا بدلاً من ذلك' : 'Enter details manually instead'}
      </button>
    </div>
  );
}
function AddFamilyMemberSheet({ onClose, onAdd }) {
  const { t, lang } = useApp();
  const [mode, setMode] = useState('choose'); // choose | scan | found | manual
  const [found, setFound] = useState(null);
  const [name, setName] = useState('');
  const [relation, setRelation] = useState('');
  const [dob, setDob] = useState('');
  const [dobOpen, setDobOpen] = useState(false);
  const canSave = name.trim().length > 1;
  const acceptScan = (p) => {
    setFound(p); setName(p.name[lang] || p.name.en);
    setRelation(p.relation[lang] || p.relation.en); setDob(p.dob); setMode('found');
  };
  const sheetTitle = mode === 'scan' ? (lang === 'ar' ? 'مسح رمز QR' : 'Scan QR code')
    : mode === 'found' ? (lang === 'ar' ? 'تأكيد الإضافة' : 'Confirm member')
    : t('add_member');
  return (
    <>
      <div className="app-scrim" onClick={onClose} style={{ position: 'absolute', inset: 0, zIndex: 50, background: 'rgba(20,32,43,0.36)', backdropFilter: 'blur(2px)' }} />
      <div className="app-sheet" style={{
        position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 51,
        background: '#fff', borderRadius: '20px 20px 0 0',
        animation: 'qlSlideUp 0.3s cubic-bezier(0.16,1,0.3,1) both',
        padding: '10px 20px 32px',
      }}>
        <div className="sheet-grab" style={{ margin: '0 auto 12px' }} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: 12, borderBottom: '1px solid var(--balsm-ink-100)', marginBottom: 16 }}>
          <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-lg)', color: 'var(--fg1)' }}>
            {sheetTitle}
          </div>
          <button className="round-btn ghost" onClick={onClose}><Icon name="x" size={17} /></button>
        </div>
        {mode === 'choose' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <button onClick={() => setMode('scan')} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: 16, background: '#fff', border: '1px solid var(--balsm-border)', borderRadius: 'var(--radius-lg)', cursor: 'pointer', textAlign: 'start', font: 'inherit' }}>
              <div style={{ width: 44, height: 44, borderRadius: 'var(--radius-md)', background: 'var(--app-accent-50)', color: 'var(--app-accent)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <Icon name="qr-code" size={22} />
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{lang === 'ar' ? 'مسح رمز QR الخاص بهم' : 'Scan their QR code'}</div>
                <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', marginTop: 2 }}>{lang === 'ar' ? 'اربط حسابًا موجودًا على بلسم في ثوانٍ.' : 'Link an existing Balsm account in seconds.'}</div>
              </div>
              <span className="rchev"><Icon name="chevron-right" size={18} /></span>
            </button>
            <button onClick={() => setMode('manual')} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: 16, background: '#fff', border: '1px solid var(--balsm-border)', borderRadius: 'var(--radius-lg)', cursor: 'pointer', textAlign: 'start', font: 'inherit' }}>
              <div style={{ width: 44, height: 44, borderRadius: 'var(--radius-md)', background: 'var(--balsm-ink-50)', color: 'var(--fg2)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <Icon name="pencil-line" size={21} />
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{lang === 'ar' ? 'الإدخال يدويًا' : 'Enter details manually'}</div>
                <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', marginTop: 2 }}>{lang === 'ar' ? 'لمن لا يملك حسابًا بعد.' : "For someone who doesn't have an account yet."}</div>
              </div>
              <span className="rchev"><Icon name="chevron-right" size={18} /></span>
            </button>
          </div>
        )}
        {mode === 'scan' && <QRScanView onFound={acceptScan} onManual={() => setMode('manual')} />}
        {mode === 'found' && found && (
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: 16, background: 'var(--petal-mint-50)', border: '1px solid var(--balsm-border)', borderRadius: 'var(--radius-lg)' }}>
              <div style={{ width: 48, height: 48, borderRadius: 999, background: found.color, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 16, flexShrink: 0 }}>{found.initials}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{found.name[lang]}</div>
                <div dir="ltr" style={{ fontFamily: 'var(--font-mono)', fontSize: 'var(--pt-sm)', color: 'var(--app-accent)', marginTop: 2, textAlign: 'start' }}>@{found.handle}</div>
              </div>
              <Icon name="badge-check" size={22} style={{ color: 'var(--petal-mint-600)', flexShrink: 0 }} />
            </div>
            <div className="field" style={{ marginTop: 16 }}>
              <label>{lang === 'ar' ? 'صلة القرابة' : 'Relation'}</label>
              <select className="b-input" value={relation} onChange={e => setRelation(e.target.value)}>
                {RELATIONS.map(r => <option key={r.en} value={lang === 'ar' ? r.ar : r.en}>{lang === 'ar' ? r.ar : r.en}</option>)}
              </select>
            </div>
            <p className="body" style={{ margin: '14px 2px 0', fontSize: 'var(--pt-sm)', color: 'var(--fg3)' }}>
              {lang === 'ar' ? 'سنطلب موافقتهم قبل ظهور أي بيانات صحية — سيرى الطلب في تطبيقه ويوافق عليه مرة واحدة.' : 'They see the request in their own Balsm app and approve it once — no health data appears until they do.'}
            </p>
            <button className="b-btn b-btn-lg b-btn-primary b-btn--full" style={{ marginTop: 18 }}
              onClick={() => onAdd({ name: name.trim(), relation: relation.trim(), dob: dob || null, handle: found.handle, status: 'pending' })}>
              {lang === 'ar' ? 'إرسال طلب الربط' : 'Send link request'}
            </button>
            <button className="b-btn b-btn-md b-btn-ghost b-btn--full" style={{ marginTop: 8 }} onClick={() => setMode('scan')}>
              {lang === 'ar' ? 'مسح رمز آخر' : 'Scan a different code'}
            </button>
          </div>
        )}
        {mode === 'manual' && (
        <React.Fragment>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div className="field">
            <label>{lang === 'ar' ? 'الاسم' : 'Name'}</label>
            <input className="b-input" value={name} onChange={e => setName(e.target.value)} placeholder={lang === 'ar' ? 'اسم فرد الأسرة' : "Family member's name"} autoFocus />
          </div>
          <div className="field">
            <label>{lang === 'ar' ? 'صلة القرابة' : 'Relation'}</label>
            <select className="b-input" value={relation} onChange={e => setRelation(e.target.value)}>
              <option value="" disabled>{lang === 'ar' ? 'اختر صلة القرابة' : 'Select a relation'}</option>
              {RELATIONS.map(r => <option key={r.en} value={lang === 'ar' ? r.ar : r.en}>{lang === 'ar' ? r.ar : r.en}</option>)}
            </select>
          </div>
          <div className="field">
            <label>{lang === 'ar' ? 'تاريخ الميلاد' : 'Date of birth'}</label>
            <button type="button" className="b-input" onClick={() => setDobOpen(true)}
              style={{ display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer', textAlign: 'start' }}>
              <Icon name="calendar" size={17} style={{ color: 'var(--fg3)', flexShrink: 0 }} />
              <span className={dob ? 'num' : ''} style={{ flex: 1, color: dob ? 'var(--fg1)' : 'var(--fg3)', direction: 'ltr', textAlign: 'start' }}>
                {dob ? fmtDob(dob, lang) : (lang === 'ar' ? 'يوم / شهر / سنة' : 'DD / MM / YYYY')}
              </span>
              <Icon name="chevron-down" size={15} style={{ color: 'var(--fg3)', flexShrink: 0 }} />
            </button>
          </div>
        </div>
        <button className={cx('b-btn b-btn-lg b-btn-primary b-btn--full', !canSave && 'is-disabled')} style={{ marginTop: 20 }}
          onClick={() => canSave && onAdd({ name: name.trim(), relation: relation.trim(), dob: dob || null })}>
          {lang === 'ar' ? 'إضافة' : 'Add member'}
        </button>
        <button className="b-btn b-btn-md b-btn-ghost b-btn--full" style={{ marginTop: 8 }} onClick={() => setMode('scan')}>
          <Icon name="qr-code" size={17} />{lang === 'ar' ? 'مسح رمز QR بدلاً من ذلك' : 'Scan a QR code instead'}
        </button>
        </React.Fragment>
        )}
        {dobOpen && (
          <DobPicker lang={lang} value={dob} title={lang === 'ar' ? 'تاريخ الميلاد' : 'Date of birth'}
            onPick={iso => setDob(iso)} onClose={() => setDobOpen(false)} />
        )}
      </div>
    </>
  );
}

/* ── Home screen ─────────────────────────────────────────── */
function HomeScreen() {
  const { t, lang, openFlow, setTab, today, account, country, openCareTeam } = useApp();
  const [switcherOpen, setSwitcherOpen] = useState(false);
  const [dayOpen, setDayOpen] = useState(null);
  if (dayOpen) return <DayRecordsScreen h={dayOpen} onBack={() => setDayOpen(null)} />;

  const checkedIn = !!today;
  const cur = today || { bp: HISTORY[0].bp, glu: HISTORY[0].glu, mood: HISTORY[0].mood, pain: HISTORY[0].pain };
  const moodLbl = cur.mood ? t('mood_' + cur.mood) : '—';

  const metrics = [
    { icon: 'activity',    lab: t('m_bp'),      val: cur.bp || '—',       unit: t('unit_bp'),  foot: t('bp_normal'), tone: 'down' },
    { icon: 'droplet',     lab: t('m_glucose'),  val: cur.glu || '—',      unit: t('unit_glu'), foot: t('bp_high'),   tone: 'up'   },
    { icon: 'wind',        lab: t('m_o2'),       val: cur.o2 || '98',      unit: '%',           foot: '',             tone: ''     },
    { icon: 'smile',       lab: t('m_mood'),     val: moodLbl,             unit: '',            foot: '',             tone: ''     },
    { icon: 'thermometer', lab: t('m_pain'),     val: (cur.pain ?? 0) + '/10', unit: '',        foot: '',             tone: ''     },
  ];

  return (
    <React.Fragment>
      <div className="screen-scroll fade-in">
        <div className="pad-top" />

        {/* App bar */}
        <div className="appbar">
          <button
            className="avatar"
            style={{ background: account.color, border: 'none', cursor: 'pointer', position: 'relative' }}
            onClick={() => setSwitcherOpen(true)}
            aria-label={t('switch_account')}
          >
            {account.initials}
            {/* Multi-account indicator dot */}
            {FAMILY_ACCOUNTS.length > 1 && (
              <div style={{
                position: 'absolute', bottom: -1, right: -1,
                width: 14, height: 14, borderRadius: 99,
                background: '#fff', border: '1.5px solid #fff',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <div style={{ width: 8, height: 8, borderRadius: 99, background: 'var(--app-accent)' }} />
              </div>
            )}
          </button>
          <div className="grow">
            <div className="meta">{t('greet')}</div>
            <h1 style={{ fontSize: 'var(--pt-xl)' }}>{account.name[lang].split(' ')[0]}</h1>
          </div>
          <button className="round-btn" aria-label="Reminders"><Icon name="bell" /></button>
        </div>

        {/* Travel banner */}
        {country && !country.home && (
          <div style={{
            margin: '0 20px 14px', padding: '12px 16px', borderRadius: 'var(--radius-lg)',
            background: 'var(--balsm-sun-500)', color: '#3A2E05',
            display: 'flex', alignItems: 'center', gap: 12,
          }}>
            <Icon name="plane" size={20} style={{ flexShrink: 0 }} />
            <div className="grow" style={{ lineHeight: 1.35 }}>
              <div style={{ fontWeight: 700, fontSize: 'var(--pt-sm)' }}>{t('away_banner')} · {country.name[lang]}</div>
              <div style={{ fontSize: 'var(--pt-xs)', opacity: 0.85 }}>{t('emergency')} <b className="num">{country.emergency}</b></div>
            </div>
            <button className="round-btn" onClick={() => setTab('profile')} style={{ background: 'rgba(58,46,5,0.12)', flexShrink: 0 }} aria-label={t('p_country')}>
              <Icon name="chevron-right" size={18} style={{ color: '#3A2E05', transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
            </button>
          </div>
        )}

        {/* Hero check-in */}
        {!checkedIn ? (
          <div className="hero-card">
            <img className="petal-wm" src={window.__resources ? window.__resources['icon-mono-white'] : 'assets/icon-mono-white.svg?v=7'} alt="" />
            <div className="label">{t('today_lbl')}</div>
            <div className="h" style={{ textWrap: 'balance' }}>{t('hero_q')}</div>
            <div style={{ fontSize: 'var(--pt-xs)', opacity: 0.85, marginTop: 2 }}>{lang === 'ar' ? 'تقييمك الخاص — لا يعتمد على قياس طبي' : 'Your own self-report — not a clinical measurement'}</div>
            <div className="cta" onClick={openFlow} style={{ whiteSpace: 'nowrap' }}>
              <Icon name="plus-circle" size={20} />{t('hero_cta')}
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 12, fontSize: 'var(--pt-sm)', opacity: 0.9 }}>
              <Icon name="clock" size={15} />{t('hero_time')}
            </div>
          </div>
        ) : (
          <div className="hero-card done">
            <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
              <div className="confirm-mark" style={{ width: 52, height: 52, margin: 0 }}><Icon name="check" size={28} /></div>
              <div className="grow">
                <div className="label">{t('done_lbl')}</div>
                <div className="subhead" style={{ marginTop: 2 }}>{t('done_q')}</div>
              </div>
              <button className="round-btn" onClick={() => setTab('trends')}>
                <Icon name="chevron-right" style={{ transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
              </button>
            </div>
          </div>
        )}

        {/* Streak */}
        <div className="card" style={{ margin: '14px 20px 0', padding: 16 }}>
          <div className="streak">
            <div className="ring">
              <svg width="56" height="56">
                <circle cx="28" cy="28" r="24" fill="none" stroke="var(--balsm-ink-100)" strokeWidth="6" />
                <circle cx="28" cy="28" r="24" fill="none" stroke="var(--app-accent)" strokeWidth="6" strokeLinecap="round"
                  strokeDasharray={2 * Math.PI * 24} strokeDashoffset={2 * Math.PI * 24 * (1 - 6 / 7)} />
              </svg>
              <div className="rtxt">6</div>
            </div>
            <div className="grow">
              <div className="subhead" style={{ fontSize: 'var(--pt-md)' }}><b className="num">6</b> {t('streak')}</div>
              <div className="meta" style={{ marginTop: 2 }}>{t('streak_help')}</div>
            </div>
            <Icon name="flame" size={24} style={{ color: 'var(--balsm-sun-500)' }} />
          </div>
        </div>

        {/* Care team shortcut */}
        <div className="card" style={{ margin: '14px 20px 0', padding: '13px 16px', display: 'flex', alignItems: 'center', gap: 13, cursor: 'pointer' }}
          onClick={openCareTeam}>
          <div style={{ width: 38, height: 38, borderRadius: 'var(--radius-md)', background: 'var(--petal-mint-50)', color: 'var(--petal-mint)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Icon name="stethoscope" size={19} />
          </div>
          <div className="grow">
            <div style={{ fontSize: 'var(--pt-md)', fontWeight: 600, color: 'var(--fg1)' }}>{lang === 'ar' ? 'فريق الرعاية' : 'Care team'}</div>
            <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', marginTop: 1 }}>{DOCTORS.length} {lang === 'ar' ? 'مقدّم رعاية يتابع حالتك' : 'providers following your care'}</div>
          </div>
          <Icon name="chevron-right" size={18} style={{ color: 'var(--fg4)', flexShrink: 0, transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
        </div>

        {/* Nearby care shortcut */}
        <div className="card" style={{ margin: '14px 20px 0', padding: '13px 16px', display: 'flex', alignItems: 'center', gap: 13, cursor: 'pointer' }}
          onClick={() => setTab('map')}>
          <div style={{ width: 38, height: 38, borderRadius: 'var(--radius-md)', background: 'var(--petal-blue-50)', color: 'var(--petal-blue)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Icon name="map-pin" size={19} />
          </div>
          <div className="grow">
            <div style={{ fontSize: 'var(--pt-md)', fontWeight: 600, color: 'var(--fg1)' }}>{t('map_nearby')}</div>
            <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', marginTop: 1 }}>{HEALTH_ENTITIES.length} {lang === 'ar' ? 'مكان بالقرب منك' : 'places mapped nearby'}</div>
          </div>
          <Icon name="chevron-right" size={18} style={{ color: 'var(--fg4)', flexShrink: 0, transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
        </div>

        {/* Health records shortcut */}
        <div className="card" style={{ margin: '14px 20px 0', padding: '13px 16px', display: 'flex', alignItems: 'center', gap: 13, cursor: 'pointer' }}
          onClick={() => setTab('records')}>
          <div style={{ width: 38, height: 38, borderRadius: 'var(--radius-md)', background: 'var(--petal-violet-50)', color: 'var(--petal-violet)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Icon name="folder-heart" size={19} />
          </div>
          <div className="grow">
            <div style={{ fontSize: 'var(--pt-md)', fontWeight: 600, color: 'var(--fg1)' }}>{t('records')}</div>
            <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', marginTop: 1 }}>{HEALTH_RECORDS.length} {lang === 'ar' ? 'مستند' : 'documents'}</div>
          </div>
          <Icon name="chevron-right" size={18} style={{ color: 'var(--fg4)', flexShrink: 0, transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
        </div>

        {/* Latest readings */}
        <div className="row-head"><h2>{t('latest')}</h2></div>
        <div className="metric-grid">
          {metrics.map((m, i) => (
            <div key={i} className="metric">
              <div className="mlab"><Icon name={m.icon} size={15} />{m.lab}</div>
              <div className="mval" dir={/[0-9]/.test(String(m.val)) ? 'ltr' : undefined}
                style={{ textAlign: lang === 'ar' && /[0-9]/.test(String(m.val)) ? 'right' : undefined }}>
                {m.val}{m.unit && <span className="unit">{m.unit}</span>}
              </div>
              {m.foot && (
                <div className={cx('mfoot', m.tone)}>
                  {m.tone && <Icon name={m.tone === 'up' ? 'arrow-up-right' : 'arrow-down-right'} size={14} />}{m.foot}
                </div>
              )}
            </div>
          ))}
        </div>

        {/* Recent reports */}
        <div className="row-head"><h2>{t('recent')}</h2><a onClick={() => setTab('trends')}>{t('see_all')}</a></div>
        <div className="card" style={{ margin: '0 20px' }}>
          {HISTORY.slice(0, 3).map((h, i) => <HistoryRow key={i} h={h} onClick={() => setDayOpen(h)} />)}
        </div>

        <div style={{ height: 24 }} />
      </div>

      {switcherOpen && <AccountSwitcherSheet onClose={() => setSwitcherOpen(false)} />}
    </React.Fragment>
  );
}

function HistoryRow({ h, onClick }) {
  const { t, lang } = useApp();
  const pinfo = h.pain <= 3 ? 'b-badge--success' : h.pain <= 6 ? 'b-badge--warning' : 'b-badge--danger';
  return (
    <div className="history-row" onClick={onClick}>
      <div className="h-date">
        <div className="d num">{h.d}</div>
        <div className="m">{h.m[lang]}</div>
      </div>
      <div className="grow">
        <div className="hsummary">
          <Icon name="activity" size={14} style={{ color: 'var(--petal-violet)' }} /><span className="num" dir="ltr">{h.bp}</span>
          <span style={{ color: 'var(--balsm-ink-300)' }}>·</span>
          <Icon name="droplet" size={14} style={{ color: 'var(--petal-mint-600)' }} /><span className="num">{h.glu}</span>
        </div>
      </div>
      <MoodFace level={h.mood} size={26} color={MOOD_COLORS[h.mood - 1]} />
      <span className={cx('b-badge', pinfo)} style={{ padding: '3px 8px' }}><span className="num">{h.pain}</span></span>
    </div>
  );
}

/* ── Day records (single day detail) ───────────────────────── */
function DayRecordsScreen({ h, onBack }) {
  const { t, lang } = useApp();
  const atts = DAY_ATTACHMENTS[h.d] || {};
  const rows = [
    { key: 'bp',   icon: 'activity',    lab: t('m_bp'),      val: h.bp,                 unit: t('unit_bp'), time: '08:15 AM', color: 'var(--petal-violet)',   bg: 'var(--petal-violet-50)' },
    { key: 'glu',  icon: 'droplet',     lab: t('m_glucose'), val: h.glu,                unit: t('unit_glu'), time: '08:20 AM', color: 'var(--petal-mint-600)', bg: 'var(--petal-mint-50)' },
    { key: 'pain', icon: 'zap',         lab: t('m_pain'),    val: h.pain + '/10',       unit: '',            time: '07:40 PM', color: 'var(--balsm-danger)',   bg: 'var(--balsm-danger-bg)' },
  ];
  return (
    <div className="screen-scroll fade-in">
      <div className="pad-top" />
      <div className="appbar">
        <button className="round-btn" onClick={onBack} aria-label="Back">
          <Icon name="arrow-left" style={{ transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
        </button>
        <h1 className="grow">{h.d} {h.m[lang]}</h1>
      </div>
      <div className="card" style={{
        margin: '4px 20px 16px', padding: 16, display: 'flex', alignItems: 'center', gap: 14,
        background: 'linear-gradient(135deg, var(--app-accent-50), var(--balsm-surface) 65%)',
        border: '1px solid var(--app-accent-50)',
      }}>
        <MoodFace level={h.mood} size={40} color={MOOD_COLORS[h.mood - 1]} />
        <div className="grow">
          <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{t('mood_' + h.mood)}</div>
          <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)' }}>{t('m_mood')}</div>
        </div>
        <div className="meta" style={{ display: 'flex', alignItems: 'center', gap: 5, flexShrink: 0 }}>
          <Icon name="clock" size={13} />07:00 AM
        </div>
      </div>
      <div className="card" style={{ margin: '0 20px', padding: 0 }}>
        {rows.map((r, i) => (
          <div key={r.lab} style={{ borderBottom: i < rows.length - 1 ? '1px solid var(--balsm-ink-50)' : 'none' }}>
            <div className="med-row" style={{ borderBottom: 'none' }}>
              <div className="med-ico" style={{ background: r.bg, color: r.color }}><Icon name={r.icon} /></div>
              <div className="grow">
                <div className="mname">{r.lab}</div>
                <div className="meta" style={{ display: 'flex', alignItems: 'center', gap: 5, marginTop: 2 }}><Icon name="clock" size={12} />{r.time}</div>
              </div>
              <div className="num" style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{r.val} <span style={{ fontWeight: 500, fontSize: 'var(--pt-xs)', color: 'var(--fg4)' }}>{r.unit}</span></div>
            </div>
            {atts[r.key] && (
              <div style={{ padding: '0 16px 14px' }}>
                <AttachmentGallery atts={[].concat(atts[r.key])} height={120} />
              </div>
            )}
          </div>
        ))}
      </div>
      {h.sym > 0 && (
        <div className="card" style={{ margin: '14px 20px 0', padding: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '13px 16px' }}>
            <div style={{ width: 38, height: 38, borderRadius: 'var(--radius-md)', background: '#FDF5DC', color: '#9A6E00', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <Icon name="stethoscope" size={19} />
            </div>
            <div className="grow">
              <div style={{ fontWeight: 600, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{h.sym} {t('symptoms').toLowerCase()}</div>
              <div className="meta" style={{ display: 'flex', alignItems: 'center', gap: 5, marginTop: 2 }}><Icon name="clock" size={12} />09:30 PM</div>
            </div>
          </div>
          {atts.sym && <div style={{ padding: '0 16px 14px' }}><AttachmentGallery atts={[].concat(atts.sym)} height={120} /></div>}
        </div>
      )}
      {/* mood attachment, if one was saved with the check-in */}
      <div style={{ height: 24 }} />
    </div>
  );
}

/* ── Trends ──────────────────────────────────────────────── */
function TrendsScreen() {
  const { t, lang, setTab } = useApp();
  const [range, setRange] = useState('range_w');
  const [dayOpen, setDayOpen] = useState(null);
  const ALL_METRICS = ['m_bp', 'm_glucose', 'm_pain', 'm_weight'];
  const [visible, setVisible] = useState(new Set(ALL_METRICS));
  const toggleMetric = (id) => setVisible(prev => {
    const n = new Set(prev);
    if (n.has(id)) { if (n.size > 1) n.delete(id); } else n.add(id);
    return n;
  });
  const [metricsOpen, setMetricsOpen] = useState(false);
  const metricsRef = useRef(null);
  useEffect(() => {
    if (!metricsOpen) return;
    const onDoc = (e) => { if (metricsRef.current && !metricsRef.current.contains(e.target)) setMetricsOpen(false); };
    document.addEventListener('mousedown', onDoc);
    return () => document.removeEventListener('mousedown', onDoc);
  }, [metricsOpen]);
  const rtl = lang === 'ar';
  if (dayOpen) return <DayRecordsScreen h={dayOpen} onBack={() => setDayOpen(null)} />;
  return (
    <div className="screen-scroll fade-in">
      <div className="pad-top" />
      <div className="appbar">
        <button className="round-btn" onClick={() => setTab('home')} aria-label="Back">
          <Icon name="arrow-left" style={{ transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
        </button>
        <h1 className="grow">{t('trends')}</h1>
        <div className="range-tabs">
          {['range_w','range_m','range_3m'].map(r => <button key={r} className={cx(range===r&&'on')} onClick={() => setRange(r)}>{t(r)}</button>)}
        </div>
      </div>
      <div style={{ position: 'relative', padding: '0 20px 14px' }} ref={metricsRef}>
        <button onClick={() => setMetricsOpen(v => !v)} style={{
          display: 'flex', alignItems: 'center', gap: 8, height: 40, padding: '0 14px', borderRadius: 'var(--radius-md)',
          border: '1.5px solid var(--balsm-border)', background: '#fff', color: 'var(--fg1)', fontWeight: 600, fontSize: 'var(--pt-sm)', cursor: 'pointer',
          fontFamily: lang === 'ar' ? 'var(--font-arabic)' : 'var(--font-body)',
        }}>
          <Icon name="sliders-horizontal" size={15} style={{ color: 'var(--fg3)' }} />
          <span className="grow" style={{ textAlign: 'start' }}>
            {visible.size === ALL_METRICS.length ? (lang === 'ar' ? 'كل المقاييس' : 'All metrics') : `${visible.size} ${lang === 'ar' ? 'من المقاييس' : 'metrics'}`}
          </span>
          <Icon name="chevron-down" size={15} style={{ color: 'var(--fg3)', transform: metricsOpen ? 'rotate(180deg)' : 'none', transition: 'transform var(--dur-fast) var(--ease-out)' }} />
        </button>
        {metricsOpen && (
          <div style={{
            position: 'absolute', top: 46, insetInlineStart: 0, zIndex: 20, minWidth: 210,
            background: '#fff', borderRadius: 'var(--radius-lg)', border: '1px solid var(--balsm-border)',
            boxShadow: 'var(--shadow-md, 0 8px 24px rgba(20,32,43,0.14))', padding: 6,
          }}>
            {ALL_METRICS.map(id => (
              <div key={id} onClick={() => toggleMetric(id)} style={{
                display: 'flex', alignItems: 'center', gap: 10, padding: '10px 10px', borderRadius: 'var(--radius-sm)', cursor: 'pointer',
              }}>
                <span style={{
                  width: 18, height: 18, borderRadius: 5, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
                  border: visible.has(id) ? 'none' : '1.5px solid var(--balsm-border-strong)',
                  background: visible.has(id) ? 'var(--app-accent)' : 'transparent',
                }}>
                  {visible.has(id) && <Icon name="check" size={12} style={{ color: '#fff' }} />}
                </span>
                <span style={{ fontSize: 'var(--pt-sm)', fontWeight: 500, color: 'var(--fg1)' }}>{t(id)}</span>
              </div>
            ))}
          </div>
        )}
      </div>
      {visible.has('m_bp') && <div className="card chart-card">
        <div className="chart-head">
          <span className="ctitle">{t('m_bp')}</span>
          <span className="cval">{t('avg')} <b className="num" style={{ color: 'var(--fg1)' }}>131/84</b> {t('unit_bp')}</span>
        </div>
        <LineChart rtl={rtl} series={[{ data: TREND_BP_SYS, color: 'var(--petal-violet)' }, { data: TREND_BP_DIA, color: 'var(--petal-blue)' }]} />
        <div style={{ display: 'flex', gap: 16, marginTop: 10 }}>
          <span className="meta" style={{ display: 'flex', alignItems: 'center', gap: 6 }}><span style={{ width: 8, height: 8, borderRadius: 99, background: 'var(--petal-violet)', display: 'inline-block' }} />{t('sys')}</span>
          <span className="meta" style={{ display: 'flex', alignItems: 'center', gap: 6 }}><span style={{ width: 8, height: 8, borderRadius: 99, background: 'var(--petal-blue)', display: 'inline-block' }} />{t('dia')}</span>
        </div>
      </div>}
      {visible.has('m_glucose') && <div className="card chart-card" style={{ marginTop: 14 }}>
        <div className="chart-head">
          <span className="ctitle">{t('m_glucose')}</span>
          <span className="cval">{t('avg')} <b className="num" style={{ color: 'var(--fg1)' }}>144</b> {t('unit_glu')}</span>
        </div>
        <LineChart rtl={rtl} series={[{ data: TREND_GLU, color: 'var(--petal-mint-600)' }]} />
      </div>}
      {visible.has('m_pain') && <div className="card chart-card" style={{ marginTop: 14 }}>
        <div className="chart-head">
          <span className="ctitle">{t('m_pain')}</span>
          <span className="cval">{t('avg')} <b className="num" style={{ color: 'var(--fg1)' }}>{(TREND_PAIN.reduce((a,b)=>a+b,0)/TREND_PAIN.length).toFixed(1)}</b>/10</span>
        </div>
        <LineChart rtl={rtl} series={[{ data: TREND_PAIN, color: 'var(--balsm-danger)' }]} />
      </div>}
      {visible.has('m_weight') && <div className="card chart-card" style={{ marginTop: 14 }}>
        <div className="chart-head">
          <span className="ctitle">{t('m_weight')}</span>
          <span className="cval"><b className="num" style={{ color: 'var(--fg1)' }}>{TREND_WEIGHT[TREND_WEIGHT.length-1]}</b> kg</span>
        </div>
        <LineChart rtl={rtl} series={[{ data: TREND_WEIGHT, color: 'var(--petal-blue)' }]} />
      </div>}
      <div className="row-head"><h2>{t('reports')}</h2></div>
      <div className="card" style={{ margin: '0 20px' }}>
        {HISTORY.map((h, i) => <HistoryRow key={i} h={h} onClick={() => setDayOpen(h)} />)}
      </div>
      <div style={{ height: 24 }} />
    </div>
  );
}

/* ── Meds ────────────────────────────────────────────────── */
function MedsScreen() {
  const { t, lang } = useApp();
  const [rxOpen, setRxOpen] = useState(false);
  if (rxOpen) return <PrescriptionsScreen onBack={() => setRxOpen(false)} />;

  const groups = [
    { key: 'morning', icon: 'sunrise', meds: MEDS.filter(m => m.when === 'morning') },
    { key: 'evening', icon: 'moon',    meds: MEDS.filter(m => m.when === 'evening') },
  ];
  const activeRxCount = PRESCRIPTIONS.filter(r => r.status === 'active').length;

  return (
    <div className="screen-scroll fade-in">
      <div className="pad-top" />
      <div className="appbar">
        <div className="grow">
          <h1 style={{ marginBottom: 2 }}>{t('medications')}</h1>
          <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)' }}>{lang === 'ar' ? 'نظامك اليومي' : 'Your daily regimen'}</div>
        </div>
      </div>

      <div className="card" style={{
        margin: '4px 20px 16px', padding: 20, display: 'flex', alignItems: 'center', gap: 18,
        background: 'linear-gradient(135deg, var(--petal-mint-50), var(--balsm-surface) 65%)',
        border: '1px solid var(--petal-mint-50)',
      }}>
        <div className="ring" style={{ position: 'relative', flexShrink: 0 }}>
          <svg width="68" height="68">
            <circle cx="34" cy="34" r="29" fill="none" stroke="var(--balsm-ink-100)" strokeWidth="7" />
            <circle cx="34" cy="34" r="29" fill="none" stroke="var(--petal-mint)" strokeWidth="7" strokeLinecap="round"
              strokeDasharray={2 * Math.PI * 29} strokeDashoffset={2 * Math.PI * 29 * (1 - 0.92)} />
          </svg>
          <div className="rtxt num" style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', lineHeight: 1, textAlign: 'center', fontSize: 'var(--pt-base)', fontWeight: 700, color: 'var(--fg1)' }}>92%</div>
        </div>
        <div className="grow" style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 4 }}>
          <div className="subhead" style={{ fontSize: 'var(--pt-lg)', fontWeight: 700, color: 'var(--fg1)' }}>{t('adherence')}</div>
          <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)' }}>{lang === 'ar' ? 'آخر ٧ أيام' : 'Last 7 days'}</div>
          <span className="b-badge b-badge--success" style={{ marginTop: 4 }}><span className="b-badge__dot" />{t('on_track')}</span>
        </div>
      </div>

      <div className="card list-card">
        <div className="list-row" onClick={() => setRxOpen(true)}>
          <div className="lico" style={{ background: 'var(--petal-violet-50)', color: 'var(--petal-violet)' }}><Icon name="file-text" /></div>
          <div className="grow">
            <div style={{ fontWeight: 600, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{t('prescriptions')}</div>
            <div style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg3)', marginTop: 1 }}>{lang === 'ar' ? 'الوصفات والملفات' : 'Manage your scripts'}</div>
          </div>
          <span className="b-badge b-badge--success" style={{ marginInlineEnd: 8 }}><span className="b-badge__dot" />{activeRxCount} {t('rx_active').toLowerCase()}</span>
          <span className="rchev"><Icon name="chevron-right" /></span>
        </div>
      </div>

      {groups.map(g => (
        <div key={g.key}>
          <div className="row-head" style={{ margin: '20px 0 10px', display: 'flex', alignItems: 'center', gap: 10, padding: '0 20px' }}>
            <div style={{ width: 26, height: 26, borderRadius: 'var(--radius-sm)', background: 'var(--app-accent-50)', color: 'var(--app-accent-600)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <Icon name={g.icon} size={15} />
            </div>
            <h2 style={{ fontSize: 'var(--pt-md)', fontWeight: 700, color: 'var(--fg1)', margin: 0 }}>{t(g.key)}</h2>
            <span style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg3)' }}>· {g.meds.length}</span>
          </div>
          <div className="card" style={{ margin: '0 20px' }}>
            {g.meds.map(m => {
              const bg = { info:'var(--petal-blue-50)', violet:'var(--petal-violet-50)', success:'var(--petal-mint-50)' }[m.tone];
              const fg = { info:'var(--petal-blue)',    violet:'var(--petal-violet)',    success:'var(--petal-mint-600)' }[m.tone];
              const taken = m.id === 'metformin';
              return (
                <div key={m.id} className="med-row">
                  <div className="med-ico" style={{ background: bg, color: fg }}><Icon name={m.icon} /></div>
                  <div className="grow">
                    <div className="mname">{m.name[lang]}</div>
                    <div className="mdose">{m.dose[lang]}</div>
                  </div>
                  {taken
                    ? <span className="b-badge b-badge--success"><span className="b-badge__dot" />{t('taken')}</span>
                    : <span className="b-badge b-badge--neutral"><span className="b-badge__dot" />{t('due')}</span>}
                </div>
              );
            })}
          </div>
        </div>
      ))}
      <div style={{ height: 24 }} />
    </div>
  );
}


/* ── Personal details screen ──────────────────────────────── */
function PersonalDetailsScreen({ onBack }) {
  const { t, lang, setNavHidden, setProfileComplete } = useApp();
  const [saved, setSaved]         = useState(false);
  useEffect(() => { setNavHidden(true); return () => setNavHidden(false); }, []);
  const [firstName, setFirstName] = useState(PATIENT.firstName[lang] || PATIENT.firstName.en);
  const [lastName,  setLastName]  = useState(PATIENT.lastName[lang]  || PATIENT.lastName.en);
  const [dob,       setDob]       = useState('1967-03-14');
  const [dobOpen,   setDobOpen]   = useState(false);
  const [gender,    setGender]    = useState(PATIENT.gender);
  const [phone,     setPhone]     = useState(PATIENT.phone);
  const [nid,       setNid]       = useState(PATIENT.nid);
  const [nat,       setNat]       = useState(PATIENT.nationality ? (PATIENT.nationality[lang] || PATIENT.nationality.en) : (lang === 'ar' ? 'مصرية' : 'Egyptian'));
  const [blood,     setBlood]     = useState(PATIENT.bloodType);
  const [weight,    setWeight]    = useState(String(PATIENT.weight));
  const [height,    setHeight]    = useState(String(PATIENT.height));
  const [emName,    setEmName]    = useState(PATIENT.emergency.name);
  const [emRel,     setEmRel]     = useState(PATIENT.emergency.relation[lang] || PATIENT.emergency.relation.en);
  const [emPhone,   setEmPhone]   = useState(PATIENT.emergency.phone);

  /* username */
  const [handle, setHandle, unStatus] = useUsername(HANDLE_STORE.value);
  const committedHandle = useRef(HANDLE_STORE.value);
  useEffect(() => { if (unStatus === 'available' || unStatus === 'idle') HANDLE_STORE.value = handle; }, [handle, unStatus]);
  const [handleConfirmOpen, setHandleConfirmOpen] = useState(false);

  /* connected accounts */
  const [connApple,  setConnApple]  = useState(false);
  const [connGoogle, setConnGoogle] = useState(false);

  const [saving, setSaving] = useState(false);
  const doSave = () => { setSaving(true); setTimeout(() => { setSaving(false); setSaved(true); setProfileComplete(true); committedHandle.current = handle; setTimeout(() => setSaved(false), 2000); }, 850); };
  const save = () => {
    if (saving) return;
    if (handle !== committedHandle.current) { setHandleConfirmOpen(true); return; }
    doSave();
  };

  const Field = ({ label, children, half }) => (
    <div className="field" style={half ? { flex: 1 } : {}}>{label && <label style={{ fontSize: 'var(--pt-xs)', fontWeight: 700, color: 'var(--fg3)', letterSpacing: '0.08em', textTransform: 'uppercase' }}>{label}</label>}{children}</div>
  );
  const SectionHead = ({ icon, title }) => (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '18px 0 10px', color: 'var(--fg2)', fontWeight: 700, fontSize: 'var(--pt-sm)' }}>
      <Icon name={icon} size={16} style={{ color: 'var(--app-accent)' }} />{title}
    </div>
  );

  return (
    <div className="screen fade-in">
      <div className="pad-top" />
      <div className="appbar">
        <button className="round-btn" onClick={onBack} aria-label="Back">
          <Icon name="arrow-left" style={{ transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
        </button>
        <h1 style={{ flex: 1, margin: 0, fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', letterSpacing: '-0.01em', color: 'var(--fg1)' }}>
          {t('p_personal')}
        </h1>
        {saved && <span className="b-badge b-badge--success"><span className="b-badge__dot" />{t('pd_saved')}</span>}
      </div>

      <div className="screen-scroll" style={{ padding: '0 20px 28px' }}>

        {/* Avatar */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10, padding: '14px 0 20px' }}>
          <div style={{ width: 72, height: 72, borderRadius: 9999, background: 'var(--petal-aqua)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 26 }}>
            {(firstName[0] || '') + (lastName[0] || '')}
          </div>
          <button className="b-btn b-btn-md b-btn-ghost" style={{ fontSize: 'var(--pt-sm)', color: 'var(--app-accent)', fontWeight: 600 }}>
            <Icon name="camera" size={15} />{lang === 'ar' ? 'تغيير الصورة' : 'Change photo'}
          </button>
        </div>

        {/* Account section */}
        <SectionHead icon="at-sign" title={lang === 'ar' ? 'الحساب' : 'Account'} />
        <div className="card" style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: 14, marginBottom: 4 }}>
          <UsernameField handle={handle} setHandle={setHandle} status={unStatus} t={t} lang={lang} />
          <div style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg3)', marginTop: -8, display: 'flex', alignItems: 'center', gap: 5 }}>
            <Icon name="info" size={12} />
            <span dir="ltr" style={{ fontFamily: 'var(--font-mono)', color: 'var(--fg3)' }}>balsm.health/@{handle || '…'}</span>
          </div>
        </div>

        {/* Connected accounts */}
        <SectionHead icon="link" title={t('conn_accounts')} />
        <div className="card" style={{ padding: '0', marginBottom: 4, overflow: 'hidden' }}>
          {[
            { key: 'apple',  Icon: () => <AppleIcon />,  label: t('conn_apple'),  connected: connApple,  toggle: () => setConnApple(v => !v)  },
            { key: 'google', Icon: () => <GoogleIcon />, label: t('conn_google'), connected: connGoogle, toggle: () => setConnGoogle(v => !v) },
          ].map(({ key, Icon: Ico, label, connected, toggle }, i, arr) => (
            <div key={key} style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 14, borderBottom: i < arr.length - 1 ? '1px solid var(--balsm-ink-100)' : 'none' }}>
              <div style={{ width: 38, height: 38, borderRadius: 'var(--radius-md)', background: key === 'apple' ? '#1A1A17' : '#fff', border: key === 'google' ? '1px solid var(--balsm-ink-100)' : 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <Ico />
              </div>
              <div className="grow">
                <div style={{ fontWeight: 600, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{label}</div>
                {connected && <div style={{ fontSize: 'var(--pt-xs)', color: 'var(--petal-mint-600)', marginTop: 2, display: 'flex', alignItems: 'center', gap: 4 }}><Icon name="check-circle" size={12} />{t('conn_primary')}</div>}
              </div>
              <button onClick={toggle} className={connected ? 'b-btn b-btn-md b-btn-secondary' : 'b-btn b-btn-md b-btn-soft'} style={{ height: 36, padding: '0 14px', fontSize: 'var(--pt-sm)', flexShrink: 0 }}>
                {connected ? t('conn_remove') : t('conn_connect')}
              </button>
            </div>
          ))}
        </div>

        {/* Basic info */}
        <SectionHead icon="user" title={lang === 'ar' ? 'المعلومات الأساسية' : 'Basic info'} />
        <div className="card" style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: 14, marginBottom: 4 }}>
          <div style={{ display: 'flex', gap: 12 }}>
            <Field label={t('pd_fname')} half><input className="b-input" value={firstName} onChange={e => setFirstName(e.target.value)} /></Field>
            <Field label={t('pd_lname')} half><input className="b-input" value={lastName}  onChange={e => setLastName(e.target.value)} /></Field>
          </div>
          <Field label={t('pd_dob')}>
            <button type="button" className="b-input" onClick={() => setDobOpen(true)}
              style={{ display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer', textAlign: 'start' }}>
              <Icon name="calendar" size={17} style={{ color: 'var(--fg3)', flexShrink: 0 }} />
              <span className={dob ? 'num' : ''} style={{ flex: 1, color: dob ? 'var(--fg1)' : 'var(--fg3)', direction: 'ltr', textAlign: 'start' }}>
                {dob ? fmtDob(dob, lang) : (lang === 'ar' ? 'يوم / شهر / سنة' : 'DD / MM / YYYY')}
              </span>
              <Icon name="chevron-down" size={15} style={{ color: 'var(--fg3)', flexShrink: 0 }} />
            </button>
            {dobOpen && (
              <DobPicker lang={lang} value={dob} title={t('pd_dob')} initialYearsBack={0}
                onPick={iso => setDob(iso)} onClose={() => setDobOpen(false)} />
            )}
          </Field>
          <Field label={t('pd_gender')}>
            <div className="segmented" style={{ width: '100%' }}>
              <button className={cx(gender === 'female' && 'active')} onClick={() => setGender('female')}>{t('pd_female')}</button>
              <button className={cx(gender === 'male'   && 'active')} onClick={() => setGender('male')}>{t('pd_male')}</button>
            </div>
          </Field>
        </div>

        {/* Contact */}
        <SectionHead icon="phone" title={lang === 'ar' ? 'معلومات الاتصال' : 'Contact'} />
        <div className="card" style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: 14, marginBottom: 4 }}>
          <Field label={t('pd_phone')}>
            <PhoneInput value={phone} onChange={setPhone} />
          </Field>
          <Field label={t('pd_nid')}>
            <input className="b-input num" dir="ltr" value={nid} onChange={e => setNid(e.target.value)} maxLength={18} placeholder="2 9912 22 12345 6" />
          </Field>
          <Field label={lang === 'ar' ? 'الجنسية' : 'Nationality'}>
            <div style={{ position: 'relative' }}>
              <select className="b-input" value={nat} onChange={e => setNat(e.target.value)}
                style={{ appearance: 'none', WebkitAppearance: 'none', paddingInlineEnd: 38, cursor: 'pointer' }}>
                {(lang === 'ar'
                  ? ['مصرية','سعودية','إماراتية','أردنية','لبنانية','سورية','عراقية','فلسطينية','كويتية','قطرية','بحرينية','عمانية','يمنية','سودانية','ليبية','تونسية','جزائرية','مغربية','أخرى']
                  : ['Egyptian','Saudi','Emirati','Jordanian','Lebanese','Syrian','Iraqi','Palestinian','Kuwaiti','Qatari','Bahraini','Omani','Yemeni','Sudanese','Libyan','Tunisian','Algerian','Moroccan','Other']
                ).map(n => <option key={n} value={n}>{n}</option>)}
              </select>
              <Icon name="chevron-down" size={16} style={{ position: 'absolute', insetInlineEnd: 14, top: '50%', transform: 'translateY(-50%)', color: 'var(--fg3)', pointerEvents: 'none' }} />
            </div>
          </Field>
        </div>

        {/* Emergency contact */}
        <SectionHead icon="phone-call" title={t('pd_emergency')} />
        <div className="card" style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: 14, marginBottom: 24 }}>
          <Field label={t('pd_em_name')}>
            <input className="b-input" value={emName} onChange={e => setEmName(e.target.value)} />
          </Field>
          <Field label={t('pd_em_rel')}>
            <input className="b-input" value={emRel} onChange={e => setEmRel(e.target.value)} />
          </Field>
          <Field label={t('pd_em_phone')}>
            <PhoneInput value={emPhone} onChange={setEmPhone} />
          </Field>
        </div>

        <DSProgressButton block loading={saving} onClick={save}>
          {!saving && <Icon name={saved ? 'check' : 'save'} size={18} />}
          {saving ? (lang === 'ar' ? 'جارٍ الحفظ…' : 'Saving…') : (saved ? t('pd_saved') : t('pd_save'))}
        </DSProgressButton>
      </div>
      {handleConfirmOpen && (
        <SettingsSheet title={t('hc_title')} onClose={() => { setHandle(committedHandle.current); setHandleConfirmOpen(false); }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '2px 0 18px' }}>
            <div style={{ width: 44, height: 44, borderRadius: '50%', background: 'var(--balsm-sun-50, #FFF6E0)', color: 'var(--balsm-sun-500)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <Icon name="alert-triangle" size={21} />
            </div>
            <p className="body-sm" style={{ margin: 0, lineHeight: 1.55, color: 'var(--fg2)' }}>{t('hc_body')}</p>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 22 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 14px', background: 'var(--balsm-ink-50)', borderRadius: 'var(--radius-md)' }}>
              <span className="meta" style={{ fontWeight: 700 }}>{t('hc_from')}</span>
              <span className="num" style={{ fontFamily: 'var(--font-mono)', color: 'var(--fg3)', textDecoration: 'line-through' }} dir="ltr">@{committedHandle.current}</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 14px', background: 'var(--app-accent-50)', borderRadius: 'var(--radius-md)' }}>
              <span className="meta" style={{ fontWeight: 700 }}>{t('hc_to')}</span>
              <span className="num" style={{ fontFamily: 'var(--font-mono)', color: 'var(--app-accent-600)', fontWeight: 700 }} dir="ltr">@{handle}</span>
            </div>
          </div>
          <button className="b-btn b-btn-lg b-btn-primary b-btn--full" onClick={() => { setHandleConfirmOpen(false); doSave(); }}>{t('hc_confirm')}</button>
          <button className="b-btn b-btn-md b-btn-ghost b-btn--full" style={{ marginTop: 10 }} onClick={() => { setHandle(committedHandle.current); setHandleConfirmOpen(false); }}>{t('hc_cancel')}</button>
        </SettingsSheet>
      )}
    </div>
  );
}

/* ── Profile ─────────────────────────────────────────────── */

/* Care team providers — a care team is not only doctors. */
const PROVIDER_TYPES = [
  { id: 'doctor',   icon: 'stethoscope',  en: 'Doctor',         ar: 'طبيب' },
  { id: 'nurse',    icon: 'heart-pulse',  en: 'Nurse',          ar: 'تمريض' },
  { id: 'carer',    icon: 'hand-heart',   en: 'Caregiver',      ar: 'مقدّم رعاية' },
  { id: 'pharmacy', icon: 'pill',         en: 'Pharmacy',       ar: 'صيدلية' },
  { id: 'lab',      icon: 'flask-conical',en: 'Lab',            ar: 'مختبر' },
  { id: 'physio',   icon: 'activity',     en: 'Physiotherapist',ar: 'علاج طبيعي' },
  { id: 'clinic',   icon: 'building-2',   en: 'Clinic',         ar: 'عيادة' },
  { id: 'other',    icon: 'user-round',   en: 'Other',          ar: 'أخرى' },
];
const providerType = (id) => PROVIDER_TYPES.find(p => p.id === id) || PROVIDER_TYPES[0];
/* places rather than people — their name and "specialty" read differently */
const PLACE_TYPES = ['pharmacy', 'lab', 'clinic'];

/* Care team store — module-level so added doctors and their files survive leaving the screen. */
const careCardSvg = (d) => {
  const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="700" height="400" viewBox="0 0 700 400">
<rect width="700" height="400" rx="24" fill="#F4F3EC"/>
<rect x="0" y="0" width="14" height="400" fill="#1283FF"/>
<text x="60" y="120" font-family="Montserrat, sans-serif" font-weight="700" font-size="40" fill="#1F2D3D">${esc(d.name.en)}</text>
<text x="60" y="165" font-family="IBM Plex Sans, sans-serif" font-size="24" fill="#526174">${esc(d.specialty.en)}</text>
<line x1="60" y1="205" x2="640" y2="205" stroke="#D9DEE4" stroke-width="2"/>
<text x="60" y="255" font-family="IBM Plex Mono, monospace" font-size="24" fill="#1F2D3D">+20 2 2555 0100</text>
<text x="60" y="295" font-family="IBM Plex Sans, sans-serif" font-size="22" fill="#526174">Maadi Medical Center · Road 9, Maadi, Cairo</text>
<text x="60" y="335" font-family="IBM Plex Sans, sans-serif" font-size="22" fill="#526174">clinic@maadimedical.eg</text>
</svg>`;
  return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
};
const CARE_STORE = window.__balsmCareStore || (window.__balsmCareStore = {
  mine: [], overrides: {}, hidden: [],
  files: DOCTORS[0] ? { [DOCTORS[0].id]: [{ url: careCardSvg(DOCTORS[0]), kind: 'image', name: 'Business card.png' }] } : {},
});

/* Care team screen */
function CareTeamScreen({ onBack }) {
  const { t, lang, setTab, setNavHidden } = useApp();
  useEffect(() => { setNavHidden(true); return () => setNavHidden(false); }, []);
  /* Files are kept per doctor id; manually added doctors sit alongside the seeded ones. */
  const [mine, setMine]     = useState(CARE_STORE.mine);
  const [files, setFiles]   = useState(CARE_STORE.files);
  useEffect(() => { CARE_STORE.mine = mine; }, [mine]);
  useEffect(() => { CARE_STORE.files = files; }, [files]);
  const [overrides, setOverrides] = useState(CARE_STORE.overrides || {});
  const [hidden, setHidden] = useState(CARE_STORE.hidden || []);
  useEffect(() => { CARE_STORE.overrides = overrides; }, [overrides]);
  useEffect(() => { CARE_STORE.hidden = hidden; }, [hidden]);
  const [editingId, setEditingId] = useState(null);
  const [confirmDel, setConfirmDel] = useState(false);
  const [openId, setOpenId] = useState(null);
  const [viewer, setViewer] = useState(null); /* { id, i } */
  const [adding, setAdding] = useState(false);
  const [query, setQuery]   = useState('');
  const [typeFilter, setTypeFilter] = useState('all');
  const [form, setForm]     = useState({ type: 'doctor', name: '', specialty: '', phone: '', phone2: '', email: '', clinic: '', address: '', mapUrl: '', notes: '' });
  const [formAtts, setFormAtts] = useState([]);
  const NEW = '__new';
  const pickRef = useRef(null);
  const pickFor = useRef(null);

  const addFiles = (id, atts) => setFiles(f => ({ ...f, [id]: [...(f[id] || []), ...atts] }));
  const dropFile = (id, i) => setFiles(f => ({ ...f, [id]: f[id].filter((_, j) => j !== i) }));
  const attach = (id) => { pickFor.current = id; pickRef.current?.click(); };

  const resetForm = () => {
    setForm({ type: 'doctor', name: '', specialty: '', phone: '', phone2: '', email: '', clinic: '', address: '', mapUrl: '', notes: '' });
    setFormAtts([]);
    setEditingId(null);
    setConfirmDel(false);
  };
  const closeSheet = () => { setAdding(false); resetForm(); };

  const FIELDS = ['type', 'name', 'specialty', 'phone', 'phone2', 'email', 'clinic', 'address', 'mapUrl', 'notes'];
  const startEdit = (r) => {
    const f = {};
    FIELDS.forEach(k => { f[k] = r[k] || ''; });
    f.type = r.type || 'doctor';
    setForm(f);
    setFormAtts(files[r.id] || []);
    setEditingId(r.id);
    setConfirmDel(false);
    setAdding(true);
  };
  const deleteProvider = (id) => {
    if (id.startsWith('mine_')) setMine(m => m.filter(x => x.id !== id));
    else setHidden(h => [...h, id]);
    setFiles(f => { const n = { ...f }; delete n[id]; return n; });
    if (openId === id) setOpenId(null);
    closeSheet();
  };

  const saveDoctor = () => {
    if (!form.name.trim()) return;
    const clean = (s) => (s || '').trim();
    if (editingId) {
      const upd = {};
      FIELDS.forEach(k => { upd[k] = k === 'type' ? form.type : clean(form[k]); });
      if (editingId.startsWith('mine_')) setMine(m => m.map(x => x.id === editingId ? { ...x, ...upd } : x));
      else setOverrides(o => ({ ...o, [editingId]: upd }));
      setFiles(f => ({ ...f, [editingId]: formAtts }));
      closeSheet();
      return;
    }
    const id = 'mine_' + Date.now();
    setMine(m => [...m, {
      id, mine: true, type: form.type,
      name: clean(form.name), specialty: clean(form.specialty),
      phone: clean(form.phone), phone2: clean(form.phone2), email: clean(form.email),
      clinic: clean(form.clinic), address: clean(form.address), mapUrl: clean(form.mapUrl), notes: clean(form.notes),
    }]);
    if (formAtts.length) setFiles(f => ({ ...f, [id]: formAtts }));
    resetForm();
    setAdding(false);
    setOpenId(id);
  };

  const roster = [
    ...DOCTORS.filter(d => !hidden.includes(d.id)).map((d, i) => ({ id: d.id, doctor: d, primary: i === 0, name: d.name[lang], specialty: d.specialty[lang], type: 'doctor', ...(overrides[d.id] || {}) })),
    ...mine,
  ];

  /* search across name, specialty, clinic, address and provider type */
  const nq = dcNorm(query.trim());
  const shown = roster.filter(r => {
    if (typeFilter !== 'all' && (r.type || 'doctor') !== typeFilter) return false;
    if (!nq) return true;
    const hay = [r.name, r.specialty, r.clinic, r.address, r.phone, r.email,
      providerType(r.type).en, providerType(r.type).ar].filter(Boolean).join(' ');
    return dcNorm(hay).includes(nq);
  });
  /* only offer type chips for types actually present */
  const presentTypes = PROVIDER_TYPES.filter(p => roster.some(r => (r.type || 'doctor') === p.id));

  return (
    <div className="screen fade-in">
      <div className="pad-top" />
      <div className="appbar">
        <button className="round-btn" onClick={onBack} aria-label="Back">
          <Icon name="arrow-left" style={{ transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
        </button>
        <h1 style={{ flex: 1, margin: 0, fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', letterSpacing: '-0.01em', color: 'var(--fg1)' }}>{t('p_care')}</h1>
      </div>
      <AttachmentInput inputRef={pickRef} onPick={(atts) => {
        if (pickFor.current === NEW) setFormAtts(a => [...a, ...atts]);
        else if (pickFor.current) addFiles(pickFor.current, atts);
      }} />
      <div className="screen-scroll" style={{ padding: '0 20px 28px' }}>
        <p className="body" style={{ margin: '4px 0 18px', color: 'var(--fg3)', fontSize: 'var(--pt-sm)' }}>
          {lang === 'ar' ? 'فريق الرعاية الذي يتابع حالتك ويرى تقاريرك — أطباء، تمريض، صيدليات ومقدّمو رعاية.' : 'The people and places caring for you — doctors, nurses, pharmacies, caregivers and more.'}
        </p>
        <div style={{ position: 'relative', marginBottom: 10 }}>
          <Icon name="search" size={17} style={{ position: 'absolute', insetInlineStart: 14, top: '50%', transform: 'translateY(-50%)', color: 'var(--fg3)', pointerEvents: 'none' }} />
          <input className="b-input" value={query} onChange={e => setQuery(e.target.value)}
            placeholder={lang === 'ar' ? 'ابحث بالاسم، التخصص أو العيادة' : 'Search name, specialty or clinic'}
            style={{ paddingInlineStart: 42, paddingInlineEnd: query ? 42 : 14 }} />
          {query && (
            <button onClick={() => setQuery('')} aria-label={lang === 'ar' ? 'مسح' : 'Clear'}
              style={{ position: 'absolute', insetInlineEnd: 10, top: '50%', transform: 'translateY(-50%)', border: 'none', background: 'var(--balsm-ink-100)', color: 'var(--fg3)', cursor: 'pointer', width: 24, height: 24, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="x" size={13} />
            </button>
          )}
        </div>

        {presentTypes.length > 1 && (
          <div style={{ display: 'flex', gap: 7, flexWrap: 'wrap', marginBottom: 16 }}>
            {[{ id: 'all', icon: 'users', en: 'All', ar: 'الكل' }, ...presentTypes].map(p => {
              const on = typeFilter === p.id;
              return (
                <button key={p.id} onClick={() => setTypeFilter(p.id)}
                  style={{
                    display: 'inline-flex', alignItems: 'center', gap: 5, height: 32, padding: '0 11px',
                    borderRadius: 'var(--radius-pill)', cursor: 'pointer',
                    border: `1px solid ${on ? 'var(--app-accent)' : 'var(--balsm-border)'}`,
                    background: on ? 'var(--app-accent-50)' : '#fff',
                    color: on ? 'var(--app-accent-600)' : 'var(--fg3)',
                    fontFamily: lang === 'ar' ? 'var(--font-arabic)' : 'var(--font-body)',
                    fontWeight: on ? 700 : 600, fontSize: 'var(--pt-xs)',
                  }}>
                  <Icon name={p.icon} size={13} />{p[lang]}
                </button>
              );
            })}
          </div>
        )}

        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {shown.map((r) => {
            const atts = files[r.id] || [];
            const expanded = openId === r.id;
            return (
              <div key={r.id} className="card" style={{ padding: 16 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                  {r.doctor
                    ? <DoctorAvatar doctor={r.doctor} size={52} />
                    : <div style={{ width: 52, height: 52, borderRadius: 9999, flexShrink: 0, background: 'var(--balsm-ink-100)', color: 'var(--fg3)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <Icon name={providerType(r.type).icon} size={22} />
                      </div>}
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 7, flexWrap: 'wrap' }}>
                      <span style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{r.name}</span>
                      {r.primary && <span className="b-badge" style={{ background: 'var(--app-accent-50)', color: 'var(--app-accent-600)', fontSize: '10px', fontWeight: 700 }}>{lang === 'ar' ? 'الطبيب الأساسي' : 'Primary'}</span>}
                      {r.mine && <span className="b-badge" style={{ background: 'var(--balsm-ink-50)', color: 'var(--fg3)', fontSize: '10px', fontWeight: 700, display: 'inline-flex', alignItems: 'center', gap: 4 }}><Icon name={providerType(r.type).icon} size={11} />{providerType(r.type)[lang]}</span>}
                    </div>
                    {r.specialty && <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', marginTop: 2 }}>{r.specialty}</div>}
                    {(r.clinic || r.address) && <div style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg3)', marginTop: 3, display: 'flex', alignItems: 'flex-start', gap: 4 }}><Icon name="map-pin" size={12} style={{ flexShrink: 0, marginTop: 1 }} /><span>{[r.clinic, r.address].filter(Boolean).join(' · ')}</span></div>}
                    {r.mapUrl && /^https?:\/\//i.test(r.mapUrl) && (
                      <a href={r.mapUrl} target="_blank" rel="noopener noreferrer"
                        style={{ display: 'inline-flex', alignItems: 'center', gap: 4, marginTop: 4, fontSize: 'var(--pt-xs)', fontWeight: 700, color: 'var(--app-accent-600)', textDecoration: 'none' }}>
                        <Icon name="navigation" size={12} />{lang === 'ar' ? 'الاتجاهات' : 'Directions'}
                      </a>
                    )}
                    {r.phone && <div dir="ltr" className="num" style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg3)', marginTop: 3, display: 'flex', alignItems: 'center', gap: 4 }}><Icon name="phone" size={12} />{r.phone}{r.phone2 ? ` · ${r.phone2}` : ''}</div>}
                    {r.email && <div dir="ltr" style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg3)', marginTop: 3, display: 'flex', alignItems: 'center', gap: 4 }}><Icon name="mail" size={12} />{r.email}</div>}
                    {r.notes && <div style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg3)', marginTop: 5, lineHeight: 1.45, fontStyle: 'italic' }}>{r.notes}</div>}
                  </div>
                  <button className="round-btn ghost" aria-label={lang === 'ar' ? 'تعديل' : 'Edit'} onClick={() => startEdit(r)} style={{ alignSelf: 'flex-start' }}>
                    <Icon name="pencil" size={16} />
                  </button>
                </div>
                {atts.length > 0 && !expanded && (
                  <div style={{ display: 'flex', gap: 8, marginTop: 14, overflowX: 'auto', paddingBottom: 2 }}>
                    {atts.map((a, i) => (
                      <AttachmentThumb key={i} att={a} compact height={64} onOpen={() => setViewer({ id: r.id, i })}
                        style={{ width: 64, flexShrink: 0, borderRadius: 'var(--radius-md)' }} />
                    ))}
                  </div>
                )}
                <div style={{ display: 'flex', gap: 8, marginTop: 14 }}>
                  <a className="b-btn b-btn-md b-btn-secondary b-btn--full" href={`tel:${(r.phone || (r.doctor && r.doctor.phone) || '+20225550100').replace(/[^\d+]/g, '')}`}
                    style={{ height: 40, gap: 7, fontSize: 'var(--pt-sm)', textDecoration: 'none' }}>
                    <Icon name="phone" size={15} />{lang === 'ar' ? 'اتصال' : 'Call'}
                  </a>
                  <button className="b-btn b-btn-md b-btn-secondary" onClick={() => atts.length ? setOpenId(expanded ? null : r.id) : attach(r.id)}
                    style={{ height: 40, gap: 7, fontSize: 'var(--pt-sm)', paddingInline: 14, flexShrink: 0 }}>
                    <Icon name={atts.length ? (expanded ? 'check' : 'pencil') : 'paperclip'} size={15} />
                    {atts.length ? (expanded ? (lang === 'ar' ? 'تم' : 'Done') : (lang === 'ar' ? 'إدارة الملفات' : 'Manage files')) : (lang === 'ar' ? 'إرفاق ملف' : 'Attach file')}
                  </button>
                </div>
                {expanded && (
                  <div style={{ marginTop: 12, paddingTop: 12, borderTop: '1px solid var(--balsm-ink-100)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: atts.length ? 10 : 0 }}>
                      <Icon name="paperclip" size={13} style={{ color: 'var(--fg3)' }} />
                      <span style={{ flex: 1, fontSize: 'var(--pt-xs)', fontWeight: 700, color: 'var(--fg3)' }}>
                        {lang === 'ar' ? 'بطاقة العمل والملفات' : 'Business card & files'}
                      </span>
                      <button className="b-btn b-btn-sm b-btn-ghost" onClick={() => attach(r.id)}
                        style={{ height: 28, padding: '0 8px', gap: 5, fontSize: 'var(--pt-xs)', color: 'var(--app-accent)', fontWeight: 700 }}>
                        <Icon name="plus" size={13} />{lang === 'ar' ? 'إرفاق' : 'Attach'}
                      </button>
                    </div>
                    {atts.length > 0 && (
                      <AttachmentGallery atts={atts} height={150}
                        onRemove={(i) => dropFile(r.id, i)}
                        onAdd={() => attach(r.id)}
                        addLabel={lang === 'ar' ? 'إضافة' : 'Add'} />
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
        {viewer && files[viewer.id] && (
          <AttachmentViewer atts={files[viewer.id]} index={viewer.i}
            title={(roster.find(x => x.id === viewer.id) || {}).name}
            onClose={() => setViewer(null)} />
        )}

        {shown.length === 0 && (
          <div style={{ textAlign: 'center', padding: '34px 12px 4px' }}>
            <Icon name="search-x" size={26} style={{ color: 'var(--balsm-ink-300)' }} />
            <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg2)', marginTop: 10 }}>
              {lang === 'ar' ? 'لا توجد نتائج' : 'No matches'}
            </div>
            <p className="meta" style={{ margin: '6px auto 0', maxWidth: 240, lineHeight: 1.5 }}>
              {lang === 'ar' ? 'جرّب اسمًا آخر، أو أضف مقدّم الرعاية بنفسك.' : 'Try another name, or add the provider yourself.'}
            </p>
          </div>
        )}

        <button className="b-btn b-btn-md b-btn-ghost b-btn--full" style={{ marginTop: 12, gap: 8 }} onClick={() => setTab('map')}>
          <Icon name="search" size={16} />{lang === 'ar' ? 'ابحث عن رعاية قريبة' : 'Find care nearby'}
        </button>
        <div style={{ height: 72 }} />
      </div>

      <button className="rec-fab" onClick={() => setAdding(true)} aria-label={lang === 'ar' ? 'أضف مقدّم رعاية' : 'Add a care provider'}>
        <Icon name="user-plus" size={22} stroke={2.2} />
      </button>

      {adding && (
        <SettingsSheet title={editingId ? (lang === 'ar' ? 'تعديل مقدّم الرعاية' : 'Edit provider') : (lang === 'ar' ? 'إضافة مقدّم رعاية' : 'Add a provider')} onClose={closeSheet}>
          <p className="meta" style={{ margin: '4px 0 16px', fontSize: 'var(--pt-xs)', lineHeight: 1.5 }}>
            {lang === 'ar' ? 'الاسم فقط مطلوب. ما تضيفه يبقى على جهازك.' : 'Only the name is required. What you add stays on your device.'}
          </p>
          <div style={{ marginBottom: 16 }}>
            <div style={{ fontSize: 'var(--pt-xs)', fontWeight: 700, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--fg3)', marginBottom: 10 }}>
              {lang === 'ar' ? 'نوع مقدّم الرعاية' : 'Provider type'}
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {PROVIDER_TYPES.map(p => {
                const on = form.type === p.id;
                return (
                  <button key={p.id} onClick={() => setForm(f => ({ ...f, type: p.id }))}
                    style={{
                      display: 'inline-flex', alignItems: 'center', gap: 6, height: 38, padding: '0 13px',
                      borderRadius: 'var(--radius-pill)', cursor: 'pointer',
                      border: `1.5px solid ${on ? 'var(--app-accent)' : 'var(--balsm-border)'}`,
                      background: on ? 'var(--app-accent-50)' : '#fff',
                      color: on ? 'var(--app-accent-600)' : 'var(--fg2)',
                      fontFamily: lang === 'ar' ? 'var(--font-arabic)' : 'var(--font-body)',
                      fontWeight: on ? 700 : 600, fontSize: 'var(--pt-sm)',
                      transition: 'all var(--dur-fast) var(--ease-out)',
                    }}>
                    <Icon name={p.icon} size={15} />{p[lang]}
                  </button>
                );
              })}
            </div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div className="field" style={{ margin: 0 }}>
              <label>{lang === 'ar' ? 'الاسم' : 'Name'}</label>
              <input className="b-input" autoFocus value={form.name}
                placeholder={PLACE_TYPES.includes(form.type)
                  ? (lang === 'ar' ? 'صيدلية الشفاء' : 'El Ezaby Pharmacy')
                  : (lang === 'ar' ? 'د. سارة كمال' : 'Dr. Sara Kamal')}
                onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
            </div>
            <div className="field" style={{ margin: 0 }}>
              <label>{PLACE_TYPES.includes(form.type)
                ? (lang === 'ar' ? 'الخدمات' : 'Services')
                : (lang === 'ar' ? 'التخصص' : 'Specialty')}</label>
              <input className="b-input" value={form.specialty}
                placeholder={PLACE_TYPES.includes(form.type)
                  ? (lang === 'ar' ? 'توصيل، قياس ضغط' : 'Delivery, blood pressure checks')
                  : (lang === 'ar' ? 'باطنة' : 'Internal medicine')}
                onChange={e => setForm(f => ({ ...f, specialty: e.target.value }))} />
            </div>

            <div style={{ fontSize: 'var(--pt-xs)', fontWeight: 700, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--fg3)', marginTop: 2 }}>
              {lang === 'ar' ? 'التواصل' : 'Contact'}
            </div>
            <div className="field" style={{ margin: 0 }}>
              <label>{lang === 'ar' ? 'رقم الهاتف' : 'Phone'}</label>
              <PhoneInput value={form.phone} onChange={(v) => setForm(f => ({ ...f, phone: v }))} />
            </div>
            <div className="field" style={{ margin: 0 }}>
              <label>{lang === 'ar' ? 'رقم آخر (اختياري)' : 'Second number (optional)'}</label>
              <PhoneInput value={form.phone2} onChange={(v) => setForm(f => ({ ...f, phone2: v }))}
                placeholder={lang === 'ar' ? 'هاتف العيادة' : 'Clinic landline'} />
            </div>
            <div className="field" style={{ margin: 0 }}>
              <label>{lang === 'ar' ? 'البريد الإلكتروني' : 'Email'}</label>
              <input className="b-input" type="email" dir="ltr" inputMode="email" autoComplete="email" value={form.email}
                placeholder="doctor@clinic.eg"
                onChange={e => setForm(f => ({ ...f, email: e.target.value }))} />
            </div>

            <div style={{ fontSize: 'var(--pt-xs)', fontWeight: 700, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--fg3)', marginTop: 2 }}>
              {PLACE_TYPES.includes(form.type) ? (lang === 'ar' ? 'الموقع' : 'Location') : (lang === 'ar' ? 'العيادة' : 'Clinic')}
            </div>
            <div className="field" style={{ margin: 0 }}>
              <label>{PLACE_TYPES.includes(form.type)
                ? (lang === 'ar' ? 'الفرع أو المجموعة' : 'Branch or group')
                : (lang === 'ar' ? 'العيادة أو المستشفى' : 'Clinic or hospital')}</label>
              <input className="b-input" value={form.clinic}
                placeholder={lang === 'ar' ? 'مركز بلسم الطبي' : 'Balsm Medical Centre'}
                onChange={e => setForm(f => ({ ...f, clinic: e.target.value }))} />
            </div>
            <div className="field" style={{ margin: 0 }}>
              <label>{lang === 'ar' ? 'العنوان' : 'Address'}</label>
              <textarea className="b-input" rows={2} value={form.address}
                placeholder={lang === 'ar' ? '١٢ شارع ٩، المعادي، القاهرة' : '12 Street 9, Maadi, Cairo'}
                style={{ resize: 'none', minHeight: 62, paddingBlock: 12 }}
                onChange={e => setForm(f => ({ ...f, address: e.target.value }))} />
            </div>
            <div className="field" style={{ margin: 0 }}>
              <label>{lang === 'ar' ? 'رابط الموقع (اختياري)' : 'Map link (optional)'}</label>
              <div style={{ position: 'relative' }}>
                <span style={{ position: 'absolute', insetInlineStart: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fg3)', display: 'flex', pointerEvents: 'none' }}><Icon name="map-pinned" size={16} /></span>
                <input className="b-input" type="url" dir="ltr" inputMode="url" value={form.mapUrl}
                  placeholder="https://maps.app.goo.gl/…"
                  style={{ paddingInlineStart: 38, paddingInlineEnd: 78 }}
                  onChange={e => setForm(f => ({ ...f, mapUrl: e.target.value }))} />
                <button type="button" className="b-btn b-btn-sm b-btn-ghost"
                  onClick={async () => { try { const v = (await navigator.clipboard.readText()).trim(); if (v) setForm(f => ({ ...f, mapUrl: v })); } catch (e) {} }}
                  style={{ position: 'absolute', insetInlineEnd: 6, top: '50%', transform: 'translateY(-50%)', height: 32, padding: '0 10px', gap: 5, fontSize: 'var(--pt-xs)', fontWeight: 700, color: 'var(--app-accent)' }}>
                  <Icon name="clipboard-paste" size={14} />{lang === 'ar' ? 'لصق' : 'Paste'}
                </button>
              </div>
              {form.mapUrl && !/^https?:\/\/\S+\.\S+/i.test(form.mapUrl.trim()) && (
                <div style={{ fontSize: 'var(--pt-xs)', color: 'var(--balsm-danger)', marginTop: 6 }}>
                  {lang === 'ar' ? 'يبدو أن هذا ليس رابطًا. انسخ الرابط من خرائط Google أو Apple.' : 'That doesn’t look like a link. Copy it from Google Maps or Apple Maps.'}
                </div>
              )}
              {!form.mapUrl && (
                <div className="meta" style={{ fontSize: 'var(--pt-xs)', marginTop: 6, lineHeight: 1.5 }}>
                  {lang === 'ar' ? 'من الخريطة: مشاركة ← نسخ الرابط.' : 'In your maps app: Share → Copy link.'}
                </div>
              )}
            </div>
            <div className="field" style={{ margin: 0 }}>
              <label>{lang === 'ar' ? 'ملاحظات' : 'Notes'}</label>
              <textarea className="b-input" rows={2} value={form.notes}
                placeholder={lang === 'ar' ? 'مواعيد العمل، كيف وصلت إليه…' : 'Visiting hours, how you were referred…'}
                style={{ resize: 'none', minHeight: 62, paddingBlock: 12 }}
                onChange={e => setForm(f => ({ ...f, notes: e.target.value }))} />
            </div>
          </div>

          <div style={{ marginTop: 18 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
              <span style={{ flex: 1, fontSize: 'var(--pt-xs)', fontWeight: 700, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--fg3)' }}>
                {lang === 'ar' ? 'بطاقة العمل والملفات' : 'Business card & files'}
              </span>
              <button className="b-btn b-btn-sm b-btn-ghost" onClick={() => { pickFor.current = NEW; pickRef.current?.click(); }}
                style={{ height: 28, padding: '0 8px', gap: 5, fontSize: 'var(--pt-xs)', color: 'var(--app-accent)', fontWeight: 700 }}>
                <Icon name="plus" size={13} />{lang === 'ar' ? 'إرفاق' : 'Attach'}
              </button>
            </div>
            {formAtts.length > 0 ? (
              <AttachmentGallery atts={formAtts} height={150}
                onRemove={(i) => setFormAtts(a => a.filter((_, j) => j !== i))}
                onAdd={() => { pickFor.current = NEW; pickRef.current?.click(); }}
                addLabel={lang === 'ar' ? 'إضافة' : 'Add'} />
            ) : (
              <button onClick={() => { pickFor.current = NEW; pickRef.current?.click(); }}
                style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 10, padding: '13px 14px', cursor: 'pointer', textAlign: 'start', background: 'transparent', border: '1.5px dashed var(--balsm-border)', borderRadius: 'var(--radius-lg)' }}>
                <Icon name="paperclip" size={16} style={{ color: 'var(--fg3)', flexShrink: 0 }} />
                <span style={{ flex: 1, minWidth: 0 }}>
                  <span style={{ display: 'block', fontSize: 'var(--pt-sm)', fontWeight: 600, color: 'var(--fg2)' }}>
                    {lang === 'ar' ? 'أرفق بطاقة العمل أو صورة' : 'Attach a business card or photo'}
                  </span>
                  <span style={{ display: 'block', fontSize: 'var(--pt-xs)', color: 'var(--fg3)', marginTop: 2 }}>
                    {lang === 'ar' ? 'صور، فيديو أو PDF' : 'Photos, video or PDF'}
                  </span>
                </span>
              </button>
            )}
          </div>

          <div style={{ display: 'flex', gap: 8, marginTop: 16 }}>
            <button className="b-btn b-btn-lg b-btn-secondary b-btn--full" onClick={closeSheet}>
              {lang === 'ar' ? 'إلغاء' : 'Cancel'}
            </button>
            <button className="b-btn b-btn-lg b-btn-primary b-btn--full" onClick={saveDoctor} disabled={!form.name.trim()}>
              {editingId ? (lang === 'ar' ? 'حفظ التغييرات' : 'Save changes') : (lang === 'ar' ? 'حفظ' : 'Save provider')}
            </button>
          </div>
          {editingId && (confirmDel ? (
            <div style={{ marginTop: 14, padding: 14, borderRadius: 'var(--radius-lg)', background: 'var(--balsm-danger-50, #FBECEA)', border: '1px solid var(--balsm-danger)' }}>
              <div style={{ fontWeight: 700, fontSize: 'var(--pt-sm)', color: 'var(--fg1)' }}>
                {lang === 'ar' ? `حذف ${form.name || 'مقدّم الرعاية'} من فريق رعايتك؟` : `Remove ${form.name || 'this provider'} from your care team?`}
              </div>
              <div style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg2)', marginTop: 4, lineHeight: 1.5 }}>
                {lang === 'ar' ? 'سيتم حذف بياناته وملفاته المرفقة من جهازك.' : 'Their details and attached files will be deleted from your device.'}
              </div>
              <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
                <button className="b-btn b-btn-md b-btn-secondary b-btn--full" onClick={() => setConfirmDel(false)}>{lang === 'ar' ? 'تراجع' : 'Keep'}</button>
                <button className="b-btn b-btn-md b-btn-danger b-btn--full" onClick={() => deleteProvider(editingId)}>{lang === 'ar' ? 'حذف' : 'Remove'}</button>
              </div>
            </div>
          ) : (
            <button className="b-btn b-btn-md b-btn-ghost b-btn--full" onClick={() => setConfirmDel(true)}
              style={{ marginTop: 10, gap: 8, color: 'var(--balsm-danger)' }}>
              <Icon name="trash-2" size={16} />{lang === 'ar' ? 'حذف من فريق الرعاية' : 'Remove from care team'}
            </button>
          ))}
        </SettingsSheet>
      )}
    </div>
  );
}

/* Privacy & data screen */
function PrivacyDataScreen({ onBack }) {
  const { t, lang, setNavHidden, authEmail } = useApp();
  useEffect(() => { setNavHidden(true); return () => setNavHidden(false); }, []);
  const [shareTeam, setShareTeam]   = useState(true);
  const [analytics, setAnalytics]   = useState(false);
  const [research,  setResearch]    = useState(false);
  const [bioLock,   setBioLock]     = useState(true);
  const [pinOpen,   setPinOpen]     = useState(false);
  const [changeEmailOpen, setChangeEmailOpen] = useState(false);

  const PvSection = ({ icon, title }) => (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '18px 0 10px', color: 'var(--fg2)', fontWeight: 700, fontSize: 'var(--pt-sm)' }}>
      <Icon name={icon} size={16} style={{ color: 'var(--app-accent)' }} />{title}
    </div>
  );
  const ToggleRow = ({ title, desc, on, set, last }) => (
    <div style={{ padding: '14px 16px', borderBottom: last ? 'none' : '1px solid var(--balsm-ink-100)' }}>
      <Switch between checked={on} onChange={() => set(v => !v)}
        label={<span style={{ fontWeight: 600, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{title}</span>}
        hint={desc && <span style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg3)', lineHeight: 1.4 }}>{desc}</span>} />
    </div>
  );
  const ActionRow = ({ icon, title, desc, danger, last, onClick }) => (
    <div onClick={onClick} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '14px 16px', cursor: 'pointer', borderBottom: last ? 'none' : '1px solid var(--balsm-ink-100)' }}>
      <div style={{ width: 38, height: 38, borderRadius: 'var(--radius-md)', background: danger ? '#FBEBE7' : 'var(--balsm-ink-50)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <Icon name={icon} size={18} style={{ color: danger ? 'var(--balsm-danger)' : 'var(--fg2)' }} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontWeight: 600, fontSize: 'var(--pt-md)', color: danger ? 'var(--balsm-danger)' : 'var(--fg1)' }}>{title}</div>
        {desc && <div style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg3)', marginTop: 2 }}>{desc}</div>}
      </div>
      <Icon name={lang === 'ar' ? 'chevron-left' : 'chevron-right'} size={18} style={{ color: 'var(--fg3)', flexShrink: 0 }} />
    </div>
  );

  return (
    <div className="screen fade-in">
      <div className="pad-top" />
      <div className="appbar">
        <button className="round-btn" onClick={onBack} aria-label="Back">
          <Icon name="arrow-left" style={{ transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
        </button>
        <h1 style={{ flex: 1, margin: 0, fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', letterSpacing: '-0.01em', color: 'var(--fg1)' }}>{t('p_privacy')}</h1>
      </div>
      <div className="screen-scroll" style={{ padding: '0 20px 28px' }}>

        <PvSection icon="share-2" title={lang === 'ar' ? 'مشاركة البيانات' : 'Data sharing'} />
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <ToggleRow on={shareTeam} set={setShareTeam}
            title={lang === 'ar' ? 'مشاركة التقارير مع فريق الرعاية' : 'Share reports with care team'}
            desc={lang === 'ar' ? 'يرى أطباؤك قراءاتك وتقاريرك اليومية' : 'Your doctors can see your daily readings'} />
          <ToggleRow on={analytics} set={setAnalytics}
            title={lang === 'ar' ? 'تحليلات مجهولة' : 'Anonymous analytics'}
            desc={lang === 'ar' ? 'ساعدنا على تحسين التطبيق' : 'Help us improve the app'} />
          <ToggleRow on={research} set={setResearch} last
            title={lang === 'ar' ? 'المساهمة في الأبحاث' : 'Research contributions'}
            desc={lang === 'ar' ? 'بيانات مجهولة للأبحاث الطبية' : 'De-identified data for medical studies'} />
        </div>

        <PvSection icon="lock" title={lang === 'ar' ? 'الأمان' : 'Security'} />
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <ActionRow icon="mail" title={t('sec_email')} desc={authEmail || '—'} onClick={() => setChangeEmailOpen(true)} />
          <ToggleRow on={bioLock} set={setBioLock}
            title={lang === 'ar' ? 'قفل بالبصمة / الوجه' : 'Biometric app lock'}
            desc={lang === 'ar' ? 'افتح التطبيق ببصمتك' : 'Unlock the app with Face ID / fingerprint'} />
          <ToggleRow on={pinOpen} set={setPinOpen} last
            title={lang === 'ar' ? 'طلب رمز PIN عند الفتح' : 'Require PIN on open'}
            desc={lang === 'ar' ? 'طبقة حماية إضافية' : 'An extra layer of protection'} />
        </div>

        <PvSection icon="database" title={lang === 'ar' ? 'بياناتك' : 'Your data'} />
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <ActionRow icon="download" title={lang === 'ar' ? 'تصدير بياناتي' : 'Export my data'} desc={lang === 'ar' ? 'ملف PDF أو CSV' : 'As a PDF or CSV file'} />
          <ActionRow icon="folder-heart" title={lang === 'ar' ? 'تحميل السجلات الصحية' : 'Download health records'} desc={lang === 'ar' ? 'جميع التحاليل والأشعة' : 'All labs and scans'} />
          <ActionRow icon="app-window" last title={lang === 'ar' ? 'التطبيقات المتصلة' : 'Connected apps'} desc={lang === 'ar' ? 'إدارة الوصول للطرف الثالث' : 'Manage third-party access'} />
        </div>

        <PvSection icon="alert-triangle" title={lang === 'ar' ? 'منطقة الخطر' : 'Danger zone'} />
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <ActionRow icon="trash-2" danger last title={lang === 'ar' ? 'حذف حسابي' : 'Delete my account'} desc={lang === 'ar' ? 'حذف دائم لكل بياناتك' : 'Permanently erase all your data'} />
        </div>

        <p className="meta" style={{ textAlign: 'center', margin: '18px 0 0', display: 'flex', gap: 6, justifyContent: 'center', alignItems: 'center', color: 'var(--fg3)' }}>
          <Icon name="shield-check" size={14} />{lang === 'ar' ? 'بياناتك مشفّرة ومحمية' : 'Your data is encrypted and protected'}
        </p>
      </div>
      {changeEmailOpen && <ChangeEmailSheet onClose={() => setChangeEmailOpen(false)} />}
    </div>
  );
}

/* Medical profile screen */
function MedicalProfileScreen({ onBack }) {
  const { t, lang, account, setNavHidden } = useApp();
  useEffect(() => { setNavHidden(true); return () => setNavHidden(false); }, []);
  const [saved, setSaved]   = useState(false);
  const [blood, setBlood]   = useState(PATIENT.bloodType);
  const [weight, setWeight] = useState(String(PATIENT.weight));
  const [height, setHeight] = useState(String(PATIENT.height));

  const bmi = (() => {
    const w = parseFloat(weight), h = parseFloat(height) / 100;
    if (!w || !h || w <= 0 || h <= 0) return null;
    const v = w / (h * h);
    if (!isFinite(v)) return null;
    const cat = v < 18.5
      ? { key: 'bmi_under',  color: 'var(--petal-blue)',           bg: 'var(--petal-blue-50)' }
      : v < 25  ? { key: 'bmi_normal', color: 'var(--petal-mint-600)',       bg: 'var(--petal-mint-50)' }
      : v < 30  ? { key: 'bmi_over',   color: 'var(--balsm-expiring,#D97A20)', bg: '#FBF0E2' }
      :           { key: 'bmi_obese',  color: 'var(--balsm-danger)',          bg: '#FBEBE7' };
    const pct = Math.max(2, Math.min(98, ((v - 15) / (35 - 15)) * 100));
    return { value: v.toFixed(1), pct, ...cat };
  })();
  const [conds, setConds]   = useState(() => account.conditions.map(c => c[lang] || c.en));
  const [allergies, setAllergies] = useState(lang === 'ar' ? ['البنسلين', 'حبوب اللقاح'] : ['Penicillin', 'Pollen']);
  const [condInput, setCondInput] = useState('');
  const [algInput, setAlgInput]   = useState('');

  const [saving, setSaving] = useState(false);
  const save = () => { if (saving) return; setSaving(true); setTimeout(() => { setSaving(false); setSaved(true); setTimeout(() => setSaved(false), 2000); }, 850); };

  const SectionHead = ({ icon, title }) => (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '18px 0 10px', color: 'var(--fg2)', fontWeight: 700, fontSize: 'var(--pt-sm)' }}>
      <Icon name={icon} size={16} style={{ color: 'var(--app-accent)' }} />{title}
    </div>
  );
  const ChipEditor = ({ items, setItems, value, setValue, placeholder, tone }) => (
    <div className="card" style={{ padding: 16 }}>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: items.length ? 12 : 0 }}>
        {items.map((c, i) => (
          <span key={i} className="b-badge" style={{ background: tone.bg, color: tone.fg, display: 'inline-flex', alignItems: 'center', gap: 6, paddingInlineEnd: 6 }}>
            {c}
            <button onClick={() => setItems(items.filter((_, j) => j !== i))} aria-label="Remove"
              style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', padding: 0, color: tone.fg, opacity: 0.7 }}>
              <Icon name="x" size={13} />
            </button>
          </span>
        ))}
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        <input className="b-input" value={value} onChange={e => setValue(e.target.value)} placeholder={placeholder}
          onKeyDown={e => { if (e.key === 'Enter' && value.trim()) { setItems([...items, value.trim()]); setValue(''); } }}
          style={{ flex: 1, height: 44 }} />
        <button className="b-btn b-btn-md b-btn-secondary" style={{ width: 44, height: 44, padding: 0, flexShrink: 0 }}
          onClick={() => { if (value.trim()) { setItems([...items, value.trim()]); setValue(''); } }}>
          <Icon name="plus" size={18} />
        </button>
      </div>
    </div>
  );

  return (
    <div className="screen fade-in">
      <div className="pad-top" />
      <div className="appbar">
        <button className="round-btn" onClick={onBack} aria-label="Back">
          <Icon name="arrow-left" style={{ transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
        </button>
        <h1 style={{ flex: 1, margin: 0, fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', letterSpacing: '-0.01em', color: 'var(--fg1)' }}>{t('p_cond')}</h1>
        {saved && <span className="b-badge b-badge--success"><span className="b-badge__dot" />{t('pd_saved')}</span>}
      </div>
      <div className="screen-scroll" style={{ padding: '0 20px 28px' }}>

        <SectionHead icon="clipboard-list" title={lang === 'ar' ? 'الحالات المزمنة' : 'Chronic conditions'} />
        <ChipEditor items={conds} setItems={setConds} value={condInput} setValue={setCondInput}
          placeholder={lang === 'ar' ? 'أضف حالة…' : 'Add a condition…'}
          tone={{ bg: 'var(--app-accent-50)', fg: 'var(--app-accent-600)' }} />

        <SectionHead icon="alert-octagon" title={lang === 'ar' ? 'الحساسية' : 'Allergies'} />
        <ChipEditor items={allergies} setItems={setAllergies} value={algInput} setValue={setAlgInput}
          placeholder={lang === 'ar' ? 'أضف حساسية…' : 'Add an allergy…'}
          tone={{ bg: '#FBEBE7', fg: 'var(--balsm-danger)' }} />

        <SectionHead icon="droplet" title={lang === 'ar' ? 'فصيلة الدم' : 'Blood type'} />
        <div className="card" style={{ padding: 16 }}>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {['A+','A-','B+','B-','O+','O-','AB+','AB-'].map(bt => (
              <button key={bt} onClick={() => setBlood(bt)} style={{
                height: 40, padding: '0 14px', borderRadius: 'var(--radius-md)', cursor: 'pointer',
                border: `1.5px solid ${blood === bt ? 'var(--app-accent)' : 'var(--balsm-border)'}`,
                background: blood === bt ? 'var(--app-accent-50)' : '#fff',
                color: blood === bt ? 'var(--app-accent-600)' : 'var(--fg2)',
                fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 'var(--pt-sm)',
                transition: 'all var(--dur-fast) var(--ease-out)',
              }}>{bt}</button>
            ))}
          </div>
        </div>

        <SectionHead icon="ruler" title={lang === 'ar' ? 'القياسات' : 'Measurements'} />
        <div className="card" style={{ padding: 16 }}>
          <div style={{ display: 'flex', gap: 12 }}>
            <div className="field" style={{ flex: 1, margin: 0 }}>
              <label style={{ fontSize: 'var(--pt-xs)', fontWeight: 700, color: 'var(--fg3)', letterSpacing: '0.08em', textTransform: 'uppercase' }}>{`${t('pd_weight')} (${t('pd_kg')})`}</label>
              <input className="b-input num" dir="ltr" type="number" value={weight} onChange={e => setWeight(e.target.value)} />
            </div>
            <div className="field" style={{ flex: 1, margin: 0 }}>
              <label style={{ fontSize: 'var(--pt-xs)', fontWeight: 700, color: 'var(--fg3)', letterSpacing: '0.08em', textTransform: 'uppercase' }}>{`${t('pd_height')} (${t('pd_cm')})`}</label>
              <input className="b-input num" dir="ltr" type="number" value={height} onChange={e => setHeight(e.target.value)} />
            </div>
          </div>
          {bmi && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginTop: 14, paddingTop: 14, borderTop: '1px solid var(--balsm-ink-100)' }}>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: lang === 'ar' ? 'flex-end' : 'flex-start', flexShrink: 0 }}>
                <span style={{ fontSize: 'var(--pt-2xs)', fontWeight: 700, color: 'var(--fg3)', letterSpacing: '0.08em', textTransform: 'uppercase' }}>{t('bmi_label')}</span>
                <span className="num" style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-2xl)', color: 'var(--fg1)', lineHeight: 1.1 }}>{bmi.value}</span>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <span className="b-badge" style={{ background: bmi.bg, color: bmi.color, fontWeight: 700, fontSize: '11px' }}>{t(bmi.key)}</span>
                <div style={{ position: 'relative', height: 6, borderRadius: 99, marginTop: 8, background: 'linear-gradient(90deg, var(--petal-blue) 0%, var(--petal-mint) 33%, var(--balsm-expiring,#D97A20) 66%, var(--balsm-danger) 100%)' }}>
                  <div style={{ position: 'absolute', top: '50%', insetInlineStart: `${bmi.pct}%`, width: 12, height: 12, borderRadius: 99, background: '#fff', border: '2.5px solid var(--fg1)', transform: 'translate(-50%, -50%)' }} />
                </div>
              </div>
            </div>
          )}
        </div>

        <DSProgressButton block loading={saving} onClick={save} style={{ marginTop: 22 }}>
          {!saving && <Icon name={saved ? 'check' : 'save'} size={18} />}
          {saving ? (lang === 'ar' ? 'جارٍ الحفظ…' : 'Saving…') : (saved ? t('pd_saved') : t('pd_save'))}
        </DSProgressButton>
      </div>
    </div>
  );
}

function EmergencyScreen({ onBack }) {
  const { t, lang, setNavHidden } = useApp();
  useEffect(() => { setNavHidden(true); return () => setNavHidden(false); }, []);
  const contacts = [
    { key: 'em_ambulance', icon: 'ambulance', num: '123', color: 'var(--balsm-danger)',          bg: '#FBEBE7' },
    { key: 'em_police',    icon: 'shield',    num: '122', color: 'var(--petal-blue)',            bg: 'var(--petal-blue-50)' },
    { key: 'em_fire',      icon: 'flame',     num: '180', color: 'var(--balsm-expiring, #D97A20)', bg: '#FBF0E2' },
    { key: 'em_tourist',   icon: 'compass',   num: '126', color: 'var(--petal-violet)',          bg: 'var(--petal-violet-50)' },
  ];
  return (
    <div className="screen fade-in">
      <div className="pad-top" />
      <div className="appbar">
        <button className="round-btn" onClick={onBack} aria-label="Back">
          <Icon name="arrow-left" style={{ transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
        </button>
        <h1 style={{ flex: 1, margin: 0, fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', letterSpacing: '-0.01em', color: 'var(--fg1)' }}>{t('p_emergency')}</h1>
        <span className="meta" style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
          <Icon name="map-pin" size={12} />{t('em_eg')}
        </span>
      </div>
      <div className="screen-scroll" style={{ padding: '0 20px calc(env(safe-area-inset-bottom, 0px) + 40px)' }}>
        <p className="body-sm" style={{ margin: '2px 0 18px' }}>{t('em_intro')}</p>
        <div className="emergency-grid">
          {contacts.map(c => (
            <a key={c.key} href={`tel:${c.num}`} className="card emergency-tile">
              <div className="etile-ico" style={{ background: c.bg, color: c.color }}><Icon name={c.icon} /></div>
              <div className="etile-label">{t(c.key)}</div>
              <div className="etile-foot">
                <span className="etile-num num">{c.num}</span>
                <Icon name="phone" size={13} style={{ color: c.color }} />
              </div>
            </a>
          ))}
        </div>
        <div className="save-note" style={{ marginTop: 18 }}>
          <Icon name="phone-call" size={15} />{t('em_tap_call')}
        </div>
      </div>
    </div>
  );
}

function ProfileScreen() {
  const { t, lang, go, account, country, profileComplete, careTeamJump } = useApp();
  const [langSheet, setLangSheet]       = useState(false);
  const [countrySheet, setCountrySheet] = useState(false);
  const curLang = LANGUAGES.find(l => l.code === lang) || LANGUAGES[1];
  const [storageSheet, setStorageSheet] = useState(false);
  const [personalOpen, setPersonalOpen] = useState(false);
  const [careOpen, setCareOpen]         = useState(false);
  useEffect(() => { if (careTeamJump) setCareOpen(true); }, [careTeamJump]);
  const [privacyOpen, setPrivacyOpen]   = useState(false);
  const [medicalOpen, setMedicalOpen]   = useState(false);
  const [emergencyOpen, setEmergencyOpen] = useState(false);
  const [fbOpen, setFbOpen]             = useState(false);
  const [ecoOpen, setEcoOpen]           = useState(false);
  const [qrOpen, setQrOpen]             = useState(false);
  if (personalOpen) return <PersonalDetailsScreen onBack={() => setPersonalOpen(false)} />;
  if (careOpen)     return <CareTeamScreen onBack={() => setCareOpen(false)} />;
  if (privacyOpen)  return <PrivacyDataScreen onBack={() => setPrivacyOpen(false)} />;
  if (medicalOpen)  return <MedicalProfileScreen onBack={() => setMedicalOpen(false)} />;
  if (emergencyOpen) return <EmergencyScreen onBack={() => setEmergencyOpen(false)} />;
  const { storageProviders } = useApp();
  const primaryCfg = STORAGE_CFG[storageProviders.active] || STORAGE_CFG.local;
  const rows = [
    { icon: 'user',           key: 'p_personal', action: () => setPersonalOpen(true) },
    { icon: 'clipboard-list', key: 'p_cond',     action: () => setMedicalOpen(true) },
    { icon: 'stethoscope',    key: 'p_care',     action: () => setCareOpen(true) },
    { icon: 'siren',          key: 'p_emergency',action: () => setEmergencyOpen(true), tone: 'danger' },
    { icon: 'bell',           key: 'p_notif'    },
    { icon: 'shield-check',   key: 'p_privacy',  action: () => setPrivacyOpen(true) },
    { icon: 'star',           key: 'fb_row',     action: () => setFbOpen(true) },
    { icon: 'flower-2',       key: 'eco_row',    action: () => setEcoOpen(true) },
    { icon: 'life-buoy',      key: 'p_help'     },
  ];
  return (
    <div className="screen-scroll fade-in">
      <div className="pad-top" />
      <div className="appbar">
        <h1 className="grow">{t('profile')}</h1>
        <button className="round-btn" onClick={() => setQrOpen(true)} aria-label={lang === 'ar' ? 'مشاركة رمز QR' : 'Share my QR code'}>
          <Icon name="qr-code" />
        </button>
      </div>
      <div className="profile-head">
        <div className="avatar" style={{ background: account.color }}>{account.initials}</div>
        <div className="pname">{account.name[lang]}</div>
        <div className="pmeta">{t('since')} {account.since[lang]}</div>
        <button onClick={() => setQrOpen(true)} dir="ltr"
          style={{ margin: '10px auto 0', display: 'inline-flex', alignItems: 'center', gap: 7, height: 34, padding: '0 14px', borderRadius: 9999, border: '1px solid var(--app-accent-100, var(--balsm-ink-100))', background: 'var(--app-accent-50)', color: 'var(--app-accent-600)', fontSize: 'var(--pt-sm)', fontWeight: 700, cursor: 'pointer' }}>
          <Icon name="qr-code" size={15} />
          <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 600 }}>@{HANDLE_STORE.value}</span>
        </button>
        <div className="chip-wrap" style={{ justifyContent: 'center', marginTop: 12 }}>
          {account.conditions.map((c, i) => (
            <span key={i} className="b-badge" style={{ background: 'var(--balsm-ink-100)', color: 'var(--balsm-ink-700)' }}>{c[lang]}</span>
          ))}
        </div>
      </div>

      {!profileComplete && (
        <div className="card" style={{ margin: '0 var(--gutter, 20px) 14px', padding: 16, display: 'flex', alignItems: 'center', gap: 14, background: 'var(--app-accent-50)', cursor: 'pointer' }} onClick={() => setPersonalOpen(true)}>
          <div className="lico" style={{ background: 'var(--app-accent)', color: '#fff' }}><Icon name="user-round-pen" /></div>
          <div className="grow">
            <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{t('pc_title')}</div>
            <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg2)', marginTop: 2 }}>{t('pc_help')}</div>
          </div>
          <span className="rchev"><Icon name="chevron-right" /></span>
        </div>
      )}

      <div className="card list-card">
        <div className="list-row" onClick={() => setLangSheet(true)}>
          <div className="lico"><Icon name="languages" /></div>
          <div className="grow">{t('p_lang')}</div>
          <span style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', fontWeight: 600, fontFamily: curLang.rtl ? 'var(--font-arabic)' : 'var(--font-body)', marginInlineEnd: 8 }}>{curLang.native}</span>
          <span className="rchev"><Icon name="chevron-right" /></span>
        </div>
        <div className="list-row" onClick={() => setCountrySheet(true)}>
          <div className="lico" style={!country.home ? { background: 'var(--balsm-sun-500)', color: '#fff' } : undefined}><Icon name={country.home ? 'map-pin' : 'plane'} /></div>
          <div className="grow">{t('p_country')}</div>
          <span style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', fontWeight: 600, marginInlineEnd: 8 }}>{country.name[lang]}</span>
          <span className="rchev"><Icon name="chevron-right" /></span>
        </div>
      </div>

      {/* Storage & sync */}
      <div className="card list-card">
        <div className="list-row" onClick={() => setStorageSheet(true)}>
          <div className="lico" style={{ background: primaryCfg.bg, color: primaryCfg.color }}><Icon name={primaryCfg.icon} /></div>
          <div className="grow">{t('storage')}</div>
          <StorageBadge storage={storageProviders.active} size="xs" />
          <span className="rchev"><Icon name="chevron-right" /></span>
        </div>
      </div>

      <div className="card list-card">
        {rows.map(r => (
          <div key={r.key} className="list-row" onClick={r.action}>
            <div className="lico" style={r.tone === 'danger' ? { background: '#FBEBE7', color: 'var(--balsm-danger)' } : undefined}><Icon name={r.icon} /></div>
            <div className="grow">{t(r.key)}</div>
            <span className="rchev"><Icon name="chevron-right" /></span>
          </div>
        ))}
      </div>

      <div className="px-20" style={{ paddingBottom: 24 }}>
        <button className="b-btn b-btn-md b-btn-secondary b-btn--full" style={{ color: 'var(--balsm-danger)' }} onClick={() => go('welcome')}>
          <Icon name="log-out" size={18} />{t('p_signout')}
        </button>
      </div>

      {langSheet    && <LanguageSheet    onClose={() => setLangSheet(false)} />}
      {countrySheet  && <CountrySheet     onClose={() => setCountrySheet(false)} />}
      {storageSheet  && <StorageSyncSheet onClose={() => setStorageSheet(false)} />}
      {fbOpen        && <FeedbackSheet    onClose={() => setFbOpen(false)} />}
      {ecoOpen       && <EcosystemSheet   onClose={() => setEcoOpen(false)} onFeedback={() => setFbOpen(true)} />}
      {qrOpen        && <QRShareSheet handle={HANDLE_STORE.value} name={account.name[lang]} onClose={() => setQrOpen(false)} />}
    </div>
  );
}

Object.assign(window, { PROVIDER_TYPES, providerType, HomeScreen, TrendsScreen, MedsScreen, ProfileScreen, PersonalDetailsScreen, CareTeamScreen, PrivacyDataScreen, MedicalProfileScreen, EmergencyScreen, LineChart, HistoryRow, AccountSwitcherSheet });
