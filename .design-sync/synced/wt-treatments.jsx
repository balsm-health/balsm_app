/* wt-treatments.jsx — three visual skins over the shared WalkthroughShell.
   A · Petal      — calm, brand-forward, centered, five-petal aura.
   B · Watercolor — immersive full-bleed brand backdrop, marketing-hero.
   C · Editorial  — structured white, progress bar, left-aligned, product hints.
   Each exposes WT_SKINS[key] consumed by wt-compare.jsx.

   Redesign: fewer, more narrative slides (see wt-core.jsx) + a real,
   tappable "day with Balsm" demo standing in for the old static product-hint
   art on the middle slide, plus a light parallax response to swipe drag. */

/* Shared glyph — the petal mark for the vision slide, else a Lucide icon. */
function WtGlyph({ slide, size = 46, markSize = 96, color = 'var(--app-accent)' }) {
  if (slide.icon === 'petal') return <PetalMark style={{ width: markSize, height: markSize }} />;
  return <Icon name={slide.icon} size={size} stroke={1.85} style={{ color }} />;
}

/* Soft multi-radial petal aura (echoes the splash aura), tinted to one petal. */
function WtAura({ petal }) {
  const c = petal.soft;
  return (
    <span className="wt-aura" aria-hidden="true" style={{
      background:
        `radial-gradient(closest-side, ${c}0.34), transparent 72%) 14% 8% / 62% 62% no-repeat,` +
        `radial-gradient(closest-side, ${c}0.26), transparent 72%) 86% 20% / 60% 60% no-repeat,` +
        `radial-gradient(closest-side, ${c}0.22), transparent 72%) 84% 88% / 58% 58% no-repeat,` +
        `radial-gradient(closest-side, ${c}0.28), transparent 72%) 18% 90% / 62% 62% no-repeat`,
    }} />
  );
}

/* ── Interactive "day with Balsm" demo — shared across all 3 treatments ──
   Tabs auto-advance until the visitor taps one, then it's fully manual.
   This is the slide's "product hint": a small, real, tappable preview
   instead of a static illustration. */
const WT_DAY_TABS = [
  { key: 'record',  icon: 'file-text', label: { en: 'Record',   ar: 'السجلّ' } },
  { key: 'checkin', icon: 'activity',  label: { en: 'Check-in', ar: 'التسجيل' } },
  { key: 'nearby',  icon: 'map-pin',   label: { en: 'Nearby',   ar: 'قريب منك' } },
];
const WT_DAY_RECORDS = [
  { icon: 'flask-conical', t: { en: 'CBC blood panel',       ar: 'تحليل دم شامل' }, d: { en: '2 days ago',  ar: 'قبل يومين' } },
  { icon: 'file-text',     t: { en: 'Cardiology referral',   ar: 'تحويل قلب' },     d: { en: '2 weeks ago', ar: 'قبل أسبوعين' } },
];
const WT_DAY_MOODS = [
  { icon: 'frown', label: { en: 'Low',   ar: 'منخفض' } },
  { icon: 'meh',   label: { en: 'Okay',  ar: 'عادي' } },
  { icon: 'smile', label: { en: 'Good',  ar: 'جيد' } },
  { icon: 'laugh', label: { en: 'Great', ar: 'ممتاز' } },
];
const WT_DAY_PINS = [
  { l: 20, t: 66, name: { en: 'Zahran Pharmacy', ar: 'صيدلية زهران' } },
  { l: 56, t: 30, name: { en: 'Nour Clinic',     ar: 'عيادة نور' } },
  { l: 82, t: 62, name: { en: 'City Lab',        ar: 'معمل المدينة' } },
];

function WtDayDemo({ lang }) {
  const [tab, setTab] = useState(0);
  const [mood, setMood] = useState(2);
  const [pin, setPin] = useState(0);
  const auto = useRef(true);

  useEffect(() => {
    const id = setInterval(() => { if (auto.current) setTab(t => (t + 1) % WT_DAY_TABS.length); }, 3400);
    return () => clearInterval(id);
  }, []);
  const pick = (i) => { auto.current = false; setTab(i); };

  return (
    <div className="wt-demo" data-no-swipe onPointerDown={(e) => e.stopPropagation()}>
      <div className="wt-demo-tabs" role="tablist">
        {WT_DAY_TABS.map((d, i) => (
          <button key={d.key} className={cx('wt-demo-tab', i === tab && 'on')} role="tab" aria-selected={i === tab}
            onClick={() => pick(i)}>
            <Icon name={d.icon} size={14} />{d.label[lang]}
          </button>
        ))}
      </div>
      <div className="wt-demo-panel" key={tab}>
        {tab === 0 && (
          <div className="wt-demo-list">
            {WT_DAY_RECORDS.map((r, k) => (
              <div className="wt-demo-row" key={k}>
                <span className="wt-demo-ico"><Icon name={r.icon} size={15} /></span>
                <span className="grow">
                  <span className="wt-demo-rt">{r.t[lang]}</span>
                  <span className="wt-demo-rd">{r.d[lang]}</span>
                </span>
              </div>
            ))}
          </div>
        )}
        {tab === 1 && (
          <div className="wt-demo-checkin">
            <svg className="wt-demo-chart" viewBox="0 0 200 60" width="100%" height="52" preserveAspectRatio="none">
              <polyline points="6,46 42,36 78,40 114,20 150,26 194,10" />
            </svg>
            <div className="wt-demo-moods">
              {WT_DAY_MOODS.map((m, i) => (
                <button key={i} className={cx('wt-demo-mood', i === mood && 'on')} aria-label={m.label[lang]}
                  onClick={() => setMood(i)}>
                  <Icon name={m.icon} size={18} />
                </button>
              ))}
            </div>
          </div>
        )}
        {tab === 2 && (
          <div className="wt-demo-map">
            {WT_DAY_PINS.map((p, i) => (
              <button key={i} className={cx('wt-demo-pin', i === pin && 'on')}
                style={{ left: `${p.l}%`, top: `${p.t}%` }} onClick={() => setPin(i)} aria-label={p.name[lang]}>
                <Icon name="map-pin" size={i === pin ? 20 : 16} />
              </button>
            ))}
            <div className="wt-demo-pin-label">{WT_DAY_PINS[pin].name[lang]}</div>
          </div>
        )}
      </div>
    </div>
  );
}

/* ── A · Petal ────────────────────────────────────────────────── */
const WT_SKIN_PETAL = {
  key: 'petal',
  tone: 'light',
  base: () => ({ background: 'var(--balsm-cream-50)' }),
  renderSlide: (slide, i, lang, active, dx) => {
    const px = { transform: `translateX(${(dx || 0) * 0.05}px)`, transition: dx ? 'none' : 'transform 0.3s var(--ease-out)' };
    return (
      <div className="wt-petal">
        {slide.demo ? (
          <div className="wt-petal-demo-wrap" style={px}><WtDayDemo lang={lang} /></div>
        ) : (
          <div className="wt-petal-stage" style={px}>
            <WtAura petal={WT_PETALS[slide.petal]} />
            <div className="wt-petal-tile">
              <WtGlyph slide={slide} size={50} markSize={104} color="var(--app-accent)" />
            </div>
          </div>
        )}
        <div className="wt-petal-copy">
          <div className="eyebrow-l wt-eyebrow">{slide.eyebrow[lang]}</div>
          <h2 className="wt-title">{slide.title[lang]}</h2>
          <p className="wt-body">{slide.body[lang]}</p>
        </div>
      </div>
    );
  },
};

/* ── B · Watercolor ───────────────────────────────────────────── */
const WT_SKIN_WATER = {
  key: 'water',
  tone: 'dark',
  showLogo: true,
  logoDark: true,
  dot: { color: '#fff', dim: 'rgba(255,255,255,0.36)' },
  base: () => ({ background: '#14201F' }),
  renderSlide: (slide, i, lang, active, dx) => {
    const p = WT_PETALS[slide.petal];
    return (
      <div className="wt-water">
        <div className="wt-water-parallax" style={{ transform: `translateX(${(dx || 0) * 0.03}px)`, transition: dx ? 'none' : 'transform 0.3s var(--ease-out)' }}>
          <div className="wt-water-bg" style={{ backgroundImage: `url(${window.__resources ? window.__resources['balsm-bg'] : 'assets/balsm-background.png?v=7'})` }} />
        </div>
        <div className="wt-water-scrim" style={{
          background:
            `linear-gradient(180deg, ${p.soft}0.22) 0%, ${p.soft}0.30) 30%, ` +
            `${p.soft}0.40) 58%, rgba(15,20,20,0.82) 100%)`,
        }} />
        {slide.demo && <div className="wt-water-demo-wrap"><WtDayDemo lang={lang} /></div>}
        <div className="wt-water-copy">
          <div className="wt-water-eyebrow">{slide.eyebrow[lang]}</div>
          <h2 className="wt-water-title">{slide.title[lang]}</h2>
          <p className="wt-water-body">{slide.body[lang]}</p>
        </div>
      </div>
    );
  },
  renderNext: ({ next, label, lang, petal }) => (
    <button className="b-btn b-btn-lg b-btn--full wt-next-white" onClick={next}>
      <span style={{ color: petal.d, fontWeight: 700 }}>{label}</span>
      <Icon name="arrow-right" size={19} style={{ color: petal.main, transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
    </button>
  ),
};

/* ── C · Editorial ────────────────────────────────────────────── */
/* Bespoke hero art for the bookend slides; the middle slide gets the demo. */
function WtEditorialArt({ slide }) {
  const p = WT_PETALS[slide.petal];
  if (slide.id === 'vision') {
    return (
      <div className="wt-edit-mock">
        <WtAura petal={p} />
        <PetalMark style={{ width: 148, height: 148, position: 'relative', zIndex: 1 }} />
      </div>
    );
  }
  return (
    <div className="wt-edit-mock">
      <WtAura petal={p} />
      <div className="wt-shield-ring" style={{ borderColor: p.main }} />
      <Icon name="shield-check" size={72} style={{ color: 'var(--app-accent)', position: 'relative', zIndex: 1 }} />
    </div>
  );
}

const WT_SKIN_EDIT = {
  key: 'edit',
  tone: 'light',
  hideDots: true,
  base: () => ({ background: '#fff' }),
  renderTop: ({ index, total, lang, onSkip, skipColor }) => (
    <React.Fragment>
      <div className="wt-edit-prog" aria-hidden="true">
        {Array.from({ length: total }).map((_, i) => (
          <span key={i} className={cx('wt-seg', i <= index && 'on')} />
        ))}
      </div>
      <button className="wt-skip" onClick={onSkip} style={{ color: skipColor, marginInlineStart: 14 }}>
        {wtx('skip', lang)}
      </button>
    </React.Fragment>
  ),
  renderSlide: (slide, i, lang, active, dx) => (
    <div className="wt-edit">
      <div className="wt-edit-hero" style={{ transform: `translateX(${(dx || 0) * 0.04}px) rotate(${(dx || 0) * 0.01}deg)`, transition: dx ? 'none' : 'transform 0.3s var(--ease-out)' }}>
        {slide.demo ? <WtDayDemo lang={lang} /> : <WtEditorialArt slide={slide} />}
      </div>
      <div className="wt-edit-copy">
        <div className="eyebrow-l wt-eyebrow">{slide.eyebrow[lang]}</div>
        <h2 className="wt-edit-title">{slide.title[lang]}</h2>
        <p className="wt-body">{slide.body[lang]}</p>
      </div>
    </div>
  ),
  renderNext: ({ isLast, next, label, lang, index, total }) => (
    <div className="wt-edit-foot">
      <WtCounter i={index} total={total} style={{ color: 'var(--fg3)', fontSize: 'var(--pt-sm)', fontWeight: 600 }} />
      <button className="b-btn b-btn-md b-btn-primary" onClick={next}
        style={{ height: 52, padding: isLast ? '0 28px' : '0 22px', borderRadius: 'var(--radius-lg)' }}>
        {label}
        <Icon name="arrow-right" size={18} style={{ transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
      </button>
    </div>
  ),
};

const WT_SKINS = { petal: WT_SKIN_PETAL, water: WT_SKIN_WATER, edit: WT_SKIN_EDIT };

const WT_SKIN_META = [
  { key: 'petal', name: { en: 'Petal',      ar: 'البتلة' },   tag: { en: 'Calm · interactive',       ar: 'هادئ · تفاعلي' } },
  { key: 'water', name: { en: 'Watercolor', ar: 'الألوان المائية' }, tag: { en: 'Immersive · interactive', ar: 'غامر · تفاعلي' } },
  { key: 'edit',  name: { en: 'Editorial',  ar: 'تحريري' },   tag: { en: 'Structured · interactive', ar: 'منظّم · تفاعلي' } },
];

Object.assign(window, { WtGlyph, WtAura, WtDayDemo, WtEditorialArt, WT_SKINS, WT_SKIN_META });
