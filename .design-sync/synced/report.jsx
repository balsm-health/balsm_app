/* report.jsx — the daily self-report check-in flow + summary.
   Every metric input here is the SAME component the quick-log sheet uses
   (metric-inputs.jsx): MoodPicker, BPField, GlucoseField, PainScale,
   SymptomPicker, NoteAttach. Nothing metric-related is re-implemented. */

function ReportFlow({ onClose, onDone }) {
  const { t, lang } = useApp();
  const STEPS = ['mood', 'bp', 'glucose', 'meds'];
  const [step, setStep] = useState(0);
  const [submitted, setSubmitted] = useState(false);

  const [mood, setMood] = useState(0);
  const bp = useBPState();
  const glucose = useGlucoseState();
  const [bpSkip, setBpSkip] = useState(false);
  const [gluSkip, setGluSkip] = useState(false);
  const [meds, setMeds] = useState(() => Object.fromEntries(MEDS.map(m => [m.id, null])));
  const [moodWhen, setMoodWhen] = useState({ date: nowISO(), time: nowHM() });
  const [bpWhen, setBpWhen] = useState({ date: nowISO(), time: nowHM() });
  const [gluWhen, setGluWhen] = useState({ date: nowISO(), time: nowHM() });
  const [note, setNote] = useState('');
  const [photo, setPhoto] = useState(null);

  const pct = ((step + 1) / STEPS.length) * 100;
  const cur = STEPS[step];

  const canNext = {
    mood: mood > 0,
    bp: bpSkip || bp.complete,
    glucose: gluSkip || glucose.complete,
    meds: true,
  }[cur];

  const next = () => { if (step < STEPS.length - 1) setStep(s => s + 1); else setSubmitted(true); };
  const back = () => { if (step > 0) setStep(s => s - 1); else onClose(); };

  if (submitted) return <Summary {...{ mood, bpSys: bp.sys, bpDia: bp.dia, bpSkip, glu: glucose.value, gluCtx: glucose.ctx, gluSkip, meds, onClose, onDone }} />;

  return (
    <div className="flow">
      <div className="pad-top" />
      <div className="flow-top">
        <button className="round-btn ghost" onClick={back} aria-label="Back">
          <Icon name={step === 0 ? 'x' : 'arrow-left'} />
        </button>
        <div className="progress"><div className="bar" style={{ width: pct + '%' }} /></div>
        <span className="meta num" style={{ minWidth: 38, textAlign: 'center' }}>{step + 1} {t('step_of')} {STEPS.length}</span>
      </div>

      <div className="flow-body" key={cur}>
        <div className="fade-in">
          {/* MOOD */}
          {cur === 'mood' && <>
            <h2 className="q-title">{t('q_mood_t')}</h2>
            <p className="q-help">{t('q_mood_h')}</p>
            <MoodPicker value={mood} onChange={setMood} />
            <SymptomWhen date={moodWhen.date} setDate={d => setMoodWhen(w => ({ ...w, date: d }))} time={moodWhen.time} setTime={tm => setMoodWhen(w => ({ ...w, time: tm }))} />
          </>}

          {/* BLOOD PRESSURE */}
          {cur === 'bp' && <>
            <h2 className="q-title">{t('q_bp_t')}</h2>
            <p className="q-help">{t('q_bp_h')}</p>
            <div className={cx('card card-pad', bpSkip && 'is-disabled')} style={{ opacity: bpSkip ? 0.4 : 1 }}>
              <BPField bp={bp} disabled={bpSkip} numpadStyle={{ marginTop: 14 }} />
            </div>
            <SkipRow on={bpSkip} set={setBpSkip} t={t} />
            {!bpSkip && <SymptomWhen date={bpWhen.date} setDate={d => setBpWhen(w => ({ ...w, date: d }))} time={bpWhen.time} setTime={tm => setBpWhen(w => ({ ...w, time: tm }))} />}
          </>}

          {/* GLUCOSE */}
          {cur === 'glucose' && <>
            <h2 className="q-title">{t('q_glu_t')}</h2>
            <p className="q-help">{t('q_glu_h')}</p>
            <GlucoseContextChips value={glucose.ctx} onChange={glucose.setCtx} style={{ marginBottom: 16 }} />
            <div className="card card-pad" style={{ opacity: gluSkip ? 0.4 : 1 }}>
              <GlucoseField glucose={glucose} disabled={gluSkip} numpadStyle={{ marginTop: 14 }} />
            </div>
            <SkipRow on={gluSkip} set={setGluSkip} t={t} />
            {!gluSkip && <SymptomWhen date={gluWhen.date} setDate={d => setGluWhen(w => ({ ...w, date: d }))} time={gluWhen.time} setTime={tm => setGluWhen(w => ({ ...w, time: tm }))} />}
          </>}

          {/* MEDS */}
          {cur === 'meds' && <>
            <h2 className="q-title">{t('q_med_t')}</h2>
            <p className="q-help">{t('q_med_h')}</p>
            {MEDS.map(m => {
              const st = meds[m.id];
              return (
                <div key={m.id} className={cx('check-row', st === 'taken' && 'taken', st === 'skipped' && 'skipped')}
                  onClick={() => setMeds(p => ({ ...p, [m.id]: p[m.id] === 'taken' ? null : 'taken' }))}>
                  <div className="check-box">{st === 'taken' && <Icon name="check" />}</div>
                  <div className="grow">
                    <div className="cname">{m.name[lang]}</div>
                    <div className="cdose">{m.dose[lang]}</div>
                  </div>
                  {st === 'skipped'
                    ? <span className="b-badge b-badge--neutral">{t('skipped')}</span>
                    : <span className="skip-link" onClick={(e) => { e.stopPropagation(); setMeds(p => ({ ...p, [m.id]: 'skipped' })); }}>{t('mark_skip')}</span>}
                </div>
              );
            })}
          </>}
        </div>
      </div>

      <div className="flow-foot">
        <button className={cx('b-btn b-btn-lg b-btn-primary b-btn--full', !canNext && 'is-disabled')} onClick={next}>
          {step === STEPS.length - 1 ? t('finish') : t('continue')}
        </button>
      </div>
    </div>
  );
}

function SkipRow({ on, set, t }) {
  return (
    <div style={{ textAlign: 'center', marginTop: 14 }}>
      <button className="b-btn b-btn-md b-btn-ghost" onClick={() => set(!on)} style={{ height: 44 }}>
        <Icon name={on ? 'check-circle-2' : 'circle'} size={18} />{t('skip_q')}
      </button>
    </div>
  );
}

function Summary({ mood, bpSys, bpDia, bpSkip, glu, gluCtx, gluSkip, meds, onClose, onDone }) {
  const { t, lang, completeCheckin } = useApp();
  const takenCount = MEDS.filter(m => meds[m.id] === 'taken').length;
  const report = {
    mood, takenCount,
    bp: bpSkip ? null : `${bpSys}/${bpDia}`,
    glu: gluSkip ? null : glu, gluCtx,
  };
  const finishTo = (tab) => { completeCheckin && completeCheckin(report); onDone(tab); };
  const items = [
    { icon: 'smile', tone: 'info', lab: t('m_mood'), val: mood ? t('mood_' + mood) : '—' },
    !bpSkip && { icon: 'activity', tone: 'violet', lab: t('m_bp'), val: `${bpSys}/${bpDia} ${t('unit_bp')}` },
    !gluSkip && { icon: 'droplet', tone: 'success', lab: `${t('m_glucose')} · ${t(gluCtx)}`, val: `${glu} ${t('unit_glu')}` },
    { icon: 'pill', tone: 'info', lab: t('meds_today'), val: `${takenCount}/${MEDS.length} ${t('meds_taken')}` },
  ].filter(Boolean);

  const toneBg = { info: 'var(--petal-blue-50)', violet: 'var(--petal-violet-50)', success: 'var(--petal-mint-50)', warn: '#FDF5DC', neutral: 'var(--balsm-ink-100)' };
  const toneFg = { info: 'var(--petal-blue)', violet: 'var(--petal-violet)', success: 'var(--petal-mint-600)', warn: 'var(--balsm-sun-600)', neutral: 'var(--balsm-ink-600)' };

  return (
    <div className="flow" style={{ background: '#fff' }}>
      <div className="pad-top" />
      <div className="screen-scroll">
        <div className="confirm-hero fade-in">
          <div className="confirm-mark"><Icon name="check" /></div>
          <h1 className="title" style={{ margin: 0 }}>{t('saved_t')}</h1>
          <div className="save-note"><Icon name="cloud-off" />{t('saved_local')}</div>
        </div>
        <div className="summary-list">
          {items.map((it, i) => (
            <div key={i} className="summary-item">
              <div className="sico" style={{ background: toneBg[it.tone], color: toneFg[it.tone] }}><Icon name={it.icon} /></div>
              <div className="grow">
                <div className="slab">{it.lab}</div>
                <div className="sval" dir={lang==='ar' && /[A-Za-z0-9]/.test(it.val) ? 'ltr' : undefined} style={{ display: 'inline-block' }}>{it.val}</div>
              </div>
            </div>
          ))}
        </div>
        <p className="meta px-20" style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 18 }}>
          <Icon name="send" size={15} />{t('to_doctor')}
        </p>
      </div>
      <div className="flow-foot" style={{ background: '#fff', gap: 12 }}>
        <button className="b-btn b-btn-lg b-btn-secondary" style={{ flex: 1 }} onClick={() => finishTo('trends')}>{t('view_trends')}</button>
        <button className="b-btn b-btn-lg b-btn-primary" style={{ flex: 1 }} onClick={() => finishTo('home')}>{t('to_home')}</button>
      </div>
    </div>
  );
}

Object.assign(window, { ReportFlow });
