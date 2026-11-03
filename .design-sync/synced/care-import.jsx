/* care-import.jsx — build care-team records from the phone's contacts.
   Uses the Contact Picker API where the browser offers it; otherwise shows
   the address book in-app so the flow is the same everywhere. */

const CI_DEMO_CONTACTS = [
  { name: 'Dr. Sara Kamal', tel: ['+201002345678'], email: 'sara.kamal@maadimedical.eg' },
  { name: 'د. أحمد منصور', tel: ['+201225558810', '+20223584400'] },
  { name: 'El Ezaby Pharmacy', tel: ['+20219600'] },
  { name: 'صيدلية الشفاء', tel: ['+20223584411'] },
  { name: 'Alfa Lab — Maadi', tel: ['+20233331200'], email: 'maadi@alfalab.eg' },
  { name: 'Nurse Mona Adel', tel: ['+201114092231'] },
  { name: 'Cleopatra Hospital', tel: ['+20224143931'] },
  { name: 'Physio Karim Nabil', tel: ['+201063310098'] },
  { name: 'أمي', tel: ['+201007771234'] },
  { name: 'Omar Hassan', tel: ['+201283004455'], email: 'omar.h@gmail.com' },
  { name: 'Dr. Hany Fawzy', tel: ['+201019988770', '+20227350011'] },
  { name: 'Yasmin (neighbour)', tel: ['+201550021122'] },
];

const ciGuessType = (name) => {
  const n = (name || '').toLowerCase();
  if (/^(dr\.?\s|د\.|دكتور)/.test(n) || /\bdoctor\b/.test(n)) return 'doctor';
  if (/pharm|صيدل/.test(n)) return 'pharmacy';
  if (/\blab\b|laborator|معمل|مختبر|تحاليل/.test(n)) return 'lab';
  if (/nurse|ممرض/.test(n)) return 'nurse';
  if (/physio|علاج طبيعي/.test(n)) return 'physio';
  if (/clinic|hospital|centre|center|عيادة|مستشفى|مركز/.test(n)) return 'clinic';
  if (/carer|caregiver|جليس|مرافق/.test(n)) return 'carer';
  return 'other';
};
/* Opens the OS contact picker (Android Chrome). Must run inside a tap handler.
   Returns null when the browser has no picker, [] when the user cancels. */
const ciHasNative = () => typeof navigator !== 'undefined' && !!navigator.contacts && typeof navigator.contacts.select === 'function';
async function pickNativeContacts() {
  if (!ciHasNative()) return null;
  try {
    const res = await navigator.contacts.select(['name', 'tel', 'email'], { multiple: true });
    return (res || []).map((c, i) => {
      const name = ((c.name && c.name[0]) || (c.tel && c.tel[0]) || '').trim();
      return { id: 'n' + Date.now() + i, name, tel: c.tel || [], email: (c.email && c.email[0]) || '', type: ciGuessType(name) };
    }).filter(c => c.name);
  } catch (e) { return []; }
}
const ciKey = (tel) => (tel || '').replace(/\D/g, '').slice(-9);
const ciInitials = (name) => {
  const w = (name || '').replace(/^(dr\.?|د\.)\s*/i, '').trim().split(/\s+/).filter(Boolean);
  return ((w[0] || '?')[0] + (w[1] ? w[1][0] : '')).toUpperCase();
};

function ContactImportSheet({ existing = [], initial = null, onImport, onManual, onClose }) {
  const { lang } = useApp();
  const ar = lang === 'ar';
  const hasNative = ciHasNative();
  const taken0 = new Set(existing.map(ciKey).filter(Boolean));
  const [contacts, setContacts] = React.useState(() => initial || CI_DEMO_CONTACTS.map((c, i) => ({ ...c, id: 'c' + i, type: ciGuessType(c.name) })));
  const [sel, setSel] = React.useState(() => initial ? initial.filter(c => !taken0.has(ciKey(c.tel[0]))).map(c => c.id) : []);
  const [q, setQ] = React.useState('');
  const [typeFor, setTypeFor] = React.useState(null);
  const taken = new Set(existing.map(ciKey).filter(Boolean));

  const pickNative = async () => {
    const list = await pickNativeContacts();
    if (!list || !list.length) return;
    setContacts(cs => {
      const have = new Set(cs.map(c => ciKey(c.tel[0])));
      return [...cs, ...list.filter(c => !have.has(ciKey(c.tel[0])))];
    });
    setSel(s => [...new Set([...s, ...list.filter(c => !taken.has(ciKey(c.tel[0]))).map(c => c.id)])]);
  };

  const nq = dcNorm(q.trim());
  const shown = contacts.filter(c => !nq || dcNorm(c.name + ' ' + (c.tel || []).join(' ')).includes(nq));
  const selectable = shown.filter(c => !taken.has(ciKey(c.tel[0])));
  const allOn = selectable.length > 0 && selectable.every(c => sel.includes(c.id));
  const toggle = (id) => setSel(s => s.includes(id) ? s.filter(x => x !== id) : [...s, id]);
  const toggleAll = () => setSel(s => allOn ? s.filter(id => !selectable.some(c => c.id === id)) : [...new Set([...s, ...selectable.map(c => c.id)])]);
  const setType = (id, type) => { setContacts(cs => cs.map(c => c.id === id ? { ...c, type } : c)); setTypeFor(null); };

  const doImport = () => {
    const stamp = Date.now();
    const recs = contacts.filter(c => sel.includes(c.id)).map((c, i) => ({
      id: 'mine_' + stamp + '_' + i, mine: true, fromContacts: true, type: c.type,
      name: c.name.trim(), specialty: '', phone: c.tel[0] || '', phone2: c.tel[1] || '',
      email: c.email || '', clinic: '', address: '', mapUrl: '', notes: '',
    }));
    if (recs.length) onImport(recs);
  };

  const fmt = (t) => t.replace(/^\+20(1\d)(\d{4})(\d{4})$/, '+20 $1 $2 $3').replace(/^\+20(2)(\d{4})(\d{4})$/, '+20 $1 $2 $3');
  const eyebrow = { fontSize: 'var(--pt-xs)', fontWeight: 700, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--fg3)' };

  return (
    <>
      <style>{`@keyframes stSlideUp{from{transform:translateY(110%)}to{transform:none}}`}</style>
      <div className="app-scrim" onClick={onClose} style={{ position: 'absolute', inset: 0, zIndex: 40, background: 'rgba(20,32,43,0.36)', backdropFilter: 'blur(2px)' }}></div>
      <div className="app-sheet" style={{ position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 41, background: '#fff', borderRadius: '20px 20px 0 0', height: '88%', display: 'flex', flexDirection: 'column', animation: 'stSlideUp 0.3s cubic-bezier(0.16,1,0.3,1) both' }}>
        <div style={{ padding: '10px 20px 0', flexShrink: 0 }}>
          <div className="sheet-grab" style={{ margin: '0 auto 12px' }}></div>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: 12, borderBottom: '1px solid var(--balsm-ink-100)' }}>
            <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-lg)', color: 'var(--fg1)' }}>{initial ? (ar ? 'مراجعة جهات الاتصال' : 'Review contacts') : (ar ? 'إضافة من جهات الاتصال' : 'Add from contacts')}</div>
            <button className="round-btn ghost" onClick={onClose} aria-label={ar ? 'إغلاق' : 'Close'}><Icon name="x" size={17} /></button>
          </div>
        </div>
        <div style={{ flex: 1, overflowY: 'auto', padding: '12px 20px 16px' }}>
          <p className="meta" style={{ margin: '0 0 14px', fontSize: 'var(--pt-xs)', lineHeight: 1.5 }}>
            {initial
              ? (ar ? 'راجع النوع لكل جهة اتصال، ثم أضفها. يبقى كل سجل على جهازك.' : 'Check each contact’s type, then add them. Every record stays on your device.')
              : (ar ? 'اختر من يرعاك. ننشئ سجلًا لكل جهة اتصال، ويبقى على جهازك. يمكنك إضافة التفاصيل لاحقًا.' : 'Pick the people and places caring for you. Each becomes a care-team record on your device — add details any time.')}
          </p>
          {hasNative && (
            <button className="b-btn b-btn-md b-btn-secondary b-btn--full" onClick={pickNative} style={{ gap: 8, marginBottom: 14 }}>
              <Icon name="contact-round" size={16} />{initial ? (ar ? 'اختيار المزيد من جهات الاتصال' : 'Choose more contacts') : (ar ? 'فتح جهات اتصال الهاتف' : 'Open phone contacts')}
            </button>
          )}
          <div style={{ position: 'relative', marginBottom: 12 }}>
            <Icon name="search" size={17} style={{ position: 'absolute', insetInlineStart: 14, top: '50%', transform: 'translateY(-50%)', color: 'var(--fg3)', pointerEvents: 'none' }} />
            <input className="b-input" value={q} onChange={e => setQ(e.target.value)} placeholder={ar ? 'ابحث في جهات الاتصال' : 'Search contacts'} style={{ paddingInlineStart: 42 }} />
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
            <span style={{ ...eyebrow, flex: 1 }}>{ar ? `جهات الاتصال · ${shown.length}` : `Contacts · ${shown.length}`}</span>
            {selectable.length > 0 && (
              <button className="b-btn b-btn-sm b-btn-ghost" onClick={toggleAll} style={{ height: 28, padding: '0 8px', fontSize: 'var(--pt-xs)', fontWeight: 700, color: 'var(--app-accent)' }}>
                {allOn ? (ar ? 'إلغاء التحديد' : 'Clear') : (ar ? 'تحديد الكل' : 'Select all')}
              </button>
            )}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            {shown.map(c => {
              const done = taken.has(ciKey(c.tel[0]));
              const on = sel.includes(c.id);
              const pt = providerType(c.type);
              return (
                <div key={c.id} style={{ borderBottom: '1px solid var(--balsm-ink-100)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12, minHeight: 60, padding: '8px 0', opacity: done ? 0.55 : 1 }}>
                    <button onClick={() => !done && toggle(c.id)} disabled={done} aria-pressed={on}
                      style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 12, background: 'none', border: 'none', padding: 0, cursor: done ? 'default' : 'pointer', textAlign: 'start', font: 'inherit' }}>
                      <span style={{ width: 22, height: 22, borderRadius: 6, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', border: `1.5px solid ${on ? 'var(--app-accent)' : 'var(--balsm-border-strong)'}`, background: on ? 'var(--app-accent)' : '#fff', color: '#fff', transition: 'all var(--dur-fast) var(--ease-out)' }}>
                        {on && <Icon name="check" size={14} stroke={2.6} />}
                      </span>
                      <span style={{ width: 40, height: 40, borderRadius: 9999, flexShrink: 0, background: 'var(--balsm-ink-100)', color: 'var(--fg2)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 'var(--pt-sm)' }}>{ciInitials(c.name)}</span>
                      <span style={{ flex: 1, minWidth: 0 }}>
                        <span style={{ display: 'block', fontWeight: 600, fontSize: 'var(--pt-sm)', color: 'var(--fg1)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.name}</span>
                        <span dir="ltr" className="num" style={{ display: 'block', fontSize: 'var(--pt-xs)', color: 'var(--fg3)', marginTop: 2, textAlign: ar ? 'right' : 'left' }}>
                          {c.tel[0] ? fmt(c.tel[0]) : ''}{c.tel.length > 1 ? ` +${c.tel.length - 1}` : ''}
                        </span>
                      </span>
                    </button>
                    {done ? (
                      <span className="b-badge" style={{ background: 'var(--balsm-ink-50)', color: 'var(--fg3)', fontSize: '10px', fontWeight: 700, flexShrink: 0 }}>{ar ? 'في فريقك' : 'On your team'}</span>
                    ) : on && (
                      <button onClick={() => setTypeFor(typeFor === c.id ? null : c.id)}
                        style={{ flexShrink: 0, display: 'inline-flex', alignItems: 'center', gap: 5, height: 30, padding: '0 10px', borderRadius: 'var(--radius-pill)', cursor: 'pointer', border: '1px solid var(--app-accent)', background: 'var(--app-accent-50)', color: 'var(--app-accent-600)', fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-body)', fontWeight: 700, fontSize: 'var(--pt-xs)' }}>
                        <Icon name={pt.icon} size={13} />{pt[lang]}<Icon name="chevron-down" size={12} />
                      </button>
                    )}
                  </div>
                  {on && typeFor === c.id && (
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, padding: '0 0 12px 34px', paddingInlineStart: 34, paddingInlineEnd: 0 }}>
                      {PROVIDER_TYPES.map(p => {
                        const act = c.type === p.id;
                        return (
                          <button key={p.id} onClick={() => setType(c.id, p.id)}
                            style={{ display: 'inline-flex', alignItems: 'center', gap: 5, height: 32, padding: '0 11px', borderRadius: 'var(--radius-pill)', cursor: 'pointer', border: `1px solid ${act ? 'var(--app-accent)' : 'var(--balsm-border)'}`, background: act ? 'var(--app-accent-50)' : '#fff', color: act ? 'var(--app-accent-600)' : 'var(--fg2)', fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-body)', fontWeight: act ? 700 : 600, fontSize: 'var(--pt-xs)' }}>
                            <Icon name={p.icon} size={13} />{p[lang]}
                          </button>
                        );
                      })}
                    </div>
                  )}
                </div>
              );
            })}
            {shown.length === 0 && (
              <p className="meta" style={{ textAlign: 'center', padding: '24px 0 8px' }}>{ar ? 'لا توجد جهات اتصال مطابقة.' : 'No matching contacts.'}</p>
            )}
          </div>
        </div>
        <div style={{ flexShrink: 0, padding: '12px 20px 28px', borderTop: '1px solid var(--balsm-ink-100)', display: 'flex', flexDirection: 'column', gap: 6 }}>
          <button className="b-btn b-btn-lg b-btn-primary b-btn--full" disabled={!sel.length} onClick={doImport}>
            {sel.length
              ? (ar ? `إضافة ${sel.length} إلى فريق الرعاية` : `Add ${sel.length} to care team`)
              : (ar ? 'اختر جهات اتصال' : 'Select contacts')}
          </button>
          <button className="b-btn b-btn-md b-btn-ghost b-btn--full" onClick={onManual} style={{ gap: 7, color: 'var(--fg3)' }}>
            <Icon name="pencil-line" size={15} />{ar ? 'ليس في جهات الاتصال؟ أضف يدويًا' : 'Not in your contacts? Add manually'}
          </button>
        </div>
      </div>
    </>
  );
}

Object.assign(window, { ContactImportSheet, pickNativeContacts, ciHasNative });
