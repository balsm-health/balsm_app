/* storage.jsx — where each kind of data lives, and user-triggered sync to any connected cloud.
   This device always holds a copy; each data category can additionally sync to any connected cloud. */

const { Modal } = window.BalsmDesignSystem_1cf4c7;

const STORAGE_CFG = {
  local:  { icon: 'smartphone',  label: { en: 'This device',   ar: 'هذا الجهاز'  }, color: 'var(--balsm-ink-600)', bg: 'var(--balsm-ink-50)',  border: 'var(--balsm-ink-200)' },
  icloud: { icon: 'brand-icloud',       label: { en: 'iCloud',        ar: 'آي كلاود'    }, color: '#1783FF',              bg: '#EAF2FF',               border: '#C0D8FF'              },
  gdrive: { icon: 'brand-gdrive', label: { en: 'Google Drive',  ar: 'جوجل درايف'  }, color: '#1E8E3E',              bg: '#E6F4EA',               border: '#B3DFBB'              },
  balsmcloud: { icon: 'brand-balsm',  label: { en: 'Balsm Cloud',   ar: 'بلسم كلاود'  }, color: 'var(--petal-aqua-600, #019A95)', bg: 'var(--petal-aqua-50, #E6F8F7)', border: 'var(--balsm-ink-200)' },
};
const CLOUDS = ['icloud', 'gdrive', 'balsmcloud'];

const DATA_CATS = [
  { id: 'records',  icon: 'folder',          en: 'Medical records',       ar: 'السجلات الطبية' },
  { id: 'rx',       icon: 'file-text',       en: 'Prescriptions',         ar: 'الوصفات' },
  { id: 'meds',     icon: 'pill',            en: 'Medications',           ar: 'الأدوية' },
  { id: 'checkins', icon: 'clipboard-check', en: 'Daily check-ins',       ar: 'المتابعة اليومية' },
  { id: 'symptoms', icon: 'activity',        en: 'Symptoms',              ar: 'الأعراض' },
  { id: 'vitals',   icon: 'heart-pulse',     en: 'Vitals',                ar: 'المؤشرات الحيوية' },
  { id: 'medical',  icon: 'clipboard-list',  en: 'Conditions & allergies',ar: 'الحالات والحساسية' },
  { id: 'care',     icon: 'users',           en: 'Care team',             ar: 'فريق الرعاية' },
  { id: 'appts',    icon: 'calendar',        en: 'Appointments',          ar: 'المواعيد' },
];
const dataCat = (id) => DATA_CATS.find(c => c.id === id) || DATA_CATS[0];

function StorageBadge({ storage, size = 'sm' }) {
  const { lang } = useApp();
  const cfg = STORAGE_CFG[storage] || STORAGE_CFG.local;
  const isXs = size === 'xs';
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: isXs ? 3 : 4, padding: isXs ? '2px 6px' : '3px 8px', borderRadius: 'var(--radius-pill)', border: `1px solid ${cfg.border}`, background: cfg.bg, color: cfg.color, fontSize: isXs ? '10px' : 'var(--pt-2xs)', fontWeight: 600, flexShrink: 0, fontFamily: lang === 'ar' ? 'var(--font-arabic)' : 'var(--font-body)', whiteSpace: 'nowrap' }}>
      <Icon name={cfg.icon} size={isXs ? 10 : 12} stroke={2} />
      {cfg.label[lang] || cfg.label.en}
    </span>
  );
}

const syncAgo = (at, ar) => {
  if (!at) return ar ? 'لم تتم المزامنة بعد' : 'Not synced yet';
  const s = Math.round((Date.now() - at) / 1000);
  if (s < 60) return ar ? 'تمت المزامنة الآن' : 'Synced just now';
  const m = Math.round(s / 60);
  return ar ? `تمت المزامنة قبل ${m} د` : `Synced ${m} min ago`;
};

/* Stacked location icons: device + each cloud this category syncs to */
function LocIcons({ targets, size = 22 }) {
  const all = ['local', ...targets];
  return (
    <span style={{ display: 'inline-flex', flexShrink: 0 }}>
      {all.map((p, i) => {
        const c = STORAGE_CFG[p];
        return (
          <span key={p} style={{ width: size, height: size, borderRadius: 999, background: c.bg, color: c.color, border: '1.5px solid #fff', marginInlineStart: i ? -6 : 0, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', zIndex: all.length - i }}>
            <Icon name={c.icon} size={Math.round(size * 0.55)} stroke={2} />
          </span>
        );
      })}
    </span>
  );
}

const locSummary = (targets, lang) => {
  const ar = lang === 'ar';
  if (!targets.length) return ar ? 'على هذا الجهاز فقط' : 'This device only';
  if (targets.length === 1) return (ar ? 'الجهاز و' : 'Device + ') + STORAGE_CFG[targets[0]].label[lang];
  return ar ? `الجهاز و${targets.length} سحابات` : `Device + ${targets.length} clouds`;
};

/* Per-category (or 'all') sync editor */
function CategorySyncBody({ cat, onBack, onDone }) {
  const { lang, storageProviders, connectCloud, dataSync, syncData, accountMode } = useApp();
  const offlineAcct = accountMode === 'offline';
  const ar = lang === 'ar';
  const isAll = cat === 'all';
  const cur = isAll ? [...new Set(DATA_CATS.flatMap(c => (dataSync[c.id] || {}).targets || []))] : ((dataSync[cat] || {}).targets || []);
  const at = isAll ? null : (dataSync[cat] || {}).at;
  const [sel, setSel] = useState(cur);
  const [connecting, setConnecting] = useState(null);
  const [phase, setPhase] = useState('idle'); // idle | syncing | done
  const c = isAll ? { icon: 'layers', en: 'All your data', ar: 'كل بياناتك' } : dataCat(cat);
  const changed = sel.length !== cur.length || sel.some(p => !cur.includes(p));
  const removed = cur.filter(p => !sel.includes(p));

  const connect = (p) => { setConnecting(p); setTimeout(() => { connectCloud(p); setSel(s => [...s, p]); setConnecting(null); }, 900); };
  const toggle = (p) => setSel(s => s.includes(p) ? s.filter(x => x !== p) : [...s, p]);
  const run = () => {
    setPhase('syncing');
    setTimeout(() => { syncData(isAll ? DATA_CATS.map(d => d.id) : [cat], sel); setPhase('done'); setTimeout(() => onDone && onDone(), 1100); }, sel.length ? 1300 : 500);
  };

  const btnLabel = phase === 'syncing' ? (ar ? 'جارٍ المزامنة…' : 'Syncing…')
    : phase === 'done' ? (ar ? 'تم' : 'Done')
    : !sel.length && removed.length ? (ar ? 'الإبقاء على الجهاز فقط' : 'Keep on this device only')
    : changed ? (ar ? 'حفظ ومزامنة' : 'Save & sync')
    : (ar ? 'مزامنة الآن' : 'Sync now');

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14, paddingTop: 8 }}>
      {onBack && (
        <button onClick={onBack} style={{ alignSelf: 'flex-start', display: 'inline-flex', alignItems: 'center', gap: 6, background: 'none', border: 'none', padding: 0, cursor: 'pointer', color: 'var(--app-accent)', fontWeight: 700, fontSize: 'var(--pt-sm)', fontFamily: 'inherit' }}>
          <Icon name="arrow-left" size={15} style={{ transform: ar ? 'scaleX(-1)' : 'none' }} />{ar ? 'كل البيانات' : 'All data'}
        </button>
      )}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{ width: 42, height: 42, borderRadius: 'var(--radius-md)', background: 'var(--balsm-ink-50)', color: 'var(--fg2)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Icon name={c.icon} size={20} /></div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{c[lang]}</div>
          <div className="meta" style={{ fontSize: 'var(--pt-xs)', marginTop: 2 }}>{isAll ? (ar ? 'يُطبَّق على كل الفئات' : 'Applies to every category') : `${locSummary(cur, lang)} · ${syncAgo(cur.length ? at : null, ar)}`}</div>
        </div>
      </div>

      <div style={{ fontSize: 'var(--pt-xs)', fontWeight: 700, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--fg3)', marginTop: 4 }}>{ar ? 'أين تُحفظ' : 'Stored in'}</div>
      <div style={{ display: 'flex', flexDirection: 'column', borderRadius: 'var(--radius-lg)', border: '1px solid var(--balsm-border)', overflow: 'hidden' }}>
        {['local', ...CLOUDS].map((p, i) => {
          const cfg = STORAGE_CFG[p];
          const isLocal = p === 'local';
          const locked = p === 'balsmcloud' && offlineAcct;
          const connected = isLocal || (!locked && storageProviders[p]);
          const on = isLocal || (!locked && sel.includes(p));
          return (
            <div key={p} onClick={() => !isLocal && !locked && connected && phase === 'idle' && toggle(p)}
              style={{ display: 'flex', alignItems: 'center', gap: 12, minHeight: 60, padding: '10px 14px', borderTop: i ? '1px solid var(--balsm-ink-100)' : 'none', cursor: !isLocal && connected ? 'pointer' : 'default', background: on && !isLocal ? cfg.bg : '#fff', transition: 'background var(--dur-fast) var(--ease-out)' }}>
              <div style={{ width: 36, height: 36, borderRadius: 'var(--radius-md)', background: cfg.icon.startsWith('brand-') ? (on ? '#fff' : 'var(--balsm-ink-100)') : (on ? cfg.color : 'var(--balsm-ink-100)'), boxShadow: cfg.icon.startsWith('brand-') && on ? 'inset 0 0 0 1px var(--balsm-ink-200)' : 'none', color: on ? '#fff' : 'var(--fg3)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Icon name={cfg.icon} size={cfg.icon.startsWith('brand-') ? 20 : 18} muted={!on} /></div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 600, fontSize: 'var(--pt-sm)', color: 'var(--fg1)' }}>{cfg.label[lang]}</div>
                <div className="meta" style={{ fontSize: 'var(--pt-xs)', marginTop: 1 }}>
                  {isLocal ? (ar ? 'نسخة دائمة، تعمل دون إنترنت' : 'Always kept here — works offline')
                    : locked ? (ar ? 'يتطلب حسابًا متصلًا' : 'Needs an online account')
                    : !connected ? (ar ? 'غير مربوط' : 'Not connected')
                    : on ? (cur.includes(p) ? (ar ? 'تتم المزامنة' : 'Syncing here') : (ar ? 'ستتم المزامنة' : 'Will sync'))
                    : cur.includes(p) ? (ar ? 'ستُزال من هنا' : 'Will be removed from here') : (ar ? 'مربوط' : 'Connected')}
                </div>
              </div>
              {isLocal || locked ? <Icon name="lock" size={16} style={{ color: 'var(--fg3)' }} />
                : !connected ? (
                  <button className="b-btn b-btn-sm b-btn-secondary" disabled={!!connecting || phase !== 'idle'} onClick={(e) => { e.stopPropagation(); connect(p); }} style={{ minWidth: 84 }}>
                    {connecting === p ? <Icon name="loader" size={14} style={{ animation: 'spin 0.9s linear infinite' }} /> : (ar ? 'ربط' : 'Connect')}
                  </button>
                ) : (
                  <span style={{ width: 22, height: 22, borderRadius: 6, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', border: `1.5px solid ${on ? cfg.color : 'var(--balsm-border-strong)'}`, background: on ? cfg.color : '#fff', color: '#fff' }}>
                    {on && <Icon name="check" size={14} stroke={2.6} />}
                  </span>
                )}
            </div>
          );
        })}
      </div>

      {removed.length > 0 && (
        <div style={{ display: 'flex', gap: 10, padding: '11px 14px', borderRadius: 'var(--radius-lg)', background: '#FEF3F2', fontSize: 'var(--pt-xs)', lineHeight: 1.5, color: 'var(--fg1)' }}>
          <Icon name="cloud-off" size={16} style={{ color: 'var(--balsm-danger)', flexShrink: 0, marginTop: 1 }} />
          <span>{ar ? `ستُحذف النسخة من ${removed.map(p => STORAGE_CFG[p].label.ar).join('، ')}. تبقى على هذا الجهاز.` : `The copy in ${removed.map(p => STORAGE_CFG[p].label.en).join(', ')} will be deleted. It stays on this device.`}</span>
        </div>
      )}

      <button className={`b-btn b-btn-lg b-btn-${!sel.length && removed.length ? 'danger' : 'primary'} b-btn--full`} disabled={phase !== 'idle' || (!changed && !sel.length)} onClick={run} style={{ gap: 8 }}>
        {phase === 'syncing' && <Icon name="refresh-cw" size={16} style={{ animation: 'spin 0.9s linear infinite' }} />}
        {phase === 'done' && <Icon name="check" size={16} />}
        {btnLabel}
      </button>
      <p className="meta" style={{ margin: 0, fontSize: 'var(--pt-xs)', lineHeight: 1.5, textAlign: 'center' }}>
        {ar ? 'تُشفَّر بياناتك على هذا الهاتف قبل رفعها. أنت من يختار مكانها.' : 'Encrypted on this phone before upload. You choose where it goes.'}
      </p>
    </div>
  );
}

/* Header pill — shows where this screen's data lives; tap to change or sync */
function DataLocPill({ cat, compact }) {
  const { lang, dataSync } = useApp();
  const [open, setOpen] = useState(false);
  const btnRef = React.useRef(null);
  const host = open && btnRef.current ? (btnRef.current.closest('.screen, .screen-scroll') || document.body) : null;
  const targets = (dataSync[cat] || {}).targets || [];
  const label = !targets.length ? (lang === 'ar' ? 'الجهاز' : 'Device') : targets.length === 1 ? STORAGE_CFG[targets[0]].label[lang] : (lang === 'ar' ? `${targets.length + 1} أماكن` : `${targets.length + 1} places`);
  return (
    <>
      <button ref={btnRef} onClick={() => setOpen(true)} aria-label={`${lang === 'ar' ? 'مكان الحفظ' : 'Stored on'}: ${locSummary(targets, lang)}`}
        style={{ flexShrink: 0, display: 'inline-flex', alignItems: 'center', gap: 6, height: 34, padding: compact ? 5 : '0 10px 0 5px', paddingInlineStart: 5, paddingInlineEnd: compact ? 5 : 10, minWidth: 34, justifyContent: 'center', borderRadius: 999, border: '1px solid var(--balsm-border)', background: '#fff', cursor: 'pointer', fontFamily: lang === 'ar' ? 'var(--font-arabic)' : 'var(--font-body)', fontSize: 'var(--pt-xs)', fontWeight: 600, color: 'var(--fg2)' }}>
        <LocIcons targets={targets} size={24} />
        {!compact && label}
      </button>
      {open && host && ReactDOM.createPortal(
        <Modal open onClose={() => setOpen(false)} closeOnScrim
          title={<span style={{ display: 'flex', alignItems: 'center', gap: 10 }}><Icon name="hard-drive" size={19} style={{ color: 'var(--fg3)' }} />{lang === 'ar' ? 'مكان الحفظ' : 'Where it’s stored'}</span>}>
          <style>{`@keyframes spin{to{transform:rotate(360deg)}}`}</style>
          <CategorySyncBody cat={cat} onDone={() => setOpen(false)} />
        </Modal>, host
      )}
    </>
  );
}

/* Storage & sync — cloud accounts + a map of every data category */
function StorageSyncSheet({ onClose }) {
  const { t, lang, storageProviders, connectCloud, disconnectCloud, dataSync, accountMode } = useApp();
  const ar = lang === 'ar';
  const offlineAcct = accountMode === 'offline';
  const [view, setView] = useState(null); // null | cat id | 'all'
  const [connecting, setConnecting] = useState(null);
  const [confirmOff, setConfirmOff] = useState(null);
  const connected = CLOUDS.filter(p => storageProviders[p]);
  const eyebrow = { fontSize: 'var(--pt-xs)', fontWeight: 700, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--fg3)' };

  const connect = (p) => { setConnecting(p); setTimeout(() => { connectCloud(p); setConnecting(null); }, 900); };

  return (
    <Modal open onClose={onClose} closeOnScrim
      title={<span style={{ display: 'flex', alignItems: 'center', gap: 10 }}><Icon name="hard-drive" size={20} style={{ color: 'var(--fg3)' }} />{t('storage')}</span>}>
      <style>{`@keyframes spin{to{transform:rotate(360deg)}}`}</style>
      {view ? <CategorySyncBody key={view} cat={view} onBack={() => setView(null)} onDone={() => setView(null)} /> : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, paddingTop: 8 }}>
          <p className="meta" style={{ margin: 0, lineHeight: 1.5 }}>{offlineAcct
            ? (ar ? 'كل شيء محفوظ على هذا الجهاز. حسابك غير متصل، لذا يمكنك المزامنة مع آي كلاود أو جوجل درايف فقط.' : 'Everything is kept on this device. Your account is device-only, so you can sync to iCloud or Google Drive only.')
            : (ar ? 'كل شيء محفوظ على هذا الجهاز. اختر ما تريد مزامنته، وإلى أي سحابة.' : 'Everything is kept on this device. Choose what to sync, and to which cloud.')}</p>

          <div style={{ ...eyebrow, marginTop: 6 }}>{ar ? 'حسابات السحابة' : 'Cloud accounts'}</div>
          <div style={{ display: 'flex', flexDirection: 'column', borderRadius: 'var(--radius-lg)', border: '1px solid var(--balsm-border)', overflow: 'hidden' }}>
            {CLOUDS.map((p, i) => {
              const cfg = STORAGE_CFG[p];
              const locked = p === 'balsmcloud' && offlineAcct;
              const on = !locked && storageProviders[p];
              const used = DATA_CATS.filter(c => ((dataSync[c.id] || {}).targets || []).includes(p)).length;
              if (locked) return (
                <div key={p} style={{ borderTop: i ? '1px solid var(--balsm-ink-100)' : 'none', display: 'flex', alignItems: 'center', gap: 12, minHeight: 60, padding: '10px 14px', background: 'var(--balsm-ink-50)' }}>
                  <div style={{ width: 36, height: 36, borderRadius: 'var(--radius-md)', background: 'var(--balsm-ink-100)', color: 'var(--fg3)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Icon name={cfg.icon} size={cfg.icon.startsWith('brand-') ? 20 : 18} muted /></div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontWeight: 600, fontSize: 'var(--pt-sm)', color: 'var(--fg2)' }}>{cfg.label[lang]}</div>
                    <div className="meta" style={{ fontSize: 'var(--pt-xs)', marginTop: 1, lineHeight: 1.4 }}>{ar ? 'يتطلب حسابًا متصلًا. اتصل بالإنترنت من «البيانات الشخصية».' : 'Needs an online account. Go online from Personal details.'}</div>
                  </div>
                  <Icon name="lock" size={16} style={{ color: 'var(--fg3)', flexShrink: 0 }} />
                </div>
              );
              return (
                <div key={p} style={{ borderTop: i ? '1px solid var(--balsm-ink-100)' : 'none' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12, minHeight: 60, padding: '10px 14px' }}>
                    <div style={{ width: 36, height: 36, borderRadius: 'var(--radius-md)', background: cfg.icon.startsWith('brand-') ? (on ? '#fff' : 'var(--balsm-ink-100)') : (on ? cfg.color : 'var(--balsm-ink-100)'), boxShadow: cfg.icon.startsWith('brand-') && on ? 'inset 0 0 0 1px var(--balsm-ink-200)' : 'none', color: on ? '#fff' : 'var(--fg3)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Icon name={cfg.icon} size={cfg.icon.startsWith('brand-') ? 20 : 18} muted={!on} /></div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ fontWeight: 600, fontSize: 'var(--pt-sm)', color: 'var(--fg1)' }}>{cfg.label[lang]}</div>
                      <div className="meta" style={{ fontSize: 'var(--pt-xs)', marginTop: 1, color: on ? cfg.color : undefined, fontWeight: on ? 600 : 400 }}>
                        {!on ? (ar ? 'غير مربوط' : 'Not connected') : used ? (ar ? `مربوط · ${used} فئات` : `Connected · ${used} ${used === 1 ? 'category' : 'categories'}`) : (ar ? 'مربوط · لا شيء بعد' : 'Connected · nothing synced yet')}
                      </div>
                    </div>
                    {on
                      ? <button className="b-btn b-btn-sm b-btn-ghost" onClick={() => setConfirmOff(confirmOff === p ? null : p)} style={{ color: 'var(--fg3)' }}>{ar ? 'فصل' : 'Disconnect'}</button>
                      : <button className="b-btn b-btn-sm b-btn-secondary" disabled={!!connecting} onClick={() => connect(p)} style={{ minWidth: 84 }}>
                          {connecting === p ? <Icon name="loader" size={14} style={{ animation: 'spin 0.9s linear infinite' }} /> : (ar ? 'ربط' : 'Connect')}
                        </button>}
                  </div>
                  {confirmOff === p && (
                    <div style={{ margin: '0 14px 12px', padding: '11px 14px', borderRadius: 'var(--radius-md)', background: '#FEF3F2', display: 'flex', flexDirection: 'column', gap: 10 }}>
                      <div style={{ fontSize: 'var(--pt-xs)', lineHeight: 1.5, color: 'var(--fg1)' }}>{ar ? `ستتوقف المزامنة مع ${cfg.label.ar} وتُحذف نسختها. تبقى بياناتك على هذا الجهاز.` : `Syncing to ${cfg.label.en} stops and its copy is deleted. Your data stays on this device.`}</div>
                      <div style={{ display: 'flex', gap: 8 }}>
                        <button className="b-btn b-btn-sm b-btn-danger" onClick={() => { disconnectCloud(p); setConfirmOff(null); }}>{ar ? 'فصل' : 'Disconnect'}</button>
                        <button className="b-btn b-btn-sm b-btn-ghost" onClick={() => setConfirmOff(null)}>{t('cancel')}</button>
                      </div>
                    </div>
                  )}
                </div>
              );
            })}
          </div>

          <div style={{ display: 'flex', alignItems: 'center', marginTop: 6 }}>
            <span style={{ ...eyebrow, flex: 1 }}>{ar ? 'بياناتك' : 'Your data'}</span>
            <button className="b-btn b-btn-sm b-btn-ghost" onClick={() => setView('all')} style={{ height: 28, padding: '0 8px', fontSize: 'var(--pt-xs)', fontWeight: 700, color: 'var(--app-accent)', gap: 5 }}>
              <Icon name="refresh-cw" size={13} />{ar ? 'مزامنة الكل' : 'Sync all'}
            </button>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', borderRadius: 'var(--radius-lg)', border: '1px solid var(--balsm-border)', overflow: 'hidden' }}>
            {DATA_CATS.map((c, i) => {
              const d = dataSync[c.id] || {};
              const targets = d.targets || [];
              return (
                <button key={c.id} onClick={() => setView(c.id)}
                  style={{ display: 'flex', alignItems: 'center', gap: 12, minHeight: 58, padding: '9px 14px', border: 'none', borderTop: i ? '1px solid var(--balsm-ink-100)' : 'none', background: '#fff', cursor: 'pointer', textAlign: 'start', fontFamily: 'inherit' }}>
                  <Icon name={c.icon} size={18} style={{ color: 'var(--fg3)', flexShrink: 0 }} />
                  <span style={{ flex: 1, minWidth: 0 }}>
                    <span style={{ display: 'block', fontWeight: 600, fontSize: 'var(--pt-sm)', color: 'var(--fg1)' }}>{c[lang]}</span>
                    <span className="meta" style={{ display: 'block', fontSize: 'var(--pt-xs)', marginTop: 1 }}>{locSummary(targets, lang)}{targets.length ? ` · ${syncAgo(d.at, ar)}` : ''}</span>
                  </span>
                  <LocIcons targets={targets} size={22} />
                  <Icon name="chevron-right" size={16} style={{ color: 'var(--fg4)', flexShrink: 0, transform: ar ? 'scaleX(-1)' : 'none' }} />
                </button>
              );
            })}
          </div>
          {!connected.length && <p className="meta" style={{ margin: 0, fontSize: 'var(--pt-xs)', lineHeight: 1.5 }}>{ar ? 'اربط سحابة لتتمكن من مزامنة أي فئة إليها.' : 'Connect a cloud to sync any category to it.'}</p>}
        </div>
      )}
    </Modal>
  );
}

Object.assign(window, { StorageSyncSheet, StorageBadge, STORAGE_CFG, DATA_CATS, DataLocPill, LocIcons, CLOUDS });
