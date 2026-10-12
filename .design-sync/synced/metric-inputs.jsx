/* metric-inputs.jsx — the single source of truth for every health-metric input.
   Both the quick-log mini-flows (quicklog.jsx) and the full check-in steps
   (report.jsx) render THESE components — neither one hand-rolls its own.

   Split of responsibility:
     use*State()  — value + keypad/press logic, so behaviour can't drift
     <*Field/>    — the markup, unstyled by context
     callers      — wrappers (sheet vs. flow step), skip toggles, save buttons

   DS components are resolved lazily at render time because the DS bundle
   loads after the app scripts. */
const dsCheck = () => window.BalsmDesignSystem_51cdbf || {};

/* ── Canonical symptom list (was duplicated in both files) ─────── */
const SYMPTOMS = [
  { id: 's_headache', icon: 'brain'        }, { id: 's_dizzy',   icon: 'rotate-3d'   },
  { id: 's_fatigue',  icon: 'battery-low'  }, { id: 's_blurred', icon: 'eye'         },
  { id: 's_swelling', icon: 'droplet', loc: true, regions: ['l-shin','r-shin','l-foot','r-foot'], layers: ['skin','joint'] },
  { id: 's_chest',    icon: 'heart-pulse', loc: true, regions: ['chest'], layers: ['skin','muscle','organ'] },
  { id: 's_tingling', icon: 'zap',     loc: true, regions: ['l-hand','r-hand','l-foot','r-foot'], layers: ['skin','nerve'] },
  { id: 's_itching',  icon: 'hand', loc: true, layers: ['skin'] },
  { id: 's_nausea',   icon: 'frown'        }, { id: 's_thirst',  icon: 'cup-soda'    },
  { id: 's_urine',    icon: 'droplets'     }, { id: 's_stool',   icon: 'toilet'      },
  { id: 's_vomiting', icon: 'thermometer'  },
];
const symptomNeedsLocation = (ids) => [...ids].some(id => SYMPTOMS.find(s => s.id === id)?.loc);
/* symptoms with a known typical location pre-fill the body map with it
   (e.g. chest pain → chest, leg swelling → shins/feet) — still editable. */
const regionsForSymptom = (id) => SYMPTOMS.find(s => s.id === id)?.regions || null;

const PAIN_COLORS = ['#55D77F','#7AD455','#9CC92E','#C5C424','#E5B428','#E89428','#E07228','#D85030','#CF3C38','#C43040','#B82040'];

function painInfo(t, n) {
  if (n === 0) return { lbl: t('pain_0'),     color: 'var(--petal-mint)' };
  if (n <= 3)  return { lbl: t('pain_mild'),  color: 'var(--petal-mint-600)' };
  if (n <= 6)  return { lbl: t('pain_mod'),   color: 'var(--balsm-sun-600)' };
  if (n <= 9)  return { lbl: t('pain_sev'),   color: 'var(--balsm-expiring)' };
  return { lbl: t('pain_worst'), color: 'var(--balsm-danger)' };
}

/* ── Mood ───────────────────────────────────────────────────────── */
function MoodPicker({ value, onChange, style }) {
  const { t } = useApp();
  return (
    <div className="mood-grid" style={style}>
      {[1,2,3,4,5].map(lv => (
        <div key={lv} className={cx('mood', value === lv && 'sel')} onClick={() => onChange(lv)}>
          <MoodFace level={lv} color={value === lv ? MOOD_COLORS[lv-1] : 'var(--balsm-ink-400)'} />
          <span className="mlbl">{t('mood_' + lv)}</span>
        </div>
      ))}
    </div>
  );
}

/* ── Blood pressure ─────────────────────────────────────────────── */
const bpDigits = (v) => v.replace(/\D/g, '').slice(0, 3);

function useBPState() {
  const [sys, setSys] = useState('');
  const [dia, setDia] = useState('');
  const [field, setField] = useState('sys');
  const press = (k) => {
    if (k === 'del') {
      if (field === 'dia') { if (dia) setDia(dia.slice(0, -1)); else { setSys(sys.slice(0, -1)); setField('sys'); } }
      else setSys(sys.slice(0, -1));
      return;
    }
    if (field === 'sys') { const n = bpDigits(sys + k); setSys(n); if (n.length === 3) setField('dia'); }
    else setDia(bpDigits(dia + k));
  };
  return { sys, setSys, dia, setDia, field, setField, press, complete: sys.length >= 2 && dia.length >= 2 };
}

function BPField({ bp, disabled = false, numpadStyle }) {
  const { t, numpad } = useApp();
  const pad = numpad !== 'native';
  const { sys, setSys, dia, setDia, field, setField, press } = bp;
  const sysRef = useRef(null); const diaRef = useRef(null);
  return (<>
    <div className="vital-pair">
      <input ref={sysRef} className={cx('vital-num', pad && !disabled && field === 'sys' && 'active')} type="text"
        readOnly={pad} inputMode={pad ? 'none' : 'numeric'} autoFocus={!pad} disabled={disabled}
        placeholder="—" value={sys} aria-label={t('sys')}
        style={{ width: 108, caretColor: pad ? 'transparent' : undefined }}
        onFocus={() => setField('sys')} onClick={() => setField('sys')}
        onChange={e => { if (pad) return; const n = bpDigits(e.target.value); setSys(n); if (n.length === 3) diaRef.current && diaRef.current.focus(); }} />
      <span className="vital-sep">/</span>
      <input ref={diaRef} className={cx('vital-num', pad && !disabled && field === 'dia' && 'active')} type="text"
        readOnly={pad} inputMode={pad ? 'none' : 'numeric'} disabled={disabled}
        placeholder="—" value={dia} aria-label={t('dia')}
        style={{ width: 108, caretColor: pad ? 'transparent' : undefined }}
        onFocus={() => setField('dia')} onClick={() => setField('dia')}
        onChange={e => { if (pad) return; setDia(bpDigits(e.target.value)); }}
        onKeyDown={e => { if (!pad && e.key === 'Backspace' && !dia) sysRef.current && sysRef.current.focus(); }} />
    </div>
    <div style={{ display: 'flex', justifyContent: 'center', gap: 60, marginTop: 4 }}>
      <span className="meta" style={{ color: field === 'sys' ? 'var(--app-accent)' : 'var(--fg3)', fontWeight: 600 }}>{t('sys')}</span>
      <span className="meta" style={{ color: field === 'dia' ? 'var(--app-accent)' : 'var(--fg3)', fontWeight: 600 }}>{t('dia')}</span>
    </div>
    <div className="vital-unit" style={{ textAlign: 'center', marginBottom: 4 }}>{t('unit_bp')}</div>
    {pad && !disabled && <NumPad onPress={press} style={numpadStyle} />}
  </>);
}

/* ── Glucose ────────────────────────────────────────────────────── */
function useGlucoseState() {
  const [value, setValue] = useState('');
  const [ctx, setCtx] = useState('glu_fast');
  const press = (k) => setValue(v => k === 'del' ? v.slice(0, -1) : (v + k).replace(/\D/g, '').slice(0, 3));
  return { value, setValue, ctx, setCtx, press, complete: value.length >= 2 };
}

function GlucoseContextChips({ value, onChange, style }) {
  const { t } = useApp();
  return (
    <div className="chip-wrap" style={style}>
      {['glu_fast','glu_meal','glu_random'].map(c => (
        <div key={c} className={cx('chip', value === c && 'sel')} onClick={() => onChange(c)}>{t(c)}</div>
      ))}
    </div>
  );
}

function GlucoseField({ glucose, disabled = false, numpadStyle }) {
  const { t, numpad } = useApp();
  const pad = numpad !== 'native';
  return (<>
    <div className="vital-display" style={{ padding: '8px 0 4px' }}>
      <input className={cx('vital-num', pad && !disabled && 'active')} type="text"
        readOnly={pad} inputMode={pad ? 'none' : 'numeric'} autoFocus={!pad} disabled={disabled}
        placeholder="—" value={glucose.value} aria-label={t('unit_glu')}
        style={{ minWidth: 150, caretColor: pad ? 'transparent' : undefined }}
        onChange={e => { if (!pad) glucose.setValue(e.target.value.replace(/\D/g, '').slice(0, 3)); }} />
      <div className="vital-unit">{t('unit_glu')}</div>
    </div>
    {pad && !disabled && <NumPad onPress={glucose.press} style={numpadStyle} />}
  </>);
}

/* ── SpO2 (blood oxygen) ────────────────────────────────────────── */
function useO2State() {
  const [value, setValue] = useState('');
  const press = (k) => setValue(v => k === 'del' ? v.slice(0, -1) : (v + k).replace(/\D/g, '').slice(0, 3));
  return { value, setValue, press, complete: value.length >= 2 && Number(value) <= 100 };
}

function O2Field({ o2, disabled = false, numpadStyle }) {
  const { numpad } = useApp();
  const pad = numpad !== 'native';
  return (<>
    <div className="vital-display" style={{ padding: '8px 0 4px' }}>
      <input className={cx('vital-num', pad && !disabled && 'active')} type="text"
        readOnly={pad} inputMode={pad ? 'none' : 'numeric'} autoFocus={!pad} disabled={disabled}
        placeholder="—" value={o2.value} aria-label="SpO2"
        style={{ width: 150, caretColor: pad ? 'transparent' : undefined }}
        onChange={e => { if (!pad) o2.setValue(e.target.value.replace(/\D/g, '').slice(0, 3)); }} />
      <div className="vital-unit">%</div>
    </div>
    {pad && !disabled && <NumPad onPress={o2.press} style={numpadStyle} />}
  </>);
}

/* ── Weight ─────────────────────────────────────────────────────── */
const kgClean = (v) => {
  v = v.replace(/[^\d.]/g, '');
  const i = v.indexOf('.');
  if (i === -1) return v.slice(0, 3);
  return v.slice(0, i).slice(0, 3) + '.' + v.slice(i + 1).replace(/\./g, '').slice(0, 1);
};

function useWeightState() {
  const [value, setValue] = useState('');
  const press = (k) => setValue(v => {
    if (k === 'del') return v.slice(0, -1);
    if (k === '.') return v ? kgClean(v + '.') : '0.';
    return kgClean(v + k);
  });
  return {
    value, setValue, press,
    display: value.endsWith('.') ? value.slice(0, -1) : value,
    complete: (value.split('.')[0] || '').length >= 2,
  };
}

function WeightField({ weight, disabled = false, numpadStyle }) {
  const { numpad } = useApp();
  const pad = numpad !== 'native';
  return (<>
    <div className="vital-display" style={{ padding: '8px 0 4px' }}>
      <input className={cx('vital-num', pad && !disabled && 'active')} type="text"
        readOnly={pad} inputMode={pad ? 'none' : 'decimal'} autoFocus={!pad} disabled={disabled}
        placeholder="—" value={weight.value} aria-label="Weight (kg)"
        style={{ width: 150, caretColor: pad ? 'transparent' : undefined }}
        onChange={e => { if (!pad) weight.setValue(kgClean(e.target.value)); }} />
      <div className="vital-unit">kg</div>
    </div>
    {pad && !disabled && <NumPad decimal onPress={weight.press} style={numpadStyle} />}
  </>);
}

/* ── Pain scale — branded draggable track, RTL-aware ────────────── */
function PainScale({ value, onChange, style }) {
  const { t, lang } = useApp();
  const trackRef = useRef(null);
  const info = painInfo(t, value);
  const setFromEvent = (e) => {
    const el = trackRef.current; if (!el) return;
    const r = el.getBoundingClientRect();
    let ratio = (e.clientX - r.left) / r.width;
    if (lang === 'ar') ratio = 1 - ratio;
    onChange(Math.round(Math.max(0, Math.min(1, ratio)) * 10));
  };
  return (
    <div style={style}>
      <div className="pain-val">
        <div className="pain-n" style={{ color: info.color }}>{value}</div>
        <div className="pain-lbl">{info.lbl}</div>
      </div>
      <div className="pain-track" ref={trackRef}
        onPointerDown={(e) => { e.currentTarget.setPointerCapture(e.pointerId); setFromEvent(e); }}
        onPointerMove={(e) => { if (e.buttons) setFromEvent(e); }}>
        <div className="pain-rail" />
        <div className="pain-knob" style={{ color: info.color, [lang === 'ar' ? 'right' : 'left']: `${value * 10}%` }} />
      </div>
      <div className="pain-ticks"><span>0</span><span>5</span><span>10</span></div>
    </div>
  );
}

/* ── Symptom picker — DS CheckGroup, single- or multi-select ────── */
function SymptomPicker({ selected, onToggle, multi = true, style }) {
  const { t } = useApp();
  const { CheckGroup, Checkbox, Radio } = dsCheck();
  if (!CheckGroup) return null;
  const Control = multi ? Checkbox : Radio;
  const isOn = (id) => multi ? selected.has(id) : selected === id;
  const face = (icon, id) => (
    <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}><Icon name={icon} size={15} />{t(id)}</span>
  );
  return (
    <CheckGroup row style={style}>
      {SYMPTOMS.map(s => (
        <Control key={s.id} name="symptom" checked={isOn(s.id)} onChange={() => onToggle(s.id)} label={face(s.icon, s.id)} />
      ))}
      <Control name="symptom" checked={isOn('s_none')} onChange={() => onToggle('s_none')} label={face('check-circle-2', 's_none')} />
    </CheckGroup>
  );
}

/* ── When (date + time) — every symptom gets its own timestamp ──── */
function nowISO() { const d = new Date(); return d.toISOString().slice(0, 10); }
function nowHM()  { const d = new Date(); return String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0'); }

/* ── iOS-Reminders-style tappable date/time row: colored icon chip,
   label + blue value line, opens the DS picker as a floating popup ── */
function DateTimeRow({ icon, chipBg, chipColor, label, valueText, placeholder, children }) {
  const [open, setOpen] = useState(false);
  const wrapRef = useRef(null);
  useEffect(() => {
    if (!open || !wrapRef.current) return;
    const btn = wrapRef.current.querySelector('.b-picker-trigger');
    if (btn && btn.getAttribute('aria-expanded') !== 'true') btn.click();
    const mo = new MutationObserver(() => {
      if (btn.getAttribute('aria-expanded') === 'false') setOpen(false);
    });
    if (btn) mo.observe(btn, { attributes: true, attributeFilter: ['aria-expanded'] });
    const onDoc = e => { if (!wrapRef.current.contains(e.target)) setOpen(false); };
    document.addEventListener('mousedown', onDoc);
    return () => { mo.disconnect(); document.removeEventListener('mousedown', onDoc); };
  }, [open]);
  return (
    <div className="b-dtrow" ref={wrapRef}>
      <button type="button" className="b-dtrow__head" onClick={() => setOpen(o => !o)}>
        <span className="b-dtrow__icon" style={{ background: chipBg, color: chipColor }}>{icon}</span>
        <span className="b-dtrow__label">{label}</span>
        <span className="b-dtrow__value" style={{ color: valueText ? 'var(--petal-blue)' : 'var(--fg3)' }}>{valueText || placeholder}</span>
      </button>
      {open && <div className="b-dtrow__body">{children}</div>}
    </div>
  );
}

function CalIcon() { return <svg width="17" height="17" viewBox="0 0 16 16" fill="none"><rect x="2.5" y="3.5" width="11" height="10" rx="1.5" stroke="currentColor" strokeWidth="1.5"/><path d="M2.5 6.5h11M5.5 2v3M10.5 2v3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/></svg>; }
function ClockIcon() { return <svg width="17" height="17" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="6" stroke="currentColor" strokeWidth="1.5"/><path d="M8 5v3.3l2 1.2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>; }

function fmtRowDate(iso, lang) {
  if (!iso) return '';
  const d = new Date(iso + 'T00:00:00');
  const today = new Date(); today.setHours(0,0,0,0);
  if (d.getTime() === today.getTime()) return lang === 'ar' ? 'اليوم' : 'Today';
  return d.toLocaleDateString(lang === 'ar' ? 'ar-EG' : 'en-US', { day: 'numeric', month: 'short' });
}
function fmtRowTime(hm, lang) {
  if (!hm) return '';
  const [h, m] = hm.split(':').map(Number);
  const d = new Date(); d.setHours(h, m);
  return d.toLocaleTimeString(lang === 'ar' ? 'ar-EG' : 'en-US', { hour: 'numeric', minute: '2-digit' });
}

function SymptomWhen({ date, setDate, time, setTime, bare }) {
  const { lang } = useApp();
  const { DatePicker, TimePicker } = dsCheck();
  if (!DatePicker || !TimePicker) return null;
  return (
    <div className="b-dtgroup" style={bare ? { border: 'none', borderRadius: 0 } : { marginTop: 16, marginBottom: 16 }}>
      <DateTimeRow icon={<CalIcon />} chipBg="var(--balsm-danger-50, #FCEAE7)" chipColor="var(--balsm-danger, #D44A3C)"
        label={lang === 'ar' ? 'التاريخ' : 'Date'} valueText={fmtRowDate(date, lang)}>
        <DatePicker value={date} onChange={setDate} max={nowISO()} />
      </DateTimeRow>
      <DateTimeRow icon={<ClockIcon />} chipBg="var(--petal-blue-50, #E4F0FF)" chipColor="var(--petal-blue)"
        label={lang === 'ar' ? 'الوقت' : 'Time'} valueText={fmtRowTime(time, lang)}>
        <TimePicker value={time} onChange={setTime} use12Hour />
      </DateTimeRow>
    </div>
  );
}

/* ── Note + photo attachment ────────────────────────────────────── */
function NoteAttach({ note, setNote, photo, setPhoto, style }) {
  const { t } = useApp();
  const fileRef = useRef(null);
  const list = !photo ? [] : Array.isArray(photo) ? photo : [typeof photo === 'string' ? { url: photo, kind: 'image' } : photo];
  return (
    <div style={{ marginTop: 18, paddingTop: 18, borderTop: '1px solid var(--balsm-ink-100)', ...style }}>
      <label style={{ fontSize: 'var(--pt-sm)', fontWeight: 600, color: 'var(--fg3)', display: 'block', marginBottom: 8 }}>
        {t('note_lbl')}
      </label>
      <textarea className="textarea" style={{ minHeight: 72, fontSize: 'var(--pt-md)' }}
        placeholder={t('note_ph')} value={note} onChange={e => setNote(e.target.value)} />
      <AttachmentInput inputRef={fileRef} onPick={picked => setPhoto([...list, ...picked])} />
      {list.length ? (
        <div style={{ marginTop: 10 }}>
          <AttachmentGallery atts={list} height={130}
            onRemove={i => { const next = list.filter((_, n) => n !== i); setPhoto(next.length ? next : null); }}
            onAdd={() => fileRef.current?.click()} />
        </div>
      ) : (
        <div className="photo-add" onClick={() => fileRef.current?.click()} style={{ marginTop: 10 }}>
          <Icon name="camera" size={20} /><span className="body-sm">{t('add_photo')}</span>
        </div>
      )}
    </div>
  );
}

/* ── Accordion of body maps, one per located symptom ─────────────
   Stacking every symptom's full map was the pain point (too tall, no
   sense of scale) — this collapses each into a summary row (icon,
   marked-area count) and opens one map at a time. */
function SymptomBodyMaps({ syms, symLocs, onToggleRegion }) {
  const { t, lang } = useApp();
  const located = SYMPTOMS.filter(s => s.loc && syms.has(s.id));
  const [open, setOpen] = useState(located[0]?.id ?? null);
  useEffect(() => { if (located.length && !located.find(s => s.id === open)) setOpen(located[0]?.id ?? null); }, [syms]);
  if (!located.length) return null;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <div style={{ fontSize: 'var(--pt-xs)', fontWeight: 700, letterSpacing: '0.06em', textTransform: 'uppercase', color: 'var(--fg4)' }}>
        {lang === 'ar' ? 'حدّدي أماكن الأعراض' : 'Mark where it hurts'}
      </div>
      {located.map(s => {
        const count = (symLocs[s.id] || new Set()).size;
        const isOpen = open === s.id;
        return (
          <div key={s.id} className="card" style={{ padding: 0, overflow: 'hidden' }}>
            <button onClick={() => setOpen(isOpen ? null : s.id)} style={{
              width: '100%', display: 'flex', alignItems: 'center', gap: 12, padding: '13px 14px',
              background: 'transparent', border: 'none', cursor: 'pointer', textAlign: 'start', font: 'inherit',
            }}>
              <div style={{
                width: 34, height: 34, borderRadius: 'var(--radius-md)', flexShrink: 0,
                background: count ? 'var(--app-accent-50)' : 'var(--balsm-ink-50)',
                color: count ? 'var(--app-accent)' : 'var(--fg3)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}><Icon name={s.icon} size={16} /></div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 600, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{t(s.id)}</div>
                <div style={{ fontSize: 'var(--pt-xs)', color: count ? 'var(--app-accent)' : 'var(--fg4)', marginTop: 1, fontWeight: 600 }}>
                  {count
                    ? `${count} ${lang === 'ar' ? (count === 1 ? 'موضع محدد' : 'مواضع محددة') : (count === 1 ? 'area marked' : 'areas marked')}`
                    : (lang === 'ar' ? 'اضغطي للتحديد' : 'Tap to mark location')}
                </div>
              </div>
              <Icon name="chevron-down" size={18} style={{ color: 'var(--fg4)', flexShrink: 0, transition: 'transform 0.2s var(--ease-out)', transform: isOpen ? 'rotate(180deg)' : 'none' }} />
            </button>
            {isOpen && (
              <div style={{ padding: '14px 14px 16px', borderTop: '1px solid var(--balsm-ink-100)' }}>
                <BodyMap selected={symLocs[s.id] || new Set()} onToggle={(rid) => onToggleRegion(s.id, rid)} initialGender={PATIENT.gender} />
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

/* ── Symptom add-list — "+ Add symptom" instead of a wall of chips ──
   Each added symptom is its own row, in the order added; a row whose
   symptom needs a location expands in place to its dedicated map
   (one open at a time). Replaces the flat chip grid + separate map
   stack for both quick-log and the full check-in. */
function SymptomAddList({ symList, symLocs, onAdd, onRemove, onToggleRegion, onNone, isNone, symWhen, onSetWhen }) {
  const { t, lang } = useApp();
  const [picking, setPicking] = useState(false);
  const [openMap, setOpenMap] = useState(null);
  const available = SYMPTOMS.filter(s => !symList.includes(s.id));

  const addRow = (id) => {
    onAdd(id);
    setPicking(false);
    if (SYMPTOMS.find(s => s.id === id)?.loc) setOpenMap(id);
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      {symList.map(id => {
        const s = SYMPTOMS.find(x => x.id === id); if (!s) return null;
        const count = (symLocs[id] || new Set()).size;
        const isOpen = openMap === id;
        return (
          <div key={id} className="card" style={{ padding: 0, overflow: 'hidden' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 8px 12px 14px' }}>
              <button onClick={() => s.loc && setOpenMap(isOpen ? null : id)} style={{
                flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 12, textAlign: 'start',
                background: 'transparent', border: 'none', cursor: s.loc ? 'pointer' : 'default', padding: 0, font: 'inherit',
              }}>
                <div style={{ width: 34, height: 34, borderRadius: 'var(--radius-md)', flexShrink: 0, background: count ? 'var(--app-accent-50)' : 'var(--balsm-ink-50)', color: count ? 'var(--app-accent)' : 'var(--fg3)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Icon name={s.icon} size={16} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontWeight: 600, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{t(id)}</div>
                  {s.loc && (
                    <div style={{ fontSize: 'var(--pt-xs)', color: count ? 'var(--app-accent)' : 'var(--fg4)', marginTop: 1, fontWeight: 600 }}>
                      {count
                        ? `${count} ${lang === 'ar' ? (count === 1 ? 'موضع محدد' : 'مواضع محددة') : (count === 1 ? 'area marked' : 'areas marked')}`
                        : (lang === 'ar' ? 'اضغطي للتحديد' : 'Tap to mark location')}
                    </div>
                  )}
                </div>
                {s.loc && <Icon name="chevron-down" size={17} style={{ color: 'var(--fg4)', flexShrink: 0, transition: 'transform 0.2s var(--ease-out)', transform: isOpen ? 'rotate(180deg)' : 'none' }} />}
              </button>
              <button onClick={() => { onRemove(id); if (openMap === id) setOpenMap(null); }} aria-label={lang === 'ar' ? 'إزالة' : 'Remove'}
                style={{ border: 'none', background: 'transparent', color: 'var(--fg4)', cursor: 'pointer', display: 'flex', padding: 6, flexShrink: 0 }}>
                <Icon name="x" size={16} />
              </button>
            </div>
            {s.loc && isOpen && (
              <div style={{ padding: '2px 14px 16px', borderTop: '1px solid var(--balsm-ink-100)' }}>
                <div style={{ paddingTop: 14 }}>
                  <BodyMap selected={symLocs[id] || new Set()} onToggle={(rid) => onToggleRegion(id, rid)} initialGender={PATIENT.gender} allowedLayers={s.layers} />
                </div>
              </div>
            )}
            {symWhen && onSetWhen && (
              <div style={{ borderTop: !(s.loc && isOpen) ? '1px solid var(--balsm-ink-100)' : 'none' }}>
                <SymptomWhen
                  date={(symWhen[id] || {}).date || nowISO()} setDate={(v) => onSetWhen(id, { ...(symWhen[id] || {}), date: v })}
                  time={(symWhen[id] || {}).time || nowHM()} setTime={(v) => onSetWhen(id, { ...(symWhen[id] || {}), time: v })}
                  bare
                />
              </div>
            )}
          </div>
        );
      })}

      {picking ? (
        <div className="card" style={{ padding: 14 }}>
          <div style={{ fontSize: 'var(--pt-xs)', fontWeight: 700, color: 'var(--fg3)', marginBottom: 10, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <span>{lang === 'ar' ? 'اختاري عرضًا' : 'Pick a symptom'}</span>
            <button onClick={() => setPicking(false)} style={{ border: 'none', background: 'transparent', color: 'var(--fg4)', cursor: 'pointer', display: 'flex' }}><Icon name="x" size={15} /></button>
          </div>
          {available.length === 0 ? (
            <div className="meta" style={{ textAlign: 'center', padding: '6px 0' }}>{lang === 'ar' ? 'أضفتِ كل الأعراض' : "You've added them all"}</div>
          ) : (
            <div className="chip-wrap">
              {available.map(s => (
                <div key={s.id} className="chip" onClick={() => addRow(s.id)}><Icon name={s.icon} size={15} />{t(s.id)}</div>
              ))}
            </div>
          )}
        </div>
      ) : (
        <button className="b-btn b-btn-md b-btn-secondary b-btn--full" style={{ borderStyle: 'dashed', gap: 8 }}
          onClick={() => setPicking(true)} disabled={isNone}>
          <Icon name="plus" size={17} />{lang === 'ar' ? 'أضف عرضًا' : 'Add symptom'}
        </button>
      )}

      {symList.length === 0 && !picking && (
        <button onClick={onNone} style={{
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7, marginTop: 2,
          border: 'none', background: 'transparent', cursor: 'pointer', padding: '6px 0',
          color: isNone ? 'var(--app-accent)' : 'var(--fg3)', fontWeight: 600, fontSize: 'var(--pt-sm)',
        }}>
          <Icon name={isNone ? 'check-circle-2' : 'circle'} size={16} />{t('s_none')}
        </button>
      )}
    </div>
  );
}

Object.assign(window, {
  SYMPTOMS, symptomNeedsLocation, regionsForSymptom, PAIN_COLORS, painInfo,
  MoodPicker, useBPState, BPField, useGlucoseState, GlucoseContextChips, GlucoseField,
  useWeightState, WeightField, useO2State, O2Field, PainScale, SymptomPicker, SymptomBodyMaps, SymptomAddList, NoteAttach,
  SymptomWhen, nowISO, nowHM, DateTimeRow, CalIcon, ClockIcon, fmtRowDate, fmtRowTime,
});
