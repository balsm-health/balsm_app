/* appointments.jsx — Appointments screen, read-only for MVP */

const { Avatar, Table } = window.BalsmDesignSystem_51cdbf;

/* petal CSS-var → DS Avatar tone (doctors/family are already assigned petal colors) */
const PETAL_TONE = {
  'var(--petal-aqua)': 'aqua', 'var(--petal-emerald)': 'emerald', 'var(--petal-blue)': 'blue',
  'var(--petal-mint)': 'mint', 'var(--petal-mint-600)': 'mint', 'var(--petal-violet)': 'violet',
};
function DoctorAvatar({ doctor, size = 44 }) {
  const dsSize = size >= 56 ? 'xl' : size >= 42 ? 'lg' : size >= 30 ? 'md' : size >= 24 ? 'sm' : 'xs';
  return <Avatar name={doctor.name.en} initials={doctor.initials} tone={PETAL_TONE[doctor.color]} size={dsSize} />;
}

function AppointmentsScreen({ onBack }) {
  const { t, lang, setTab } = useApp();
  const handleBack = onBack || (() => setTab('home'));

  const upcoming = APPOINTMENTS.filter(a => a.status === 'upcoming');
  const past     = APPOINTMENTS.filter(a => a.status === 'past');

  return (
    <div className="screen-scroll fade-in">
      <div className="pad-top" />
      <div className="appbar">
        <button className="round-btn" onClick={handleBack} aria-label="Back">
          <Icon name="arrow-left" style={{ transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
        </button>
        <h1 style={{ flex: 1, margin: 0, fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', letterSpacing: '-0.01em', color: 'var(--fg1)' }}>
          {t('appts')}
        </h1>
      </div>

      {/* Upcoming hero */}
      {upcoming.length > 0 ? upcoming.map(appt => {
        const doc = DOCTORS.find(d => d.id === appt.doctorId);
        return (
          <div key={appt.id} style={{
            margin: '0 20px', padding: 20, borderRadius: 'var(--radius-xl)',
            background: 'var(--app-accent)', color: '#fff',
            boxShadow: 'var(--app-accent-shadow)', position: 'relative', overflow: 'hidden',
          }}>
            <img src={window.__resources ? window.__resources['icon-mono-white'] : 'assets/icon-mono-white.svg?v=7'} alt="" style={{
              position: 'absolute', right: -20, top: -20, width: 120, opacity: 0.12, pointerEvents: 'none',
              filter: 'brightness(0) invert(1)',
            }} />
            <div style={{ fontSize: 'var(--pt-xs)', fontWeight: 700, opacity: 0.85, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 14 }}>
              {t('upcoming_appt')}
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 16 }}>
              {doc && <DoctorAvatar doctor={doc} size={52} />}
              <div>
                <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-lg)' }}>{doc?.name[lang]}</div>
                <div style={{ fontSize: 'var(--pt-sm)', opacity: 0.85, marginTop: 2 }}>{doc?.specialty[lang]}</div>
              </div>
            </div>
            <div style={{ display: 'flex', gap: 20, marginBottom: 10, fontSize: 'var(--pt-sm)', opacity: 0.92 }}>
              <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <Icon name="calendar" size={14} />{appt.date[lang]}
              </span>
              <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <Icon name="clock" size={14} />{appt.time}
              </span>
            </div>
            <div style={{ fontSize: 'var(--pt-xs)', opacity: 0.78, marginBottom: 18, display: 'flex', alignItems: 'center', gap: 6 }}>
              <Icon name="map-pin" size={13} />{appt.location[lang]}
            </div>
            <div style={{ display: 'flex', gap: 10 }}>
              <button className="b-btn b-btn-md" style={{ height: 42, padding: '0 16px', background: 'rgba(255,255,255,0.18)', color: '#fff', borderRadius: 'var(--radius-md)', border: '1px solid rgba(255,255,255,0.28)', fontSize: 'var(--pt-sm)' }}>
                <Icon name="calendar-plus" size={16} />{t('add_calendar')}
              </button>
            </div>
          </div>
        );
      }) : (
        <div className="card" style={{ margin: '0 20px', padding: '32px 24px', textAlign: 'center' }}>
          <Icon name="calendar-heart" size={36} style={{ color: 'var(--fg4)', display: 'block', margin: '0 auto 14px' }} />
          <div style={{ fontWeight: 600, fontSize: 'var(--pt-md)', color: 'var(--fg2)', marginBottom: 8 }}>{t('no_appts')}</div>
          <p className="meta" style={{ margin: 0, lineHeight: 1.5 }}>{t('book_via_doctor')}</p>
        </div>
      )}

      {/* Past visits */}
      {past.length > 0 && <>
        <div className="row-head"><h2>{t('past_appts')}</h2></div>
        <div style={{ margin: '0 20px' }}>
          <Table
            columns={[
              { key: 'doctor', label: t('past_appts'), render: (appt) => {
                const doc = DOCTORS.find(d => d.id === appt.doctorId);
                return (
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    {doc && <DoctorAvatar doctor={doc} size={36} />}
                    <span style={{ fontWeight: 600, color: 'var(--fg1)' }}>{doc?.name[lang]}</span>
                  </div>
                );
              } },
              { key: 'when', label: t('upcoming_appt'), priority: 'low', render: (appt) => `${appt.date[lang]} · ${appt.time}` },
              { key: 'type', label: '', priority: 'med', render: (appt) => (
                <span className="b-badge b-badge--neutral" style={{ fontSize: 'var(--pt-2xs)' }}>
                  {t(appt.type === 'follow-up' ? 'follow_up' : 'check_up')}
                </span>
              ) },
            ]}
            rows={past}
            rowKey="id"
            zebra
          />
        </div>
      </>}

      <div style={{ height: 24 }} />
    </div>
  );
}

Object.assign(window, { AppointmentsScreen, DoctorAvatar });
