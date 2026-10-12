/* wt-core.jsx — Walkthrough content + shared engine (state, swipe, chrome, end card).
   Skins live in wt-treatments.jsx. Comparison harness in wt-compare.jsx.
   Reuses Balsm tokens/classes from colors_and_type.css + app.css. */

/* ── The five petals — one per slide (five petals, five hues) ── */
const WT_PETALS = {
  emerald: { main: '#01C4A2', d: '#019A7F', bg: '#E1F8F1', soft: 'rgba(1,196,162,'  },
  violet:  { main: '#724DD0', d: '#5C3AB0', bg: '#ECE6FA', soft: 'rgba(114,77,208,' },
  mint:    { main: '#3FC366', d: '#2FA552', bg: '#E8F9EE', soft: 'rgba(85,215,127,' },
  blue:    { main: '#1283FF', d: '#0F6BCC', bg: '#E4F0FF', soft: 'rgba(18,131,255,' },
  aqua:    { main: '#02BBB5', d: '#029E99', bg: '#E2F8F6', soft: 'rgba(2,187,181,'  },
};

/* ── Slide content — Balsm product/patient voice, EN + AR ────── */
/* Story-driven: 3 slides, not 5. The middle slide narrates a whole day
   with the app (record → check-in → nearby) through one tappable demo,
   instead of three separate feature slides. */
const WT_SLIDES = [
  {
    id: 'vision', petal: 'emerald', icon: 'petal',
    eyebrow: { en: 'Open · Arab · Trusted',  ar: 'مفتوح · عربي · موثوق' },
    title:   { en: 'Healthcare that finally belongs to us.',
               ar: 'رعاية صحية تخصّنا أخيراً.' },
    body:    { en: 'Balsm is the first and largest open-source health platform built in Egypt and the Arab world — Arabic-first, and owned by the people who use it.',
               ar: 'بلسم أول وأكبر منصة صحية مفتوحة المصدر بُنيت في مصر والعالم العربي — بالعربية أولاً، ويملكها من يستخدمها.' },
  },
  {
    id: 'everyday', petal: 'blue', icon: 'activity', demo: true,
    eyebrow: { en: 'A day with Balsm',  ar: 'يوم مع بلسم' },
    title:   { en: "From this morning's reading to tonight's pharmacy run.",
               ar: 'من قياس هذا الصباح إلى الصيدلية الليلة.' },
    body:    { en: 'One record, one daily check-in, one map of care nearby — try them below, right where they live in the app.',
               ar: 'سجلّ واحد، وتسجيل يومي، وخريطة رعاية واحدة — جرّبها في الأسفل، تماماً كما تظهر في التطبيق.' },
  },
  {
    id: 'data', petal: 'aqua', icon: 'shield-check',
    eyebrow: { en: 'Yours, always',  ar: 'ملكك دائماً' },
    title:   { en: 'Your data stays yours.',
               ar: 'بياناتك تبقى ملكك.' },
    body:    { en: 'Saved on your phone by design, and it works offline. You choose what is shared — and with whom.',
               ar: 'محفوظة على هاتفك بالتصميم، وتعمل دون إنترنت. أنت تختار ما تشاركه — ومع من.' },
  },
];

const WT_STR = {
  skip:     { en: 'Skip',        ar: 'تخطّي' },
  next:     { en: 'Next',        ar: 'التالي' },
  start:    { en: 'Get started', ar: 'ابدأ الآن' },
  end_t:    { en: "You're all set.", ar: 'كل شيء جاهز.' },
  end_b:    { en: 'In the app this hands off to the Welcome screen — sign in and your record is ready.',
             ar: 'في التطبيق ينتقل هذا إلى شاشة الترحيب — سجّل الدخول ويكون سجلّك جاهزاً.' },
  replay:   { en: 'Replay walkthrough', ar: 'إعادة الجولة' },
  handoff:  { en: '→ Welcome', ar: 'الترحيب ←' },
};
const wtx = (key, lang) => (WT_STR[key] && (WT_STR[key][lang] ?? WT_STR[key].en)) ?? key;

/* ── Little mono step counter e.g. 02 / 05 ───────────────────── */
function WtCounter({ i, total, style }) {
  const p = (n) => String(n).padStart(2, '0');
  return (
    <span className="num" style={{ fontFamily: 'var(--font-mono)', letterSpacing: '0.04em', ...style }}>
      {p(i + 1)} <span style={{ opacity: 0.5 }}>/ {p(total)}</span>
    </span>
  );
}

/* ── Tappable pagination dots ─────────────────────────────────── */
function WtDots({ total, index, onGo, color = 'var(--app-accent)', dim }) {
  const inactive = dim || 'var(--balsm-ink-200)';
  return (
    <div className="wt-dots" role="tablist" aria-label="Slides">
      {Array.from({ length: total }).map((_, i) => (
        <button key={i} className={cx('wt-dot', i === index && 'on')} aria-label={`Slide ${i + 1}`}
          aria-selected={i === index} onClick={() => onGo(i)}
          style={{ '--dot': color, '--dot-off': inactive }} />
      ))}
    </div>
  );
}

/* ── Directional swipe (pointer) — RTL-aware, with a rubber-band feel ── */
function useWtSwipe({ dir, onNext, onPrev }) {
  const [dx, setDx] = useState(0);
  const st = useRef({ on: false, x0: 0, dx: 0 });
  const rtl = dir === 'rtl';
  const down = (e) => {
    if (e.target.closest('button, a, [data-no-swipe]')) return;
    st.current = { on: true, x0: e.clientX, dx: 0 };
    try { e.currentTarget.setPointerCapture(e.pointerId); } catch (_) {}
  };
  const move = (e) => {
    if (!st.current.on) return;
    const d = e.clientX - st.current.x0;
    st.current.dx = d;
    setDx(d);
  };
  const up = () => {
    if (!st.current.on) return;
    const d = st.current.dx;
    st.current.on = false;
    setDx(0);
    const TH = 46;
    if (Math.abs(d) < TH) return;
    let forward = d < 0;          // dragged left → forward (LTR)
    if (rtl) forward = !forward;  // mirrored in RTL
    forward ? onNext() : onPrev();
  };
  return { dx, handlers: { onPointerDown: down, onPointerMove: move, onPointerUp: up, onPointerCancel: up } };
}

/* ── Shared shell: state + swipe + chrome + end-card ──────────────
   skin: {
     base(petal): wrapper style,
     tone: 'light' | 'dark',           // default control colours
     showLogo, logoDark,
     dot: { color, dim },
     renderSlide(slide, i, lang, active),
     renderNext(props)                 // custom Next/CTA button
   }                                                                */
function WalkthroughShell({ skin, lang, label }) {
  const total = WT_SLIDES.length;
  const [index, setIndex] = useState(0);
  const [dir, setDir] = useState(1);       // animation direction
  const [done, setDone] = useState(false);
  const [flash, setFlash] = useState(false);
  const rtl = lang === 'ar';

  const idxRef = useRef(0);
  useEffect(() => { idxRef.current = index; }, [index]);

  const go = (i) => {
    const cur = idxRef.current;
    if (i < 0 || i === cur) return;
    if (i >= total) { setDone(true); return; }
    setDir(i > cur ? 1 : -1); idxRef.current = i; setIndex(i);
  };
  const next = () => {
    const cur = idxRef.current;
    if (cur >= total - 1) { setDone(true); return; }
    setDir(1); idxRef.current = cur + 1; setIndex(cur + 1);
  };
  const prev = () => {
    const cur = idxRef.current;
    if (cur <= 0) return;
    setDir(-1); idxRef.current = cur - 1; setIndex(cur - 1);
  };
  const reset = () => { setDone(false); setDir(-1); idxRef.current = 0; setIndex(0); };

  const onSkip = () => { setFlash(true); setTimeout(() => setDone(true), 220); };

  const { dx, handlers } = useWtSwipe({ dir: rtl ? 'rtl' : 'ltr', onNext: next, onPrev: prev });

  const slide = WT_SLIDES[index];
  const petal = WT_PETALS[slide.petal];
  const accentVars = {
    '--app-accent': petal.main,
    '--app-accent-600': petal.d,
    '--app-accent-50': petal.bg,
    '--app-accent-shadow': `0 10px 26px ${petal.soft}0.34)`,
  };

  const tone = skin.tone || 'light';
  const skipColor = tone === 'dark' ? 'rgba(255,255,255,0.92)' : 'var(--fg3)';
  const dotColor = skin.dot?.color || (tone === 'dark' ? '#fff' : 'var(--app-accent)');
  const dotDim = skin.dot?.dim || (tone === 'dark' ? 'rgba(255,255,255,0.34)' : 'var(--balsm-ink-200)');
  const isLast = index === total - 1;

  return (
    <div className={cx('wt', `wt--${skin.key}`, `tone-${tone}`)} dir={rtl ? 'rtl' : 'ltr'}
         style={{ ...accentVars, ...(skin.base ? skin.base(petal) : {}) }}>

      {/* moving slide layer (swipe target) */}
      <div className="wt-stage" style={{ touchAction: 'pan-y' }} {...handlers}>
        <div key={index} className="wt-slide" data-dir={dir}
             style={{ transform: dx ? `translateX(${dx * 0.34}px)` : undefined,
                      transition: dx ? 'none' : undefined }}>
          {skin.renderSlide(slide, index, lang, true, dx)}
        </div>
      </div>

      {/* top chrome — skin-controlled; default = optional logo + Skip */}
      <div className="wt-top" data-no-swipe>
        {skin.renderTop
          ? skin.renderTop({ index, total, lang, go, onSkip, skipColor, petal })
          : (
            <React.Fragment>
              {skin.showLogo
                ? <img className="wt-logo" src={window.__resources ? window.__resources['logo-vertical'] : 'assets/logo-vertical.svg?v=5'} alt="Balsm.health"
                       style={{ filter: skin.logoDark ? 'brightness(0) invert(1)' : 'none' }} />
                : <span />}
              <button className="wt-skip" onClick={onSkip} style={{ color: skipColor }}>
                {wtx('skip', lang)}
              </button>
            </React.Fragment>
          )}
      </div>

      {/* bottom chrome — dots + Next / Get started */}
      <div className="wt-bottom" data-no-swipe>
        {!skin.hideDots && <WtDots total={total} index={index} onGo={go} color={dotColor} dim={dotDim} />}
        {skin.renderNext
          ? skin.renderNext({ isLast, next, label: wtx(isLast ? 'start' : 'next', lang), lang, petal, index, total })
          : (
            <button className="b-btn b-btn-lg b-btn-primary b-btn--full wt-next" onClick={next}>
              {wtx(isLast ? 'start' : 'next', lang)}
              <Icon name={isLast ? 'arrow-right' : 'arrow-right'} size={19}
                    style={{ transform: rtl ? 'scaleX(-1)' : 'none' }} />
            </button>
          )}
      </div>

      {flash && <div className="wt-flash" />}
      {done && <WalkthroughEnd lang={lang} onReplay={reset} />}
    </div>
  );
}

/* ── End / hand-off card (demonstrates the exit to Welcome) ───── */
function WalkthroughEnd({ lang, onReplay }) {
  const rtl = lang === 'ar';
  return (
    <div className="wt-end" dir={rtl ? 'rtl' : 'ltr'}>
      <div className="wt-end-card">
        <PetalMark className="wt-end-mark" />
        <div className="wt-end-title">{wtx('end_t', lang)}</div>
        <p className="wt-end-body">{wtx('end_b', lang)}</p>
        <button className="b-btn b-btn-lg b-btn-primary b-btn--full" onClick={onReplay}
          style={{ '--app-accent': WT_PETALS.aqua.main, '--app-accent-600': WT_PETALS.aqua.d,
                   '--app-accent-shadow': '0 10px 26px rgba(2,187,181,0.32)' }}>
          <Icon name="rotate-ccw" size={18} style={{ transform: rtl ? 'scaleX(-1)' : 'none' }} />
          {wtx('replay', lang)}
        </button>
      </div>
    </div>
  );
}

Object.assign(window, {
  WT_PETALS, WT_SLIDES, WT_STR, wtx,
  WtCounter, WtDots, useWtSwipe, WalkthroughShell, WalkthroughEnd,
});
