/* feedback.jsx — in-app rating + feedback sheet.
   Five-petal rating (the brand's "stars"), optional topic chips + note.
   Submissions are stored on-device and reviewed inside Balsm — no app store. */

const FB_TOPICS = [
  { id: 'general', en: 'General',         ar: 'عام' },
  { id: 'ease',    en: 'Ease of use',     ar: 'سهولة الاستخدام' },
  { id: 'records', en: 'Records',         ar: 'السجلات' },
  { id: 'meds',    en: 'Medications',     ar: 'الأدوية' },
  { id: 'arabic',  en: 'Arabic & language', ar: 'العربية واللغة' },
];

const FB_KEY = 'balsm_app_feedback';
const fbHistory = () => { try { return JSON.parse(localStorage.getItem(FB_KEY)) || []; } catch { return []; } };
const fbDate = (ts) => { const d = new Date(ts); const p = (n) => String(n).padStart(2, '0'); return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()}`; };

/* One tappable petal mark — full colour when lit, ink when not */
function RatePetal({ lit, onPick, label }) {
  return (
    <button type="button" aria-label={label} onClick={onPick}
      className={cx('fb-petal', !lit && 'fb-petal-off')}>
      <PetalMark style={{ width: '100%', height: '100%', display: 'block' }} />
    </button>
  );
}

function FeedbackSheet({ onClose }) {
  const { t, lang } = useApp();
  const last = useMemo(() => fbHistory().slice(-1)[0] || null, []);
  const [rating, setRating] = useState(last?.rating || 0);
  const [topics, setTopics] = useState([]);
  const [note, setNote]     = useState('');
  const [sent, setSent]     = useState(false);

  const toggleTopic = (id) => setTopics(ts => ts.includes(id) ? ts.filter(x => x !== id) : [...ts, id]);
  const submit = () => {
    try { localStorage.setItem(FB_KEY, JSON.stringify([...fbHistory(), { rating, topics, note: note.trim(), at: Date.now() }])); } catch {}
    setSent(true);
  };

  return (
    <SettingsSheet title={t('fb_title')} onClose={onClose}>
      <style>{`
        .fb-petal { width: 46px; height: 46px; padding: 2px; border: none; background: none; cursor: pointer;
                    transition: transform var(--dur-base) var(--ease-out); }
        .fb-petal:active { transform: scale(0.94); }
        .fb-petal-off .petal { fill: var(--balsm-ink-200); transition: fill var(--dur-base) var(--ease-out); }
        .fb-petal .petal { transition: fill var(--dur-base) var(--ease-out); }
      `}</style>

      {sent ? (
        <div className="fade-in" style={{ textAlign: 'center', padding: '30px 8px 6px' }}>
          <PetalMark style={{ width: 58, height: 58, display: 'block', margin: '0 auto 18px' }} />
          <div style={{ fontFamily: lang === 'ar' ? 'var(--font-arabic)' : 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', color: 'var(--fg1)' }}>{t('fb_thanks')}</div>
          <p className="meta" style={{ margin: '10px auto 26px', maxWidth: 260, lineHeight: 1.55 }}>{t('fb_thanks_sub')}</p>
          <button className="b-btn b-btn-md b-btn-primary b-btn--full" onClick={onClose}>{t('fb_done')}</button>
        </div>
      ) : (
        <>
          {/* Rating */}
          <div style={{ textAlign: 'center', padding: '14px 0 4px' }}>
            <div style={{ display: 'flex', justifyContent: 'center', gap: 8 }} aria-label={t('fb_rate_q')}>
              {[1, 2, 3, 4, 5].map(n => (
                <RatePetal key={n} lit={n <= rating} onPick={() => setRating(n)} label={`${n}/5`} />
              ))}
            </div>
            <div style={{ marginTop: 8, minHeight: 20, fontSize: 'var(--pt-sm)', fontWeight: 700, color: rating ? 'var(--fg2)' : 'var(--fg3)' }}>
              {rating ? t(`fb_r${rating}`) : t('fb_rate_q')}
            </div>
            {last && (
              <div style={{ marginTop: 3, fontSize: 'var(--pt-2xs)', color: 'var(--fg3)' }}>
                {t('fb_last')} <span className="num">{fbDate(last.at)}</span>
              </div>
            )}
          </div>

          {/* Topics */}
          <label className="body-sm" style={{ fontWeight: 600, color: 'var(--fg2)', display: 'block', margin: '20px 0 10px' }}>{t('fb_about')}</label>
          <div className="chip-wrap">
            {FB_TOPICS.map(tp => (
              <button key={tp.id} type="button" className={cx('chip', topics.includes(tp.id) && 'sel')} onClick={() => toggleTopic(tp.id)}>
                {tp[lang] ?? tp.en}
              </button>
            ))}
          </div>

          {/* Note */}
          <label className="body-sm" style={{ fontWeight: 600, color: 'var(--fg2)', display: 'block', margin: '20px 0 10px' }}>
            {t('fb_note_lbl')} <span style={{ fontWeight: 400, color: 'var(--fg3)' }}>· {t('fb_optional')}</span>
          </label>
          <textarea className="textarea" placeholder={t('fb_ph')} value={note} onChange={e => setNote(e.target.value)} />

          {/* Where it goes */}
          <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start', margin: '14px 0 18px', color: 'var(--fg3)' }}>
            <Icon name="shield-check" size={16} style={{ flexShrink: 0, marginTop: 1 }} />
            <span style={{ fontSize: 'var(--pt-xs)', lineHeight: 1.5 }}>{t('fb_privacy')}</span>
          </div>

          <button className="b-btn b-btn-md b-btn-primary b-btn--full" disabled={!rating} onClick={submit}>
            <Icon name="send" size={18} />{t('fb_send')}
          </button>
        </>
      )}
    </SettingsSheet>
  );
}

Object.assign(window, { FeedbackSheet });
