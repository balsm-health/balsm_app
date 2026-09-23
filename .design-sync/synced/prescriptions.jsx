/* prescriptions.jsx — Prescriptions list + detail with QR code */
/* Card/Avatar resolved lazily inside components — the DS bundle loads deferred, after this script. */
const PETAL_TONE = {
  'var(--petal-aqua)': 'aqua', 'var(--petal-emerald)': 'emerald', 'var(--petal-blue)': 'blue',
  'var(--petal-mint)': 'mint', 'var(--petal-mint-600)': 'mint', 'var(--petal-violet)': 'violet',
};
function DoctorAvatar({ doctor, size = 44 }) {
  const { Avatar } = window.BalsmDesignSystem_51cdbf || {};
  if (!Avatar) return null;
  const dsSize = size >= 56 ? 'xl' : size >= 42 ? 'lg' : size >= 30 ? 'md' : size >= 24 ? 'sm' : 'xs';
  return <Avatar name={doctor.name.en} initials={doctor.initials} tone={PETAL_TONE[doctor.color]} size={dsSize} />;
}

/* Decorative QR code drawn as SVG — visually correct, not scannable */
function QRCode({ size = 152 }) {
  const cell = size / 21;
  const p = [
    [1,1,1,1,1,1,1,0,1,0,1,0,0,0,1,1,1,1,1,1,1],
    [1,0,0,0,0,0,1,0,0,1,0,1,0,0,1,0,0,0,0,0,1],
    [1,0,1,1,1,0,1,0,1,0,1,0,1,0,1,0,1,1,1,0,1],
    [1,0,1,1,1,0,1,0,0,1,0,1,0,0,1,0,1,1,1,0,1],
    [1,0,1,1,1,0,1,0,1,0,1,0,1,0,1,0,1,1,1,0,1],
    [1,0,0,0,0,0,1,0,0,1,0,1,0,0,1,0,0,0,0,0,1],
    [1,1,1,1,1,1,1,0,1,0,1,0,1,0,1,1,1,1,1,1,1],
    [0,0,0,0,0,0,0,0,1,1,0,1,0,0,0,0,0,0,0,0,0],
    [1,0,1,1,0,0,1,1,0,0,1,1,1,0,1,0,1,0,0,1,0],
    [0,1,0,0,1,0,0,0,1,0,1,0,0,1,0,1,0,1,1,0,1],
    [1,1,0,1,0,1,1,0,0,1,0,1,1,0,1,0,1,0,1,0,0],
    [0,0,1,0,1,0,0,1,1,0,1,0,0,1,0,1,0,1,0,1,0],
    [1,0,0,1,0,1,1,0,1,0,0,1,1,0,1,1,0,0,1,0,1],
    [0,0,0,0,0,0,0,0,0,1,1,0,0,1,0,1,0,1,0,1,0],
    [1,1,1,1,1,1,1,0,1,0,0,1,1,0,1,0,1,0,1,0,1],
    [1,0,0,0,0,0,1,0,0,1,1,0,0,1,0,1,0,1,0,0,0],
    [1,0,1,1,1,0,1,0,1,0,1,1,1,0,1,0,0,1,1,0,1],
    [1,0,1,1,1,0,1,0,0,1,0,0,0,1,0,1,1,0,0,1,0],
    [1,0,1,1,1,0,1,0,1,0,1,0,1,1,1,0,0,1,0,0,1],
    [1,0,0,0,0,0,1,0,0,1,0,1,0,0,0,1,1,0,1,0,0],
    [1,1,1,1,1,1,1,0,1,0,1,0,1,1,1,0,0,1,0,1,1],
  ];
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ display: 'block' }}>
      <rect width={size} height={size} fill="#fff" rx="4" />
      {p.map((row, ri) =>
        row.map((v, ci) =>
          v ? (
            <rect key={`${ri}-${ci}`}
              x={ci * cell + 0.5} y={ri * cell + 0.5}
              width={cell - 0.5} height={cell - 0.5}
              fill="#1A1A17"
            />
          ) : null
        )
      )}
    </svg>
  );
}

function PrescriptionDetail({ rx, onBack, onDelete }) {
  const { t, lang } = useApp();
  const doctor   = rx.doctorId ? DOCTORS.find(d => d.id === rx.doctorId) : null;
  const isActive = rx.status === 'active';
  const isSelf   = rx.source === 'self';

  return (
    <div className="screen fade-in">
      <div className="pad-top" />
      <div className="appbar">
        <button className="round-btn" onClick={onBack} aria-label="Back"><Icon name="arrow-left" /></button>
        <div style={{ flex: 1 }} />
        {isSelf
          ? <button className="round-btn ghost" onClick={onDelete} aria-label={t('rx_delete')}><Icon name="trash-2" size={18} style={{ color: 'var(--balsm-danger)' }} /></button>
          : <span className={cx('b-badge', isActive ? 'b-badge--success' : 'b-badge--neutral')}>
              <span className="b-badge__dot" />{t(isActive ? 'rx_active' : 'rx_expired')}
            </span>}
      </div>

      <div className="screen-scroll">
        {/* Doctor / self header */}
        <div style={{ padding: '4px 20px 18px' }}>
          {doctor ? (
            <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 14 }}>
              <DoctorAvatar doctor={doctor} size={50} />
              <div>
                <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{doctor.name[lang]}</div>
                <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', marginTop: 2 }}>{doctor.specialty[lang]}</div>
              </div>
            </div>
          ) : isSelf && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 14 }}>
              <div style={{ width: 50, height: 50, borderRadius: '50%', background: 'var(--petal-blue-50)', color: 'var(--petal-blue)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <Icon name="user" size={22} />
              </div>
              <div>
                <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{rx.title[lang]}</div>
                {rx.doctorName
                  ? <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', marginTop: 2 }}>{t('rx_prescribed_by')} {rx.doctorName}</div>
                  : null}
                <span className="b-badge b-badge--neutral" style={{ marginTop: 4 }}>{t('rx_self_added')}</span>
              </div>
            </div>
          )}
          <div style={{ display: 'flex', gap: 24 }}>
            <div>
              <div style={{ fontSize: 'var(--pt-2xs)', fontWeight: 700, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--fg4)', marginBottom: 3 }}>Issued</div>
              <div style={{ fontSize: 'var(--pt-sm)', fontWeight: 600, color: 'var(--fg1)' }}>{rx.date[lang]}</div>
            </div>
            {rx.validUntil && (
              <div>
                <div style={{ fontSize: 'var(--pt-2xs)', fontWeight: 700, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--fg4)', marginBottom: 3 }}>{t('rx_valid_until')}</div>
                <div style={{ fontSize: 'var(--pt-sm)', fontWeight: 600, color: isActive ? 'var(--fg1)' : 'var(--balsm-danger)' }}>{rx.validUntil[lang]}</div>
              </div>
            )}
          </div>
        </div>

        {isSelf && (
          <div style={{ margin: '0 20px 18px', padding: '12px 14px', background: 'var(--balsm-cream-100)', borderRadius: 'var(--radius-md)', display: 'flex', gap: 10, alignItems: 'flex-start' }}>
            <Icon name="info" size={16} style={{ color: 'var(--fg3)', flexShrink: 0, marginTop: 1 }} />
            <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', lineHeight: 1.5 }}>{t('rx_self_note')}</div>
          </div>
        )}

        {/* Self-added file attachment */}
        {isSelf && (rx.files || rx.file) && (
          <div style={{ margin: '0 20px 20px' }}>
            <AttachmentGallery atts={rx.files || [rx.file]} height={220} />
          </div>
        )}

        {/* QR code block */}
        {!isSelf && isActive && (
          <div style={{
            margin: '0 20px 20px', padding: '24px 20px',
            background: 'var(--balsm-cream-100)', borderRadius: 'var(--radius-xl)',
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14,
          }}>
            <div style={{ fontSize: 'var(--pt-2xs)', fontWeight: 700, letterSpacing: '0.14em', textTransform: 'uppercase', color: 'var(--fg3)' }}>
              {t('rx_scan')}
            </div>
            <div style={{ padding: 14, background: '#fff', borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-sm)' }}>
              <QRCode size={148} />
            </div>
            <div className="num" style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', letterSpacing: '0.06em' }}>{rx.ref}</div>
          </div>
        )}

        {/* Medications list */}
        {rx.meds && rx.meds.length > 0 && <>
          <div className="row-head" style={{ marginTop: (!isSelf && isActive) ? 4 : 0 }}><h2>Medications</h2></div>
          <div className="card" style={{ margin: '0 20px' }}>
            {rx.meds.map((m, i) => (
              <div key={i} className="med-row">
                <div className="med-ico" style={{ background: 'var(--petal-blue-50)', color: 'var(--petal-blue)' }}>
                  <Icon name="pill" size={20} />
                </div>
                <div className="grow">
                  <div className="mname">{m.name[lang]}</div>
                  <div className="mdose">{m.dose[lang]}</div>
                  {m.desc && <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', marginTop: 3, lineHeight: 1.4 }}>{m.desc[lang]}</div>}
                </div>
              </div>
            ))}
          </div>
        </>}

        {!isSelf && isActive && (
          <div style={{ padding: '20px 20px 0' }}>
            <button className="b-btn b-btn-lg b-btn-primary b-btn--full">
              <Icon name="qr-code" size={20} />{t('rx_show')}
            </button>
          </div>
        )}

        <div style={{ height: 28 }} />
      </div>
    </div>
  );
}

/* ── Add prescription (self-added) ─────────────────────── */
function fmtRxDate(iso) {
  const d = new Date(iso + 'T00:00:00');
  if (isNaN(d)) return { en: 'Today', ar: 'اليوم' };
  return {
    en: d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }),
    ar: d.toLocaleDateString('ar-EG', { day: '2-digit', month: 'long', year: 'numeric' }),
  };
}

/* Stable top-level component — must NOT be redefined inside AddPrescriptionSheet's
   render (a fresh function identity on every render would force React to remount
   this subtree on every keystroke elsewhere in the form, dropping its own input's value). */
function RxMetaFields({ doctorName, setDoctorName, rxDate, setRxDate, rxTime, setRxTime, rxExpiry, setRxExpiry }) {
  const { t, lang } = useApp();
  const { DatePicker, TimePicker } = dsCheck();
  const { DateTimeRow, CalIcon, ClockIcon, fmtRowDate, fmtRowTime } = window;
  return (
    <>
      <div className="field">
        <label style={{ display: 'flex', alignItems: 'center', gap: 6 }}><Icon name="stethoscope" size={13} style={{ color: 'var(--fg4)' }} />{t('rx_doctor_name')}</label>
        <input className="b-input" value={doctorName} onChange={e => setDoctorName(e.target.value)} placeholder={t('rx_doctor_name_ph')} />
      </div>
      {DatePicker && (
        <div className="b-dtgroup">
          <DateTimeRow icon={<CalIcon />} chipBg="var(--balsm-danger-50, #FCEAE7)" chipColor="var(--balsm-danger, #D44A3C)"
            label={t('rx_date')} valueText={fmtRowDate(rxDate, lang)}>
            <DatePicker value={rxDate} onChange={setRxDate} />
          </DateTimeRow>
          {TimePicker && (
            <DateTimeRow icon={<ClockIcon />} chipBg="var(--petal-blue-50, #E4F0FF)" chipColor="var(--petal-blue)"
              label={lang === 'ar' ? 'الوقت' : 'Time'} valueText={fmtRowTime(rxTime, lang)}>
              <TimePicker value={rxTime} onChange={setRxTime} use12Hour />
            </DateTimeRow>
          )}
          <DateTimeRow icon={<CalIcon />} chipBg="var(--petal-violet-50, #EEE7FB)" chipColor="var(--petal-violet)"
            label={t('rx_expiry')} valueText={fmtRowDate(rxExpiry, lang)}>
            <DatePicker value={rxExpiry} onChange={setRxExpiry} min={rxDate} />
          </DateTimeRow>
        </div>
      )}
    </>
  );
}

/* Native select styled to match the app's existing chevron-select pattern (e.g. Nationality). */
function SelectField({ value, onChange, options, style }) {
  return (
    <div style={{ position: 'relative', flex: 1, ...style }}>
      <select className="b-input" value={value} onChange={e => onChange(e.target.value)}
        style={{ appearance: 'none', WebkitAppearance: 'none', paddingInlineEnd: 34, cursor: 'pointer', width: '100%' }}>
        {options.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
      </select>
      <Icon name="chevron-down" size={15} style={{ position: 'absolute', insetInlineEnd: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fg3)', pointerEvents: 'none' }} />
    </div>
  );
}

/* One medication's dose + structured frequency/duration \u2014 stable top-level component
   (frequency/duration are captured as data for the future reminder feature, not just display text). */
function MedRow({ m, i, setMed, onRemove, canRemove }) {
  const { t, lang } = useApp();
  const set = (key, val) => setMed(i, key, val);
  return (
    <div className="card card-pad" style={{ display: 'flex', flexDirection: 'column', gap: 12, position: 'relative' }}>
      {canRemove && (
        <button onClick={onRemove} aria-label="Remove" style={{ position: 'absolute', top: 8, insetInlineEnd: 8, width: 26, height: 26, borderRadius: 999, border: 'none', background: 'var(--balsm-ink-50)', color: 'var(--fg3)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1 }}><Icon name="x" size={13} /></button>
      )}
      <input className="b-input" value={m.name} onChange={e => set('name', e.target.value)} placeholder={t('rx_med_name_ph')} />
      <input className="b-input" value={m.dose} onChange={e => set('dose', e.target.value)} placeholder={t('rx_med_dose_ph')} />
      <textarea className="b-input" rows={2} value={m.desc} onChange={e => set('desc', e.target.value)} placeholder={t('rx_med_desc_ph')} style={{ resize: 'vertical', minHeight: 40 }} />

      <div>
        <label style={{ fontSize: 'var(--pt-xs)', fontWeight: 600, color: 'var(--fg3)', display: 'block', marginBottom: 6 }}>{t('rx_frequency')}</label>
        <div style={{ display: 'flex', gap: 8 }}>
          <SelectField value={m.freqType} onChange={v => set('freqType', v)} options={[
            { value: 'once', label: t('freq_once') },
            { value: 'per_day', label: t('freq_per_day') },
            { value: 'every_x', label: t('freq_every_x') },
            { value: 'other', label: t('freq_other') },
          ]} />
          {m.freqType === 'per_day' && (
            <input className="b-input num" dir="ltr" type="number" min="1" max="12" value={m.freqN}
              onChange={e => set('freqN', e.target.value.replace(/\D/g, ''))} style={{ width: 64, textAlign: 'center', flexShrink: 0 }} />
          )}
          {m.freqType === 'every_x' && (
            <>
              <input className="b-input num" dir="ltr" type="number" min="1" value={m.freqN}
                onChange={e => set('freqN', e.target.value.replace(/\D/g, ''))} style={{ width: 56, textAlign: 'center', flexShrink: 0 }} />
              <SelectField value={m.freqUnit} onChange={v => set('freqUnit', v)} style={{ flex: 1 }} options={[
                { value: 'hours', label: t('unit_hours') },
                { value: 'days', label: t('unit_days') },
              ]} />
            </>
          )}
        </div>
        {m.freqType === 'other' && (
          <input className="b-input" value={m.freqOther} onChange={e => set('freqOther', e.target.value)} placeholder={t('freq_other_ph')} style={{ marginTop: 8 }} />
        )}
      </div>

      <div>
        <label style={{ fontSize: 'var(--pt-xs)', fontWeight: 600, color: 'var(--fg3)', display: 'block', marginBottom: 6 }}>{t('rx_duration')}</label>
        <div style={{ display: 'flex', gap: 8 }}>
          <SelectField value={m.durType} onChange={v => set('durType', v)} options={[
            { value: 'days', label: t('dur_days') },
            { value: 'weeks', label: t('dur_weeks') },
            { value: 'months', label: t('dur_months') },
            { value: 'until_empty', label: t('dur_until_empty') },
            { value: 'ongoing', label: t('dur_ongoing') },
            { value: 'other', label: t('dur_other') },
          ]} />
          {['days', 'weeks', 'months'].includes(m.durType) && (
            <input className="b-input num" dir="ltr" type="number" min="1" value={m.durN}
              onChange={e => set('durN', e.target.value.replace(/\D/g, ''))} style={{ width: 64, textAlign: 'center', flexShrink: 0 }} />
          )}
        </div>
        {m.durType === 'other' && (
          <input className="b-input" value={m.durOther} onChange={e => set('durOther', e.target.value)} placeholder={t('dur_other_ph')} style={{ marginTop: 8 }} />
        )}
      </div>
    </div>
  );
}

function AddPrescriptionSheet({ onClose, onAdd }) {
  const { t, lang } = useApp();
  const [step, setStep]   = useState('form'); // form | done
  const [title, setTitle] = useState('');
  const [photos, setPhotos] = useState([]);
  const [url, setUrl]     = useState('');
  const [meds, setMeds]   = useState([{ name: '', dose: '', desc: '', freqType: 'once', freqN: '2', freqUnit: 'hours', freqOther: '', durType: 'ongoing', durN: '', durOther: '' }]);
  const [doctorName, setDoctorName] = useState('');
  const [rxDate, setRxDate]     = useState(nowISO());
  const [rxTime, setRxTime]     = useState(() => new Date().toTimeString().slice(0, 5));
  const [rxExpiry, setRxExpiry] = useState('');
  const fileRef = useRef(null);
  const metaProps = { doctorName, setDoctorName, rxDate, setRxDate, rxTime, setRxTime, rxExpiry, setRxExpiry };

  const setMed = (i, key, val) => setMeds(prev => prev.map((m, idx) => idx === i ? { ...m, [key]: val } : m));
  const addMedRow = () => setMeds(prev => [...prev, { name: '', dose: '', desc: '', freqType: 'once', freqN: '2', freqUnit: 'hours', freqOther: '', durType: 'ongoing', durN: '', durOther: '' }]);
  const removeMedRow = (i) => setMeds(prev => prev.filter((_, idx) => idx !== i));

  const hasFile = !!(photos.length || url.trim());
  const hasMeds = meds.some(m => m.name.trim());
  const ready = hasFile || hasMeds;

  const save = () => {
    const name = title.trim() || (lang === 'ar' ? 'روشتة' : 'Prescription');
    onAdd({
      id: 'rxself' + Date.now(), source: 'self', status: 'active',
      title: { en: name, ar: name },
      doctorName: doctorName.trim() || null,
      date: fmtRxDate(rxDate), time: rxTime, validUntil: rxExpiry ? fmtRxDate(rxExpiry) : null,
      files: photos.length ? photos.map(p => ({ ...p, name: p.name || name })) : (url.trim() ? [{ url: url.trim(), kind: /\.pdf($|\?)/i.test(url.trim()) ? 'pdf' : 'link', name: url.trim() }] : null),
      file: photos[0] || (url.trim() ? { url: url.trim(), kind: /\.pdf($|\?)/i.test(url.trim()) ? 'pdf' : 'link', name: url.trim() } : null),
      meds: hasMeds ? meds.filter(m => m.name.trim()).map(m => {
        const freqDisplay =
          m.freqType === 'once'    ? t('freq_once') :
          m.freqType === 'per_day' ? `${m.freqN || 1}\u00d7/${lang === 'ar' ? '\u064a\u0648\u0645' : 'day'}` :
          m.freqType === 'every_x' ? `${t('freq_every')} ${m.freqN || 1} ${t('unit_' + m.freqUnit)}` :
          (m.freqOther.trim() || t('freq_other'));
        const durUnitLabel = { days: 'unit_days', weeks: 'unit_weeks', months: 'unit_months' }[m.durType];
        const durDisplay =
          m.durType === 'until_empty' ? t('dur_until_empty') :
          m.durType === 'ongoing'     ? null :
          m.durType === 'other'       ? (m.durOther.trim() || null) :
          (m.durN ? `${m.durN} ${t(durUnitLabel)}` : null);
        const doseStr = [m.dose.trim(), freqDisplay, durDisplay].filter(Boolean).join(' \u00b7 ') || '\u2014';
        return {
          name: { en: m.name, ar: m.name }, dose: { en: doseStr, ar: doseStr },
          desc: m.desc.trim() ? { en: m.desc, ar: m.desc } : null,
          frequency: { type: m.freqType, n: m.freqN, unit: m.freqUnit, other: m.freqOther },
          duration: { type: m.durType, n: m.durN, other: m.durOther },
        };
      }) : null,
    });
    setStep('done'); setTimeout(onClose, 1400);
  };

  return (
    <>
      <style>{`@keyframes rxSlideUp{from{transform:translateY(110%)}to{transform:none}}`}</style>
      <div className="app-scrim" onClick={onClose} style={{ position: 'absolute', inset: 0, zIndex: 40, background: 'rgba(20,32,43,0.36)', backdropFilter: 'blur(2px)' }} />
      <div className="app-sheet app-sheet--lg" style={{
        position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 41,
        background: '#fff', borderRadius: '20px 20px 0 0',
        maxHeight: '90%', display: 'flex', flexDirection: 'column',
        animation: 'rxSlideUp 0.3s cubic-bezier(0.16,1,0.3,1) both',
      }}>
        <div style={{ padding: '10px 16px 0', flexShrink: 0 }}>
          {step === 'form' && <div className="sheet-grab" />}
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, paddingBottom: 10, borderBottom: '1px solid var(--balsm-ink-100)' }}>
            <div style={{ flex: 1, fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-lg)', color: 'var(--fg1)' }}>
              {step === 'done' ? '' : t('rx_add')}
            </div>
            <button className="round-btn ghost" onClick={onClose}><Icon name="x" size={18} /></button>
          </div>
        </div>

        <div style={{ flex: 1, overflowY: 'auto', padding: '14px 14px 38px' }}>
          {step === 'form' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
              <div>
                <label style={{ fontSize: 'var(--pt-sm)', fontWeight: 600, color: 'var(--fg2)', display: 'flex', alignItems: 'center', gap: 7, marginBottom: 10 }}>
                  <Icon name="file-text" size={15} style={{ color: 'var(--app-accent)' }} />{lang === 'ar' ? 'التفاصيل' : 'Details'}
                </label>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                  <div className="field">
                    <label>{t('rx_name')}</label>
                    <input className="b-input" value={title} onChange={e => setTitle(e.target.value)} placeholder={t('rx_name_ph')} />
                  </div>
                  <RxMetaFields {...metaProps} />
                </div>
              </div>

              <div>
                <label style={{ fontSize: 'var(--pt-sm)', fontWeight: 600, color: 'var(--fg2)', display: 'flex', alignItems: 'center', gap: 7, marginBottom: 10 }}>
                  <Icon name="upload-cloud" size={15} style={{ color: 'var(--app-accent)' }} />{t('rx_upload')}
                </label>
                <AttachmentInput inputRef={fileRef} onPick={picked => setPhotos(p => [...p, ...picked])} />
                {photos.length ? (
                  <AttachmentGallery atts={photos} height={180}
                    onRemove={i => setPhotos(p => p.filter((_, n) => n !== i))}
                    onAdd={() => fileRef.current?.click()} />
                ) : (
                  <div className="card card-pad" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12, background: 'var(--balsm-cream-50)', border: '1.5px dashed var(--balsm-border-strong)' }}>
                    <Icon name="upload-cloud" size={28} style={{ color: 'var(--fg3)' }} />
                    <div style={{ display: 'flex', gap: 10 }}>
                      <button className="b-btn b-btn-md b-btn-soft" style={{ height: 42, fontSize: 'var(--pt-sm)' }} onClick={() => fileRef.current?.click()}><Icon name="camera" size={16} />{t('rx_take_photo')}</button>
                      <button className="b-btn b-btn-md b-btn-secondary" style={{ height: 42, fontSize: 'var(--pt-sm)' }} onClick={() => fileRef.current?.click()}><Icon name="folder" size={16} />{t('rx_from_files')}</button>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10, width: '100%', margin: '4px 0' }}>
                      <div style={{ flex: 1, height: 1, background: 'var(--balsm-ink-100)' }} />
                      <span style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg4)', fontWeight: 600 }}>{t('rx_or_paste_url')}</span>
                      <div style={{ flex: 1, height: 1, background: 'var(--balsm-ink-100)' }} />
                    </div>
                    <input className="b-input" dir="ltr" value={url} onChange={e => setUrl(e.target.value)} placeholder={t('rx_url_ph')} style={{ width: '100%' }} />
                  </div>
                )}
              </div>

              <div>
                <label style={{ fontSize: 'var(--pt-sm)', fontWeight: 600, color: 'var(--fg2)', display: 'flex', alignItems: 'center', gap: 7, marginBottom: 10 }}>
                  <Icon name="pill" size={15} style={{ color: 'var(--app-accent)' }} />{t('rx_manual')}
                </label>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {meds.map((m, i) => (
                    <MedRow key={i} m={m} i={i} setMed={setMed} onRemove={() => removeMedRow(i)} canRemove={meds.length > 1} />
                  ))}
                </div>
                <button className="b-btn b-btn-md b-btn-soft" style={{ marginTop: 10 }} onClick={addMedRow}><Icon name="plus" size={16} />{t('rx_add_med')}</button>
              </div>

              <button className={cx('b-btn b-btn-lg b-btn-primary b-btn--full', !ready && 'is-disabled')} onClick={save}>{t('rx_add')}</button>
            </div>
          )}

          {step === 'done' && (
            <div style={{ textAlign: 'center', padding: '20px 0 12px' }}>
              <div className="confirm-mark" style={{ width: 72, height: 72, margin: '0 auto 14px' }}><Icon name="check" size={36} /></div>
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', color: 'var(--fg1)' }}>{t('rx_added')}</div>
            </div>
          )}
        </div>
      </div>
    </>
  );
}

function PrescriptionsScreen({ onBack }) {
  const { t, lang } = useApp();
  const [selected, setSelected] = useState(null);
  const [selfRx, setSelfRx]     = useState([]);
  const [addOpen, setAddOpen]   = useState(false);

  if (selected) {
    return <PrescriptionDetail rx={selected} onBack={() => setSelected(null)}
      onDelete={() => { setSelfRx(prev => prev.filter(r => r.id !== selected.id)); setSelected(null); }} />;
  }

  const active  = PRESCRIPTIONS.filter(r => r.status === 'active');
  const expired = PRESCRIPTIONS.filter(r => r.status === 'expired');

  const RxCard = ({ rx, dim }) => {
    const { Card } = window.BalsmDesignSystem_51cdbf || {};
    if (!Card) return null;
    const isSelf = rx.source === 'self';
    const doc = isSelf ? null : DOCTORS.find(d => d.id === rx.doctorId);
    const isActive = rx.status === 'active';
    const medCount = rx.meds ? rx.meds.length : 0;
    return (
      <Card interactive size="sm" onClick={() => setSelected(rx)} style={{ opacity: dim ? 0.6 : 1, filter: dim ? 'saturate(0.6)' : 'none' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          {doc ? <DoctorAvatar doctor={doc} size={46} /> : isSelf && (
            <div style={{ width: 46, height: 46, borderRadius: '50%', background: 'var(--petal-blue-50)', color: 'var(--petal-blue)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <Icon name={rx.file ? 'file-text' : 'pill'} size={21} />
            </div>
          )}
          <div className="grow" style={{ minWidth: 0 }}>
            <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {isSelf ? rx.title[lang] : doc?.name[lang]}
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 'var(--pt-sm)', color: 'var(--fg3)', marginTop: 3, overflow: 'hidden', whiteSpace: 'nowrap', textOverflow: 'ellipsis' }}>
              {!isSelf && doc?.specialty && <span style={{ flexShrink: 0 }}>{doc.specialty[lang]}</span>}
              {!isSelf && doc?.specialty && <span style={{ flexShrink: 0, opacity: 0.5 }}>&middot;</span>}
              <span style={{ overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {medCount > 0 ? `${medCount} ${medCount === 1 ? 'medication' : 'medications'} \u00b7 ` : ''}{rx.date[lang]}
              </span>
            </div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 6, flexShrink: 0 }}>
            {isSelf
              ? <span className="b-badge b-badge--neutral">{t('rx_self_added')}</span>
              : <span className={cx('b-badge', isActive ? 'b-badge--success' : 'b-badge--neutral')}>
                  <span className="b-badge__dot" />{t(isActive ? 'rx_active' : 'rx_expired')}
                </span>}
          </div>
          <Icon name="chevron-right" size={17} style={{ color: 'var(--fg4)', flexShrink: 0 }} />
        </div>
      </Card>
    );
  };

  return (
    <div className="screen fade-in">
      <div className="pad-top" />
      <div className="appbar">
        <button className="round-btn" onClick={onBack} aria-label="Back"><Icon name="arrow-left" /></button>
        <h1 style={{ flex: 1, margin: 0, fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', letterSpacing: '-0.01em', color: 'var(--fg1)' }}>
          {t('prescriptions')}
        </h1>
        <button className="round-btn" onClick={() => setAddOpen(true)} aria-label={t('rx_add')}><Icon name="plus" size={19} /></button>
      </div>

      <div className="screen-scroll">
        {active.length > 0 && <>
          <div className="row-head"><h2>{t('rx_active')}</h2></div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '0 20px' }}>
            {active.map(rx => <RxCard key={rx.id} rx={rx} dim={false} />)}
          </div>
        </>}

        {selfRx.length > 0 && <>
          <div className="row-head"><h2>{t('rx_my_prescriptions')}</h2></div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '0 20px' }}>
            {selfRx.map(rx => <RxCard key={rx.id} rx={rx} dim={false} />)}
          </div>
        </>}

        {expired.length > 0 && <>
          <div className="row-head"><h2>{t('rx_expired')}</h2></div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '0 20px' }}>
            {expired.map(rx => <RxCard key={rx.id} rx={rx} dim={true} />)}
          </div>
        </>}

        <div style={{ height: 28 }} />
      </div>

      {addOpen && <AddPrescriptionSheet onClose={() => setAddOpen(false)} onAdd={(rx) => setSelfRx(prev => [rx, ...prev])} />}
    </div>
  );
}

Object.assign(window, { PrescriptionsScreen, PrescriptionDetail, QRCode, DoctorAvatar, AddPrescriptionSheet });
