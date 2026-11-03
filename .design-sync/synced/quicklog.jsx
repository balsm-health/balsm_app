/* quicklog.jsx — FAB quick-log bottom sheet + per-metric mini-flows
   Each flow: primary input → note + photo → save                     */

const QL_METRICS = [
  { id: 'bp',       icon: 'activity',    color: 'var(--petal-violet)',   bg: 'var(--petal-violet-50)',  labelKey: 'm_bp',      kind: 'vital'     },
  { id: 'glucose',  icon: 'droplet',     color: 'var(--petal-mint-600)', bg: 'var(--petal-mint-50)',    labelKey: 'm_glucose', kind: 'vital'     },
  { id: 'o2',       icon: 'wind',        color: 'var(--petal-aqua)',     bg: 'var(--petal-aqua-50)',    labelKey: 'm_o2',      kind: 'vital'     },
  { id: 'pulse',    icon: 'heart-pulse', color: 'var(--petal-violet)',   bg: 'var(--petal-violet-50)',  labelKey: 'm_pulse',   kind: 'vital'     },
  { id: 'weight',   icon: 'scale',       color: 'var(--petal-blue)',     bg: 'var(--petal-blue-50)',    labelKey: 'm_weight',  kind: 'vital'     },
  { id: 'mood',     icon: 'smile',       color: 'var(--petal-aqua)',     bg: 'var(--petal-aqua-50)',    labelKey: 'm_mood',    kind: 'wellbeing' },
  { id: 'pain',     icon: 'zap',         color: 'var(--balsm-danger)',   bg: 'var(--balsm-danger-bg)',  labelKey: 'm_pain',    kind: 'wellbeing' },
];

/* Shared metric inputs (SYMPTOMS, PAIN_COLORS, NoteAttach, use*State, *Field,
   MoodPicker, PainScale, SymptomPicker) all live in metric-inputs.jsx — the
   full check-in in report.jsx renders the exact same components. */

/* ── Sheet wrapper ─────────────────────────────────────── */
const SheetCtx = React.createContext(null);
function Sheet({ children, onClose, onBack, title, submit, toast }) {
  const { lang } = useApp();
  const ar = lang === 'ar';
  const [confirm, setConfirm] = useState(null); // null | 'close' | 'back'
  useEffect(() => { setConfirm(null); }, [title]);
  const guarded = !!(submit && submit.dirty);
  const requestClose = () => guarded ? setConfirm('close') : onClose();
  const requestBack = () => guarded ? setConfirm('back') : onBack();
  /* 4. Escape: dismiss the confirm, else step back, else close */
  const keyRef = React.useRef(); keyRef.current = () => confirm ? setConfirm(null) : (onBack ? requestBack() : requestClose());
  const sheetRef = React.useRef(null);
  useEffect(() => {
    const h = (e) => {
      if (e.key !== 'Escape' || e.defaultPrevented) return;
      const el = sheetRef.current;
      if (!el || !el.getClientRects().length || el.closest('.stage-full')) return; // only the visible frame
      e.preventDefault(); e.stopImmediatePropagation(); keyRef.current();
    };
    window.addEventListener('keydown', h, true); return () => window.removeEventListener('keydown', h, true);
  }, []);
  const trap = (e) => { if (e.key !== 'Tab') return; const b = [...e.currentTarget.querySelectorAll('button')]; const i = b.indexOf(document.activeElement); e.preventDefault(); b[(i + (e.shiftKey ? -1 : 1) + b.length) % b.length].focus(); };
  const [dy, setDy] = useState(0);
  const [entered, setEntered] = useState(false);
  const drag = React.useRef(null);
  const down = (e) => { if (e.target.closest('button')) return; drag.current = { y: e.clientY, t: Date.now() }; e.currentTarget.setPointerCapture(e.pointerId); };
  const move = (e) => { if (drag.current) setDy(Math.max(0, e.clientY - drag.current.y)); };
  const up = () => {
    if (!drag.current) return;
    const fast = dy / Math.max(1, Date.now() - drag.current.t) > 0.6;
    drag.current = null;
    setDy(0);
    if (dy > 110 || (fast && dy > 30)) requestClose();
  };
  const ok = submit && submit.ok;
  return (
    <>
      <div className="app-scrim" onClick={requestClose} style={{ position: 'absolute', inset: 0, zIndex: 40, background: 'rgba(20,32,43,0.38)', backdropFilter: 'blur(2px)', opacity: Math.max(0.3, 1 - dy / 400) }} />
      <div ref={sheetRef} className="app-sheet app-sheet--lg" onAnimationEnd={() => setEntered(true)} style={{
        position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 41,
        background: '#fff', borderRadius: '20px 20px 0 0',
        maxHeight: '90%', display: 'flex', flexDirection: 'column',
        animation: entered ? 'none' : 'qlSlideUp 0.3s cubic-bezier(0.16,1,0.3,1) both',
        transform: entered && dy ? `translateY(${dy}px)` : undefined,
        transition: drag.current ? 'none' : 'transform 0.25s cubic-bezier(0.16,1,0.3,1)',
      }}>
        <style>{`@keyframes qlSlideUp { from { transform: translateY(110%) } to { transform: none } } @keyframes qlFade { from { opacity: 0 } to { opacity: 1 } } @keyframes qlToast { 0% { opacity: 0; transform: translateY(8px) } 10%, 85% { opacity: 1; transform: none } 100% { opacity: 0; transform: translateY(8px) } }`}</style>
        <div onPointerDown={down} onPointerMove={move} onPointerUp={up} onPointerCancel={up}
          style={{ padding: '10px 16px 0', flexShrink: 0, touchAction: 'none', cursor: 'grab' }}>
          <div className="sheet-grab" />
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, paddingBottom: 10, borderBottom: '1px solid var(--balsm-ink-100)' }}>
            {onBack && <button className="round-btn ghost" onClick={requestBack} aria-label={lang === 'ar' ? 'رجوع' : 'Back'} style={{ flexShrink: 0 }}><Icon name="arrow-left" size={18} /></button>}
            {title
              ? <div style={{ flex: 1, fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-lg)', color: 'var(--fg1)' }}>{title}</div>
              : <div style={{ flex: 1 }} />}
            {submit
              ? <button className="round-btn" onClick={() => ok && submit.run()} disabled={!ok} aria-label={lang === 'ar' ? 'حفظ' : 'Save'}
                  style={{ flexShrink: 0, border: 'none', background: ok ? 'var(--app-accent)' : 'var(--balsm-ink-100)', color: ok ? '#fff' : 'var(--fg4)', cursor: ok ? 'pointer' : 'default', transition: 'background 0.15s var(--ease-out)' }}>
                  <Icon name="check" size={19} />
                </button>
              : <button className="round-btn ghost" onClick={onClose} aria-label={lang === 'ar' ? 'إغلاق' : 'Close'} style={{ flexShrink: 0 }}><Icon name="x" size={18} /></button>}
          </div>
        </div>
        <SheetCtx.Provider value={onBack ? requestBack : requestClose}>
          <div style={{ flex: 1, overflowY: 'auto', padding: '14px 20px 38px' }}>{children}</div>
        </SheetCtx.Provider>
        {toast && (
          <div role="status" aria-live="polite" key={toast.id} style={{ position: 'absolute', bottom: 24, insetInline: 16, zIndex: 3, display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px',
            background: 'var(--balsm-ink-800)', color: '#fff', borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-lg)', animation: 'qlToast 2.6s var(--ease-out) both', pointerEvents: 'none' }}>
            <span style={{ width: 28, height: 28, borderRadius: '50%', background: 'var(--petal-mint)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Icon name="check" size={16} /></span>
            <div style={{ minWidth: 0, flex: 1 }}>
              <div style={{ fontWeight: 700, fontSize: 'var(--pt-sm)' }}>{ar ? 'تم الحفظ' : 'Saved'}</div>
              {toast.value && <div style={{ fontSize: 'var(--pt-xs)', opacity: 0.85, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{toast.value}</div>}
            </div>
          </div>
        )}
        {confirm && (
          <div style={{ position: 'absolute', inset: 0, zIndex: 2, borderRadius: 'inherit', background: 'rgba(20,32,43,0.32)', display: 'flex', alignItems: 'flex-end' }}
            onClick={() => setConfirm(null)}>
            <div role="alertdialog" aria-modal="true" aria-labelledby="ql-discard-t" onKeyDown={trap} onClick={e => e.stopPropagation()}
              style={{ width: '100%', background: '#fff', borderRadius: '20px 20px 0 0', padding: '22px 20px 32px', boxShadow: 'var(--shadow-lg)', animation: 'qlFade 0.2s var(--ease-out) both' }}>
              <div id="ql-discard-t" style={{ fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-lg)', color: 'var(--fg1)', marginBottom: 6 }}>
                {ar ? 'تجاهل هذا التسجيل؟' : 'Discard this entry?'}
              </div>
              <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg2)', lineHeight: 1.5, marginBottom: 18 }}>
                {ar ? 'لن يُحفظ ما أدخلته.' : 'What you entered won’t be saved.'}
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                <button className="b-btn b-btn-lg b-btn-danger b-btn--full" onClick={() => { const c = confirm; setConfirm(null); c === 'back' ? onBack() : onClose(); }}>
                  {ar ? 'تجاهل' : 'Discard'}
                </button>
                <button className="b-btn b-btn-lg b-btn-secondary b-btn--full" autoFocus onClick={() => setConfirm(null)}>
                  {ar ? 'متابعة التعديل' : 'Keep editing'}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </>
  );
}

/* Registers the flow's save with the header ✓ and renders bottom Save + Cancel.
   snap = the form's current values; dirty = differs from the first render. */
function FlowSubmit({ ok, run, bind, onCancel, snap }) {
  const { lang } = useApp();
  const ar = lang === 'ar';
  const requestCancel = React.useContext(SheetCtx);
  const runRef = React.useRef(run); runRef.current = run;
  const cur = JSON.stringify(snap ?? null);
  const initial = React.useRef(cur);
  const dirty = cur !== initial.current;
  useEffect(() => { bind && bind({ ok: !!ok, dirty, run: () => runRef.current() }); }, [ok, dirty]);
  useEffect(() => () => bind && bind(null), []);
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 20 }}>
      <button className={cx('b-btn b-btn-lg b-btn-primary b-btn--full', !ok && 'is-disabled')} disabled={!ok} aria-describedby={!ok ? 'ql-save-hint' : undefined} onClick={() => ok && runRef.current()}>
        {ar ? 'حفظ' : 'Save'}
      </button>
      {!ok && <div id="ql-save-hint" className="meta" style={{ textAlign: 'center', fontSize: 'var(--pt-xs)', marginTop: -2 }}>{ar ? 'أكمل الحقول المطلوبة لتتمكن من الحفظ.' : 'Fill in the required fields to save.'}</div>}
      <button className="b-btn b-btn-lg b-btn-ghost b-btn--full" onClick={requestCancel || onCancel}>
        {ar ? 'إلغاء' : 'Cancel'}
      </button>
    </div>
  );
}

/* ── BP ─────────────────────────────────────────────────── */
function QuickBP({ onSave, bind, onCancel }) {
  const { t } = useApp();
  const bp = useBPState();
  const [note, setNote] = useState(''); const [photo, setPhoto] = useState(null);
  const [date, setDate] = useState(nowISO()); const [time, setTime] = useState(nowHM());
  return (<>
    <BPField bp={bp} />
    <SymptomWhen date={date} setDate={setDate} time={time} setTime={setTime} />
    <NoteAttach note={note} setNote={setNote} photo={photo} setPhoto={setPhoto} />
    <FlowSubmit bind={bind} onCancel={onCancel} snap={[bp, note, photo, date, time]} ok={bp.complete} run={() => onSave(`${bp.sys}/${bp.dia} ${t('unit_bp')}`, note)} />
  </>);
}

/* ── Glucose ────────────────────────────────────────────── */
function QuickGlucose({ onSave, bind, onCancel }) {
  const { t } = useApp();
  const glucose = useGlucoseState();
  const [note, setNote] = useState(''); const [photo, setPhoto] = useState(null);
  const [date, setDate] = useState(nowISO()); const [time, setTime] = useState(nowHM());
  return (<>
    <GlucoseContextChips value={glucose.ctx} onChange={glucose.setCtx} style={{ marginBottom: 14, justifyContent: 'center' }} />
    <GlucoseField glucose={glucose} />
    <SymptomWhen date={date} setDate={setDate} time={time} setTime={setTime} />
    <NoteAttach note={note} setNote={setNote} photo={photo} setPhoto={setPhoto} />
    <FlowSubmit bind={bind} onCancel={onCancel} snap={[glucose, note, photo, date, time]} ok={glucose.complete} run={() => onSave(`${glucose.value} ${t('unit_glu')} · ${t(glucose.ctx)}`, note)} />
  </>);
}

/* ── Mood ───────────────────────────────────────────────── */
function QuickMood({ onSave, bind, onCancel }) {
  const { t } = useApp();
  const [mood, setMood] = useState(0);
  const [note, setNote] = useState(''); const [photo, setPhoto] = useState(null);
  const [date, setDate] = useState(nowISO()); const [time, setTime] = useState(nowHM());
  return (<>
    <MoodPicker value={mood} onChange={setMood} style={{ marginBottom: 8 }} />
    <SymptomWhen date={date} setDate={setDate} time={time} setTime={setTime} />
    <NoteAttach note={note} setNote={setNote} photo={photo} setPhoto={setPhoto} />
    <FlowSubmit bind={bind} onCancel={onCancel} snap={[mood, note, photo, date, time]} ok={mood} run={() => onSave(t('mood_' + mood), note)} />
  </>);
}

/* ── Pain (scale + body map) ────────────────────────────── */
function QuickPain({ onSave, bind, onCancel }) {
  const { t, lang } = useApp();
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
    <FlowSubmit bind={bind} onCancel={onCancel} snap={[intensity, [...locations], note, photo, date, time]} ok={ok} run={() => {
        const locStr = [...locations].map(id => { const l = HOTSPOTS.find(h => h.id === id)?.label; return (l && (l[lang] || l.en)) || id; }).join(lang === 'ar' ? '، ' : ', ');
        onSave(`${intensity}/10${locStr ? ' · ' + locStr : ''}`, note);
      }} />
  </>);
}

/* ── O2 (SpO2) ──────────────────────────────────────────── */
function QuickO2({ onSave, bind, onCancel }) {
  const o2 = useO2State();
  const [note, setNote] = useState(''); const [photo, setPhoto] = useState(null);
  const [date, setDate] = useState(nowISO()); const [time, setTime] = useState(nowHM());
  return (<>
    <O2Field o2={o2} />
    <SymptomWhen date={date} setDate={setDate} time={time} setTime={setTime} />
    <NoteAttach note={note} setNote={setNote} photo={photo} setPhoto={setPhoto} />
    <FlowSubmit bind={bind} onCancel={onCancel} snap={[o2, note, photo, date, time]} ok={o2.complete} run={() => onSave(`${o2.value}% SpO2`, note)} />
  </>);
}

/* ── Pulse — type bpm, or tap each beat for 15 s and we multiply by 4 ── */
const PULSE_SECS = 15;
function QuickPulse({ onSave, bind, onCancel }) {
  const { t, lang, numpad } = useApp();
  const ar = lang === 'ar';
  const pad = numpad !== 'native';
  const [value, setValue] = useState('');
  const [note, setNote] = useState(''); const [photo, setPhoto] = useState(null);
  const [date, setDate] = useState(nowISO()); const [time, setTime] = useState(nowHM());
  const [mode, setMode] = useState('type'); // 'type' | 'count'
  const [beats, setBeats] = useState(0);
  const [left, setLeft] = useState(null); // null = not started
  useEffect(() => {
    if (left === null || left <= 0) return;
    const id = setTimeout(() => setLeft(l => l - 1), 1000);
    return () => clearTimeout(id);
  }, [left]);
  useEffect(() => { if (left === 0) { setValue(String(beats * (60 / PULSE_SECS))); setMode('type'); setLeft(null); } }, [left]);
  const tap = () => { if (left === null) { setLeft(PULSE_SECS); setBeats(1); } else if (left > 0) setBeats(b => b + 1); };
  const startCount = () => { setBeats(0); setLeft(null); setMode('count'); };
  const press = (k) => setValue(v => k === 'del' ? v.slice(0, -1) : (v + k).replace(/\D/g, '').slice(0, 3));
  const n = Number(value);
  const ok = value.length >= 2 && n >= 30 && n <= 220;
  const counting = left !== null;
  const progress = counting ? (PULSE_SECS - left) / PULSE_SECS : 0;
  return (<>
    {mode === 'type' ? (<>
      <div className="vital-display" style={{ padding: '8px 0 4px' }}>
        <input className={cx('vital-num', pad && 'active')} type="text" dir="ltr"
          readOnly={pad} inputMode={pad ? 'none' : 'numeric'} autoFocus={!pad}
          placeholder="—" value={value} aria-label={t('m_pulse')}
          style={{ width: 150, caretColor: pad ? 'transparent' : undefined }}
          onChange={e => { if (!pad) setValue(e.target.value.replace(/\D/g, '').slice(0, 3)); }} />
        <div className="vital-unit">{t('unit_bpm')}</div>
      </div>
      <button type="button" className="b-btn b-btn-md b-btn-secondary" onClick={startCount}
        style={{ display: 'flex', alignItems: 'center', gap: 8, margin: '4px auto 12px' }}>
        <Icon name="timer" size={17} />{ar ? 'عُدّ نبضك معي' : 'Count with me'}
      </button>
      {pad && <NumPad onPress={press} />}
    </>) : (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14, padding: '4px 0 8px' }}>
        <p style={{ margin: 0, fontSize: 'var(--pt-sm)', color: 'var(--fg2)', textAlign: 'center', lineHeight: 1.5, maxWidth: 300 }}>
          {counting
            ? (ar ? 'استمر في النقر مع كل نبضة.' : 'Keep tapping with every beat.')
            : (ar ? 'ضع إصبعين على معصمك أو جانب رقبتك، ثم انقر الدائرة مع كل نبضة. يبدأ العدّ مع أول نقرة لمدة 15 ثانية.' : 'Place two fingers on your wrist or the side of your neck, then tap the circle with each beat. The 15-second count starts on your first tap.')}
        </p>
        <button type="button" onClick={tap} aria-label={ar ? 'نبضة' : 'Beat'}
          style={{ position: 'relative', width: 196, height: 196, borderRadius: '50%', border: 'none', cursor: 'pointer', padding: 0,
                   background: 'var(--petal-violet-50)', color: 'var(--petal-violet)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4,
                   touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent' }}
          onPointerDown={e => e.currentTarget.style.transform = 'scale(0.97)'}
          onPointerUp={e => e.currentTarget.style.transform = 'none'}
          onPointerLeave={e => e.currentTarget.style.transform = 'none'}>
          <svg width="196" height="196" viewBox="0 0 196 196" style={{ position: 'absolute', inset: 0, transform: 'rotate(-90deg)' }} aria-hidden="true">
            <circle cx="98" cy="98" r="92" fill="none" stroke="var(--balsm-ink-100)" strokeWidth="6" />
            <circle cx="98" cy="98" r="92" fill="none" stroke="var(--petal-violet)" strokeWidth="6" strokeLinecap="round"
              strokeDasharray={2 * Math.PI * 92} strokeDashoffset={2 * Math.PI * 92 * (1 - progress)} style={{ transition: 'stroke-dashoffset 1s linear' }} />
          </svg>
          <Icon name="heart" size={30} />
          <span className="num" style={{ fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 44, lineHeight: 1, color: 'var(--fg1)' }}>{beats}</span>
          <span style={{ fontSize: 'var(--pt-xs)', fontWeight: 600, color: 'var(--fg3)' }}>
            {counting ? (ar ? `${left} ث متبقية` : `${left}s left`) : (ar ? 'انقر للبدء' : 'Tap to start')}
          </span>
        </button>
        <button type="button" className="b-btn b-btn-md b-btn-ghost" onClick={() => { setMode('type'); setLeft(null); setBeats(0); }}>
          {ar ? 'إدخال الرقم يدويًا' : 'Type the number instead'}
        </button>
      </div>
    )}
    <SymptomWhen date={date} setDate={setDate} time={time} setTime={setTime} />
    <NoteAttach note={note} setNote={setNote} photo={photo} setPhoto={setPhoto} />
    <FlowSubmit bind={bind} onCancel={onCancel} snap={[value, beats, note, photo, date, time]} ok={ok && !counting}
      run={() => onSave(`${value} ${t('unit_bpm')}`, note)} />
  </>);
}

/* ── Weight ─────────────────────────────────────────────── */
function QuickWeight({ onSave, bind, onCancel }) {
  const { lang } = useApp();
  const weight = useWeightState();
  const [note, setNote] = useState(''); const [photo, setPhoto] = useState(null);
  const [date, setDate] = useState(nowISO()); const [time, setTime] = useState(nowHM());
  return (<>
    <WeightField weight={weight} />
    <SymptomWhen date={date} setDate={setDate} time={time} setTime={setTime} />
    <NoteAttach note={note} setNote={setNote} photo={photo} setPhoto={setPhoto} />
    <FlowSubmit bind={bind} onCancel={onCancel} snap={[weight, note, photo, date, time]} ok={weight.complete} run={() => onSave(`${weight.display} ${lang === 'ar' ? 'كجم' : 'kg'}`, note)} />
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

function QuickSymptomDetail({ symptom, onSave, bind, onCancel }) {
  const { t, lang } = useApp();
  const { Checkbox } = window.BalsmDesignSystem_1cf4c7 || {};
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
    <FlowSubmit bind={bind} onCancel={onCancel} snap={[[...locs], note, photo, date, time, uColor, uQty, blood]} ok={true} run={() => {
        const extra = isUrine ? ` · ${uColor ? URINE_COLORS.find(c => c.id === uColor).label[lang] : ''} · ${uQty ? uQty + ' ' + URINE_QTY_UNIT : ''}`.replace(' · ·', ' ·') : (isStool && blood ? ` · ${t('s_blood')}` : '');
        onSave(t(symptom.id) + extra, note);
      }} />
  </>);
}

/* ── Main QuickLog sheet ────────────────────────────────── */
function QuickLogSheet({ onClose, onFullCheckin }) {
  const { t, lang, addRecord } = useApp();
  const [active, setActive]         = useState(null);
  const [query, setQuery]           = useState('');
  const [symDetail, setSymDetail]   = useState(null);
  const [submit, setSubmit]         = useState(null);
  /* Flat list — BP/Glucose/Mood/Pain/Weight, each symptom as its own row
     (no nested Symptoms accordion). Symptom rows navigate to their own
     detail screen, same as any other metric. */
  const symItems = SYMPTOMS.map(s => ({ id: s.id, icon: s.icon, color: s.danger ? 'var(--balsm-danger)' : '#9A6E00', bg: s.danger ? 'var(--balsm-danger-bg)' : '#FDF5DC', labelKey: s.id, kind: 'symptom' }))
    .sort((a, b) => t(a.labelKey).localeCompare(t(b.labelKey), lang));
  const FLAT_ITEMS = [...QL_METRICS, ...symItems];

  const toastTimer = React.useRef(null);
  const [toast, setToast] = useState(null);
  useEffect(() => () => clearTimeout(toastTimer.current), []);
  const handleSave = (value) => {
    setActive(null); setSymDetail(null); setSubmit(null);
    setToast({ id: Date.now(), value });
    clearTimeout(toastTimer.current); toastTimer.current = setTimeout(() => setToast(null), 2600);
  };

  const FlowMap = { bp: QuickBP, glucose: QuickGlucose, mood: QuickMood, pain: QuickPain, weight: QuickWeight, o2: QuickO2, pulse: QuickPulse };
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

  const recordsBlock = filteredRecords.length > 0 && (
    <div key="records" style={{ marginBottom: 16 }}>
      <div style={{ fontSize: 'var(--pt-2xs)', fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--fg4)', padding: '2px 12px 8px' }}>
        {lang === 'ar' ? 'أضف مستندًا' : 'Add a document'}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', gap: 8 }}>
        {filteredRecords.map(r => (
          <button type="button" key={r.type} onClick={() => addRecord(r.type)} style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, padding: '12px 6px', minHeight: 44,
            background: '#fff', border: '1.5px solid var(--balsm-border)', borderRadius: 'var(--radius-lg)', cursor: 'pointer', fontFamily: 'inherit',
            transition: 'background var(--dur-fast) var(--ease-out)',
          }}
          onPointerDown={e => e.currentTarget.style.background = 'var(--balsm-ink-50)'}
          onPointerUp={e => e.currentTarget.style.background = '#fff'}
          onPointerLeave={e => e.currentTarget.style.background = '#fff'}>
            <span style={{ width: 36, height: 36, borderRadius: 'var(--radius-md)', background: r.bg, color: r.color, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name={r.icon} size={18} />
            </span>
            <span style={{ fontSize: 'var(--pt-sm)', fontWeight: 600, color: 'var(--fg2)', textAlign: 'center', lineHeight: 1.25 }}>{t(r.labelKey)}</span>
          </button>
        ))}
      </div>
    </div>
  );

  if (symDetail) {
    const s = SYMPTOMS.find(x => x.id === symDetail);
    return (
      <Sheet onClose={onClose} onBack={() => setSymDetail(null)} submit={submit} title={symDetail === 's_none' ? t('s_none') : t(symDetail)}>
        <QuickSymptomDetail symptom={s} onSave={handleSave} bind={setSubmit} onCancel={onClose} />
      </Sheet>
    );
  }

  if (active && MetricFlow) {
    return (
      <Sheet onClose={onClose} onBack={() => setActive(null)} submit={submit} title={t(metricInfo.labelKey)}>
        <MetricFlow onSave={handleSave} bind={setSubmit} onCancel={onClose} />
      </Sheet>
    );
  }

  return (
    <Sheet onClose={onClose} title={t('ql_title')} toast={toast}>
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
          <React.Fragment key={gi}>
          <div style={{ marginBottom: 16 }}>
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
          {g.kind === 'vital' && recordsBlock}
          </React.Fragment>
        ));
      })()}

      {!filtered.some(m => m.kind === 'vital') && recordsBlock}
    </Sheet>
  );
}

Object.assign(window, { QuickLogSheet });
