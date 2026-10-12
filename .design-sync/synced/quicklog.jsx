/* quicklog.jsx — FAB quick-log bottom sheet + per-metric mini-flows
   Each flow: primary input → note + photo → save                     */

const QL_METRICS = [
  { id: 'bp',       icon: 'activity',    color: 'var(--petal-violet)',   bg: 'var(--petal-violet-50)',  labelKey: 'm_bp',      kind: 'vital'     },
  { id: 'glucose',  icon: 'droplet',     color: 'var(--petal-mint-600)', bg: 'var(--petal-mint-50)',    labelKey: 'm_glucose', kind: 'vital'     },
  { id: 'o2',       icon: 'wind',        color: 'var(--petal-aqua)',     bg: 'var(--petal-aqua-50)',    labelKey: 'm_o2',      kind: 'vital'     },
  { id: 'weight',   icon: 'scale',       color: 'var(--petal-blue)',     bg: 'var(--petal-blue-50)',    labelKey: 'm_weight',  kind: 'vital'     },
  { id: 'mood',     icon: 'smile',       color: 'var(--petal-aqua)',     bg: 'var(--petal-aqua-50)',    labelKey: 'm_mood',    kind: 'wellbeing' },
  { id: 'pain',     icon: 'zap',         color: 'var(--balsm-danger)',   bg: 'var(--balsm-danger-bg)',  labelKey: 'm_pain',    kind: 'wellbeing' },
];

/* Shared metric inputs (SYMPTOMS, PAIN_COLORS, NoteAttach, use*State, *Field,
   MoodPicker, PainScale, SymptomPicker) all live in metric-inputs.jsx — the
   full check-in in report.jsx renders the exact same components. */

/* ── Sheet wrapper ─────────────────────────────────────── */
function Sheet({ children, onClose, onBack, title }) {
  return (
    <>
      <div className="app-scrim" onClick={onClose} style={{ position: 'absolute', inset: 0, zIndex: 40, background: 'rgba(20,32,43,0.38)', backdropFilter: 'blur(2px)' }} />
      <div className="app-sheet app-sheet--lg" style={{
        position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 41,
        background: '#fff', borderRadius: '20px 20px 0 0',
        maxHeight: '90%', display: 'flex', flexDirection: 'column',
        animation: 'qlSlideUp 0.3s cubic-bezier(0.16,1,0.3,1) both',
      }}>
        <style>{`@keyframes qlSlideUp { from { transform: translateY(110%) } to { transform: none } }`}</style>
        <div style={{ padding: '10px 16px 0', flexShrink: 0 }}>
          {!onBack && <div className="sheet-grab" />}
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, paddingBottom: 10, borderBottom: '1px solid var(--balsm-ink-100)' }}>
            {onBack && <button className="round-btn ghost" onClick={onBack} style={{ flexShrink: 0 }}><Icon name="arrow-left" size={18} /></button>}
            {title
              ? <div style={{ flex: 1, fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-lg)', color: 'var(--fg1)' }}>{title}</div>
              : <div style={{ flex: 1 }} />}
            <button className="round-btn ghost" onClick={onClose} style={{ flexShrink: 0 }}><Icon name="x" size={18} /></button>
          </div>
        </div>
        <div style={{ flex: 1, overflowY: 'auto', padding: '14px 20px 38px' }}>{children}</div>
      </div>
    </>
  );
}

/* ── Saved flash ───────────────────────────────────────── */
function SavedFlash({ value, note }) {
  return (
    <div style={{ textAlign: 'center', padding: '16px 0 8px' }}>
      <div className="confirm-mark" style={{ width: 72, height: 72, margin: '0 auto 14px' }}><Icon name="check" size={36} /></div>
      <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', color: 'var(--fg1)', marginBottom: 6 }}>Saved</div>
      {value && <div style={{ fontSize: 'var(--pt-md)', color: 'var(--fg2)', fontWeight: 500 }}>{value}</div>}
      {note && (
        <div style={{ margin: '12px 0 0', padding: '10px 14px', background: 'var(--balsm-ink-50)', borderRadius: 'var(--radius-md)', fontSize: 'var(--pt-sm)', color: 'var(--fg3)', textAlign: 'left', lineHeight: 1.5 }}>
          <Icon name="file-text" size={13} style={{ display: 'inline', marginRight: 6, verticalAlign: 'middle', color: 'var(--fg4)' }} />{note}
        </div>
      )}
    </div>
  );
}

/* ── BP ─────────────────────────────────────────────────── */
function QuickBP({ onSave }) {
  const { t } = useApp();
  const bp = useBPState();
  const [note, setNote] = useState(''); const [photo, setPhoto] = useState(null);
  const [date, setDate] = useState(nowISO()); const [time, setTime] = useState(nowHM());
  return (<>
    <BPField bp={bp} />
    <SymptomWhen date={date} setDate={setDate} time={time} setTime={setTime} />
    <NoteAttach note={note} setNote={setNote} photo={photo} setPhoto={setPhoto} />
    <button className={cx('b-btn b-btn-lg b-btn-primary b-btn--full', !bp.complete && 'is-disabled')} style={{ marginTop: 16 }}
      onClick={() => onSave(`${bp.sys}/${bp.dia} ${t('unit_bp')}`, note)}>Save</button>
  </>);
}

/* ── Glucose ────────────────────────────────────────────── */
function QuickGlucose({ onSave }) {
  const { t } = useApp();
  const glucose = useGlucoseState();
  const [note, setNote] = useState(''); const [photo, setPhoto] = useState(null);
  const [date, setDate] = useState(nowISO()); const [time, setTime] = useState(nowHM());
  return (<>
    <GlucoseContextChips value={glucose.ctx} onChange={glucose.setCtx} style={{ marginBottom: 14, justifyContent: 'center' }} />
    <GlucoseField glucose={glucose} />
    <SymptomWhen date={date} setDate={setDate} time={time} setTime={setTime} />
    <NoteAttach note={note} setNote={setNote} photo={photo} setPhoto={setPhoto} />
    <button className={cx('b-btn b-btn-lg b-btn-primary b-btn--full', !glucose.complete && 'is-disabled')} style={{ marginTop: 16 }}
      onClick={() => onSave(`${glucose.value} ${t('unit_glu')} · ${t(glucose.ctx)}`, note)}>Save</button>
  </>);
}

/* ── Mood ───────────────────────────────────────────────── */
function QuickMood({ onSave }) {
  const { t } = useApp();
  const [mood, setMood] = useState(0);
  const [note, setNote] = useState(''); const [photo, setPhoto] = useState(null);
  const [date, setDate] = useState(nowISO()); const [time, setTime] = useState(nowHM());
  return (<>
    <MoodPicker value={mood} onChange={setMood} style={{ marginBottom: 8 }} />
    <SymptomWhen date={date} setDate={setDate} time={time} setTime={setTime} />
    <NoteAttach note={note} setNote={setNote} photo={photo} setPhoto={setPhoto} />
    <button className={cx('b-btn b-btn-lg b-btn-primary b-btn--full', !mood && 'is-disabled')} style={{ marginTop: 16 }}
      onClick={() => onSave(t('mood_' + mood), note)}>Save</button>
  </>);
}

/* ── Pain (scale + body map) ────────────────────────────── */
function QuickPain({ onSave }) {
  const { t } = useApp();
  const [intensity, setIntensity] = useState(0);
  const [locations, setLocations] = useState(new Set());
  const [note, setNote] = useState(''); const [photo, setPhoto] = useState(null);
  const [date, setDate] = useState(nowISO()); const [time, setTime] = useState(nowHM());
  const ok = intensity > 0 || locations.size > 0;
  const toggleLoc = (id) => setLocations(prev => { const n = new Set(prev); n.has(id) ? n.delete(id) : n.add(id); return n; });
  return (<>
    <PainScale value={intensity} onChange={setIntensity} style={{ marginBottom: 20 }} />
    <div style={{ fontSize: 'var(--pt-sm)', fontWeight: 600, color: 'var(--fg3)', marginBottom: 10 }}>{t('body_location')}</div>
    <BodyMap selected={locations} onToggle={toggleLoc} initialGender={PATIENT.gender} />
    <SymptomWhen date={date} setDate={setDate} time={time} setTime={setTime} />
    <NoteAttach note={note} setNote={setNote} photo={photo} setPhoto={setPhoto} />
    <button className={cx('b-btn b-btn-lg b-btn-primary b-btn--full', !ok && 'is-disabled')} style={{ marginTop: 16 }}
      onClick={() => {
        const locStr = [...locations].map(id => HOTSPOTS.find(h => h.id === id)?.label?.en || id).join(', ');
        onSave(`${intensity}/10${locStr ? ' · ' + locStr : ''}`, note);
      }}>Save</button>
  </>);
}

/* ── O2 (SpO2) ──────────────────────────────────────────── */
function QuickO2({ onSave }) {
  const o2 = useO2State();
  const [note, setNote] = useState(''); const [photo, setPhoto] = useState(null);
  const [date, setDate] = useState(nowISO()); const [time, setTime] = useState(nowHM());
  return (<>
    <O2Field o2={o2} />
    <SymptomWhen date={date} setDate={setDate} time={time} setTime={setTime} />
    <NoteAttach note={note} setNote={setNote} photo={photo} setPhoto={setPhoto} />
    <button className={cx('b-btn b-btn-lg b-btn-primary b-btn--full', !o2.complete && 'is-disabled')} style={{ marginTop: 16 }}
      onClick={() => onSave(`${o2.value}% SpO2`, note)}>Save</button>
  </>);
}

/* ── Weight ─────────────────────────────────────────────── */
function QuickWeight({ onSave }) {
  const weight = useWeightState();
  const [note, setNote] = useState(''); const [photo, setPhoto] = useState(null);
  const [date, setDate] = useState(nowISO()); const [time, setTime] = useState(nowHM());
  return (<>
    <WeightField weight={weight} />
    <SymptomWhen date={date} setDate={setDate} time={time} setTime={setTime} />
    <NoteAttach note={note} setNote={setNote} photo={photo} setPhoto={setPhoto} />
    <button className={cx('b-btn b-btn-lg b-btn-primary b-btn--full', !weight.complete && 'is-disabled')} style={{ marginTop: 16 }}
      onClick={() => onSave(`${weight.display} kg`, note)}>Save</button>
  </>);
}

/* ── Symptoms detail screen — one symptom, its own map if located ── */
const URINE_COLORS = [
  { id: 'pale',   label: { en: 'Pale',   ar: 'شاحب' },  swatch: '#F5F0C8' },
  { id: 'yellow', label: { en: 'Yellow', ar: 'أصفر' },  swatch: '#E8D24A' },
  { id: 'dark',   label: { en: 'Dark',   ar: 'داكن' },  swatch: '#8A6A1E' },
  { id: 'red',    label: { en: 'Red/pink', ar: 'أحمر/وردي' }, swatch: '#C4453C' },
  { id: 'brown',  label: { en: 'Brown', ar: 'بني' },    swatch: '#5C4029' },
];
const URINE_QTY_UNIT = 'ml';

function QuickSymptomDetail({ symptom, onSave }) {
  const { t, lang } = useApp();
  const { Checkbox } = window.BalsmDesignSystem_51cdbf || {};
  const [locs, setLocs] = useState(new Set(symptom.regions || []));
  const [note, setNote] = useState(''); const [photo, setPhoto] = useState(null);
  const [date, setDate] = useState(nowISO());
  const [time, setTime] = useState(nowHM());
  const [uColor, setUColor] = useState(null);
  const [uQty, setUQty] = useState('');
  const [blood, setBlood] = useState(false);
  const toggleLoc = (id) => setLocs(prev => { const n = new Set(prev); n.has(id) ? n.delete(id) : n.add(id); return n; });
  const isUrine = symptom.id === 's_urine';
  const isStool = symptom.id === 's_stool';
  return (<>
    <SymptomWhen date={date} setDate={setDate} time={time} setTime={setTime} />
    {symptom.loc && (
      <BodyMap selected={locs} onToggle={toggleLoc} initialGender={PATIENT.gender} allowedLayers={symptom.layers} />
    )}
    {isUrine && <div className="card card-pad" style={{ marginBottom: 20 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 'var(--pt-sm)', fontWeight: 700, color: 'var(--fg2)', marginBottom: 14 }}>
        <Icon name="palette" size={15} style={{ color: 'var(--app-accent)' }} />{lang === 'ar' ? 'اللون' : 'Color'}
      </div>
      <div style={{ display: 'flex', gap: 14, marginBottom: 20 }}>
        {URINE_COLORS.map(c => (
          <button key={c.id} onClick={() => setUColor(c.id)} style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, background: 'transparent', border: 'none', cursor: 'pointer', flex: 1, padding: 0,
          }}>
            <span style={{
              width: 42, height: 42, borderRadius: '50%', background: c.swatch, position: 'relative', flexShrink: 0,
              boxShadow: uColor === c.id ? '0 0 0 2.5px #fff, 0 0 0 4.5px var(--app-accent)' : '0 0 0 1px rgba(20,32,43,0.1)',
              transition: 'box-shadow 0.15s var(--ease-out), transform 0.15s var(--ease-out)',
              transform: uColor === c.id ? 'scale(1.06)' : 'none',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              {uColor === c.id && <Icon name="check" size={17} style={{ color: c.id === 'pale' || c.id === 'yellow' ? '#3A2E05' : '#fff' }} />}
            </span>
            <span style={{ fontSize: '10.5px', fontWeight: 600, color: uColor === c.id ? 'var(--app-accent)' : 'var(--fg3)', textAlign: 'center', lineHeight: 1.2 }}>{c.label[lang]}</span>
          </button>
        ))}
      </div>
      <div style={{ height: 1, background: 'var(--balsm-ink-100)', margin: '4px 0 18px' }} />
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 'var(--pt-sm)', fontWeight: 700, color: 'var(--fg2)', marginBottom: 14 }}>
        <Icon name="beaker" size={15} style={{ color: 'var(--app-accent)' }} />{lang === 'ar' ? 'الكمية' : 'Quantity'}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 18 }}>
        <button onClick={() => setUQty(v => String(Math.max(0, (parseInt(v || 0, 10)) - 50)))} aria-label="Decrease" style={{
          width: 40, height: 40, borderRadius: '50%', border: '1.5px solid var(--balsm-border)', background: '#fff',
          color: 'var(--fg2)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        }}><Icon name="minus" size={17} /></button>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, minWidth: 90, justifyContent: 'center' }}>
          <input className="b-input num" dir="ltr" type="number" inputMode="numeric" min="0" value={uQty}
            onChange={e => setUQty(e.target.value.replace(/[^\d]/g, ''))} placeholder="0"
            style={{ width: 78, textAlign: 'center', fontSize: 'var(--pt-2xl)', fontWeight: 700, border: 'none', background: 'transparent', padding: 0 }} />
          <span style={{ color: 'var(--fg3)', fontWeight: 600, fontSize: 'var(--pt-sm)' }}>{URINE_QTY_UNIT}</span>
        </div>
        <button onClick={() => setUQty(v => String((parseInt(v || 0, 10)) + 50))} aria-label="Increase" style={{
          width: 40, height: 40, borderRadius: '50%', border: '1.5px solid var(--balsm-border)', background: '#fff',
          color: 'var(--fg2)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        }}><Icon name="plus" size={17} /></button>
      </div>
      <div style={{ height: 1, background: 'var(--balsm-ink-100)', margin: '20px 0 16px' }} />
      <div onClick={() => setBlood(v => !v)} style={{
        display: 'flex', alignItems: 'center', gap: 12, padding: '10px 12px', borderRadius: 'var(--radius-md)', cursor: 'pointer',
        background: blood ? 'var(--balsm-danger-bg)' : 'var(--balsm-ink-50)', transition: 'background 0.15s var(--ease-out)',
      }}>
        <Icon name="droplet" size={17} style={{ color: blood ? 'var(--balsm-danger)' : 'var(--fg3)', flexShrink: 0 }} />
        <span style={{ flex: 1, fontWeight: 600, fontSize: 'var(--pt-sm)', color: blood ? 'var(--balsm-danger)' : 'var(--fg2)' }}>{t('s_blood')}</span>
        {Checkbox && <Checkbox checked={blood} onChange={() => setBlood(v => !v)} />}
      </div>
    </div>}
    {isStool && (
      <div className="card card-pad" style={{ marginBottom: 20 }}>
        <div onClick={() => setBlood(v => !v)} style={{
          display: 'flex', alignItems: 'center', gap: 12, padding: '10px 12px', borderRadius: 'var(--radius-md)', cursor: 'pointer',
          background: blood ? 'var(--balsm-danger-bg)' : 'var(--balsm-ink-50)', transition: 'background 0.15s var(--ease-out)',
        }}>
          <Icon name="droplet" size={17} style={{ color: blood ? 'var(--balsm-danger)' : 'var(--fg3)', flexShrink: 0 }} />
          <span style={{ flex: 1, fontWeight: 600, fontSize: 'var(--pt-sm)', color: blood ? 'var(--balsm-danger)' : 'var(--fg2)' }}>{t('s_blood')}</span>
          {Checkbox && <Checkbox checked={blood} onChange={() => setBlood(v => !v)} />}
        </div>
      </div>
    )}
    <NoteAttach note={note} setNote={setNote} photo={photo} setPhoto={setPhoto}
      style={(!symptom.loc && !isUrine && !isStool) ? { marginTop: 0, paddingTop: 0, borderTop: 'none' } : undefined} />
    <button className="b-btn b-btn-lg b-btn-primary b-btn--full" style={{ marginTop: 16 }}
      onClick={() => {
        const extra = isUrine ? ` · ${uColor ? URINE_COLORS.find(c => c.id === uColor).label[lang] : ''} · ${uQty ? uQty + ' ' + URINE_QTY_UNIT : ''}`.replace(' · ·', ' ·') : (isStool && blood ? ` · ${t('s_blood')}` : '');
        onSave(t(symptom.id) + extra, note);
      }}>Save</button>
  </>);
}

/* ── Main QuickLog sheet ────────────────────────────────── */
function QuickLogSheet({ onClose, onFullCheckin }) {
  const { t, lang, addRecord } = useApp();
  const [active, setActive]         = useState(null);
  const [savedValue, setSavedValue] = useState(null);
  const [savedNote, setSavedNote]   = useState(null);
  const [query, setQuery]           = useState('');
  const [symDetail, setSymDetail]   = useState(null);
  /* Flat list — BP/Glucose/Mood/Pain/Weight, each symptom as its own row
     (no nested Symptoms accordion). Symptom rows navigate to their own
     detail screen, same as any other metric. */
  const symItems = SYMPTOMS.map(s => ({ id: s.id, icon: s.icon, color: s.danger ? 'var(--balsm-danger)' : '#9A6E00', bg: s.danger ? 'var(--balsm-danger-bg)' : '#FDF5DC', labelKey: s.id, kind: 'symptom' }))
    .sort((a, b) => t(a.labelKey).localeCompare(t(b.labelKey), lang));
  const FLAT_ITEMS = [...QL_METRICS, ...symItems];

  const handleSave = (value, note) => { setSavedValue(value); setSavedNote(note || null); setTimeout(onClose, 1600); };

  const FlowMap = { bp: QuickBP, glucose: QuickGlucose, mood: QuickMood, pain: QuickPain, weight: QuickWeight, o2: QuickO2 };
  const MetricFlow = active ? FlowMap[active] : null;
  const metricInfo = QL_METRICS.find(m => m.id === active);
  const q = query.trim().toLowerCase();
  const filtered = q ? FLAT_ITEMS.filter(m => t(m.labelKey).toLowerCase().includes(q)) : FLAT_ITEMS;
  const showCTA = !q || t('full_checkin').toLowerCase().includes(q);
  const RECORD_SHORTCUTS = [
    { type: 'lab',    icon: 'flask-conical', labelKey: 'rec_lab_one',    color: 'var(--petal-mint-600)', bg: 'var(--petal-mint-50)' },
    { type: 'scan',   icon: 'scan-line',     labelKey: 'rec_scan_one',   color: 'var(--petal-blue)',     bg: 'var(--petal-blue-50)' },
    { type: 'report', icon: 'file-text',     labelKey: 'rec_report_one', color: 'var(--petal-violet)',   bg: 'var(--petal-violet-50)' },
  ];
  const filteredRecords = q ? RECORD_SHORTCUTS.filter(r => t(r.labelKey).toLowerCase().includes(q)) : RECORD_SHORTCUTS;

  if (savedValue !== null) return <Sheet onClose={onClose}><SavedFlash value={savedValue} note={savedNote} /></Sheet>;

  if (symDetail) {
    const s = SYMPTOMS.find(x => x.id === symDetail);
    return (
      <Sheet onClose={onClose} onBack={() => setSymDetail(null)} title={symDetail === 's_none' ? t('s_none') : t(symDetail)}>
        <QuickSymptomDetail symptom={s} onSave={handleSave} />
      </Sheet>
    );
  }

  if (active && MetricFlow) {
    return (
      <Sheet onClose={onClose} onBack={() => setActive(null)} title={t(metricInfo.labelKey)}>
        <MetricFlow onSave={handleSave} />
      </Sheet>
    );
  }

  return (
    <Sheet onClose={onClose} title={t('ql_title')}>
      {/* Search */}
      <div style={{ position: 'relative', marginBottom: 14 }}>
        <Icon name="search" size={16} style={{ position: 'absolute', insetInlineStart: 14, top: '50%', transform: 'translateY(-50%)', color: 'var(--fg4)' }} />
        <input className="b-input" value={query} onChange={e => setQuery(e.target.value)}
          placeholder={t('ql_search')} style={{ paddingInlineStart: 40, height: 44 }} />
        {query && (
          <button onClick={() => setQuery('')} aria-label="Clear" style={{
            position: 'absolute', insetInlineEnd: 10, top: '50%', transform: 'translateY(-50%)',
            border: 'none', background: 'transparent', color: 'var(--fg4)', cursor: 'pointer', display: 'flex', padding: 4,
          }}><Icon name="x" size={15} /></button>
        )}
      </div>

      {/* Full check-in CTA */}
      {showCTA && <div onClick={onFullCheckin} style={{
        display: 'flex', alignItems: 'center', gap: 14, padding: '15px 16px',
        background: 'linear-gradient(135deg, var(--app-accent), var(--app-accent-dark, var(--app-accent)))',
        borderRadius: 'var(--radius-lg)', color: '#fff', position: 'relative', overflow: 'hidden',
        cursor: 'pointer', marginBottom: 16, boxShadow: 'var(--app-accent-shadow)',
        transition: 'transform var(--dur-fast) var(--ease-out), box-shadow var(--dur-fast) var(--ease-out)',
      }}
      onPointerDown={e => e.currentTarget.style.transform = 'scale(0.985)'}
      onPointerUp={e => e.currentTarget.style.transform = 'none'}
      onPointerLeave={e => e.currentTarget.style.transform = 'none'}>
        <Icon name="sparkle" size={64} style={{ position: 'absolute', insetInlineEnd: -12, top: -14, opacity: 0.14, transform: 'rotate(12deg)' }} />
        <div style={{ width: 46, height: 46, borderRadius: 'var(--radius-md)', background: 'rgba(255,255,255,0.22)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <Icon name="clipboard-list" size={23} />
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)' }}>{t('full_checkin')}</div>
          <div style={{ fontSize: 'var(--pt-sm)', opacity: 0.85, marginTop: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>Mood · BP · glucose · meds · symptoms</div>
        </div>
        <div style={{ width: 30, height: 30, borderRadius: '50%', background: 'rgba(255,255,255,0.18)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <Icon name="chevron-right" size={16} />
        </div>
      </div>}

      {/* Divider */}
      {showCTA && filtered.length > 0 && <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
        <div style={{ flex: 1, height: 1, background: 'var(--balsm-ink-100)' }} />
        <span style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg4)', fontWeight: 600, whiteSpace: 'nowrap' }}>{t('quick_log_or')}</span>
        <div style={{ flex: 1, height: 1, background: 'var(--balsm-ink-100)' }} />
      </div>}

      {filtered.length === 0 && filteredRecords.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '28px 12px', color: 'var(--fg4)' }}>
          <Icon name="search-x" size={26} style={{ marginBottom: 8 }} />
          <div style={{ fontSize: 'var(--pt-sm)', fontWeight: 600 }}>{t('ql_no_results')}</div>
        </div>
      ) : (() => {
        const groups = [];
        filtered.forEach(m => {
          const kind = m.kind || 'symptom';
          const g = groups[groups.length - 1];
          if (g && g.kind === kind) g.items.push(m); else groups.push({ kind, items: [m] });
        });
        return groups.map((g, gi) => (
          <div key={gi} style={{ marginBottom: 16 }}>
            <div style={{ fontSize: 'var(--pt-2xs)', fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--fg4)', padding: '2px 12px 8px' }}>
              {{ symptom: t('symptoms'), wellbeing: lang === 'ar' ? 'الحالة العامة' : 'Wellbeing', vital: lang === 'ar' ? 'العلامات الحيوية' : 'Vitals' }[g.kind]}
            </div>
            <div className="card" style={{ padding: 0 }}>
              {g.items.map((m, i) => (
                <div key={m.id} onClick={() => m.kind === 'symptom' ? setSymDetail(m.id) : setActive(m.id)} style={{
                  display: 'flex', alignItems: 'center', gap: 14, padding: '11px 12px',
                  borderBottom: i < g.items.length - 1 ? '1px solid var(--balsm-ink-50)' : 'none',
                  cursor: 'pointer', transition: 'background var(--dur-fast) var(--ease-out)',
                }}
                onPointerDown={e => e.currentTarget.style.background = 'var(--balsm-ink-50)'}
                onPointerUp={e => e.currentTarget.style.background = 'transparent'}
                onPointerLeave={e => e.currentTarget.style.background = 'transparent'}>
                  <div style={{ width: 40, height: 40, borderRadius: 'var(--radius-md)', background: m.bg, color: m.color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <Icon name={m.icon} size={19} />
                  </div>
                  <div style={{ flex: 1, fontWeight: 600, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{t(m.labelKey)}</div>
                  <Icon name="chevron-right" size={18} style={{ color: 'var(--fg4)' }} />
                </div>
              ))}
            </div>
          </div>
        ));
      })()}

      {/* Add to records shortcuts */}
      {filteredRecords.length > 0 && <>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, margin: '14px 0 12px' }}>
        <div style={{ flex: 1, height: 1, background: 'var(--balsm-ink-100)' }} />
        <span style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg4)', fontWeight: 600, whiteSpace: 'nowrap' }}>{t('ql_add_record')}</span>
        <div style={{ flex: 1, height: 1, background: 'var(--balsm-ink-100)' }} />
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
        {filteredRecords.map(r => (
          <div key={r.type} onClick={() => addRecord(r.type)} style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, padding: '14px 6px',
            border: '1.5px solid var(--balsm-border)', borderRadius: 'var(--radius-lg)', cursor: 'pointer',
            transition: 'background var(--dur-fast) var(--ease-out)',
          }}
          onPointerDown={e => e.currentTarget.style.background = 'var(--balsm-ink-50)'}
          onPointerUp={e => e.currentTarget.style.background = 'transparent'}
          onPointerLeave={e => e.currentTarget.style.background = 'transparent'}>
            <div style={{ width: 40, height: 40, borderRadius: 'var(--radius-md)', background: r.bg, color: r.color, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name={r.icon} size={20} />
            </div>
            <span style={{ fontSize: 'var(--pt-sm)', fontWeight: 600, color: 'var(--fg2)', textAlign: 'center' }}>{t(r.labelKey)}</span>
          </div>
        ))}
      </div>
      </>}
    </Sheet>
  );
}

Object.assign(window, { QuickLogSheet });
