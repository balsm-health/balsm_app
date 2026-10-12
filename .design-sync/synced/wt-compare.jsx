/* wt-compare.jsx — side-by-side comparison of the three walkthrough treatments.
   Each phone runs an independent, fully interactive WalkthroughShell.
   Global language toggle (EN / العربية, with RTL) + tap-to-focus. */

/* Fit helper — scale a W×H box into the viewport with padding + cap. */
function useFitBox(W, H, padX, padY, cap) {
  const [s, setS] = useState(cap);
  useEffect(() => {
    const calc = () => {
      const sc = Math.min(cap, (window.innerWidth - padX) / W, (window.innerHeight - padY) / H);
      setS(Number(Math.max(0.3, sc).toFixed(3)));
    };
    calc();
    window.addEventListener('resize', calc);
    return () => window.removeEventListener('resize', calc);
  }, [W, H, padX, padY, cap]);
  return s;
}

function useRowScale() {
  const [s, setS] = useState(0.6);
  useEffect(() => {
    const calc = () => {
      const avail = Math.min(window.innerWidth, 1520) - 64;
      const perCol = (avail - 60) / 3;              // three columns, two 30px gaps
      const byW = perCol / 402;
      const byH = (window.innerHeight - 264) / 874;  // clear bar + caption + padding
      const sc = Math.max(0.46, Math.min(0.72, byW, byH));
      setS(Number(sc.toFixed(3)));
    };
    calc();
    window.addEventListener('resize', calc);
    return () => window.removeEventListener('resize', calc);
  }, []);
  return s;
}

/* One scaled phone running a treatment. */
function PhoneWT({ skinKey, lang, scale, onExpand }) {
  const W = 402, H = 874;
  return (
    <div className="wtc-frame-wrap" style={{ width: W * scale, height: H * scale }}>
      <div className="wtc-scaler" style={{ width: W, height: H, transform: `scale(${scale})` }}>
        <IOSDevice width={W} height={H}>
          <WalkthroughShell skin={WT_SKINS[skinKey]} lang={lang} />
        </IOSDevice>
      </div>
      {onExpand && (
        <button className="wtc-expand" onClick={() => onExpand(skinKey)} aria-label="Open larger">
          <Icon name="maximize-2" size={16} />
        </button>
      )}
    </div>
  );
}

/* Fullscreen focus of a single treatment. */
function FocusView({ skinKey, lang, onClose }) {
  const scale = useFitBox(402, 874, 96, 150, 0.98);
  useEffect(() => {
    const kh = (e) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', kh);
    return () => window.removeEventListener('keydown', kh);
  }, [onClose]);
  const meta = WT_SKIN_META.find(m => m.key === skinKey);
  const letter = 'ABC'[WT_SKIN_META.findIndex(m => m.key === skinKey)];
  return (
    <div className="wtc-focus" onClick={onClose}>
      <div className="wtc-focus-inner" onClick={e => e.stopPropagation()}
           style={{ width: 402 * scale, height: 874 * scale }}>
        <div className="wtc-focus-cap">
          <span className="k">{letter}</span>
          <span className="n">{meta.name[lang]}</span>
        </div>
        <button className="wtc-close" onClick={onClose} aria-label="Close"><Icon name="x" size={20} /></button>
        <div className="wtc-scaler" style={{ width: 402, height: 874, transform: `scale(${scale})` }}>
          <IOSDevice width={402} height={874}>
            <WalkthroughShell skin={WT_SKINS[skinKey]} lang={lang} />
          </IOSDevice>
        </div>
      </div>
    </div>
  );
}

function WalkthroughCompare() {
  const [lang, setLang] = useState('en');
  const [focus, setFocus] = useState(null);
  const scale = useRowScale();
  const rtl = lang === 'ar';

  return (
    <div className="wtc">
      {/* Toolbar */}
      <div className="wtc-bar">
        <div className="wtc-brand">
          <img src={window.__resources ? window.__resources['logo-vertical'] : 'assets/logo-vertical.svg?v=5'} alt="Balsm" />
          <span className="wtc-brand-name">Balsm<span className="dot">.health</span></span>
        </div>
        <span className="wtc-title">{lang === 'ar' ? 'جولة الترحيب — اختر التصميم' : 'Onboarding walkthrough — pick a treatment'}</span>
        <div className="wtc-spacer" />
        <div className="wtc-seg" role="tablist" aria-label="Language">
          <button className={cx(lang === 'en' && 'on')} onClick={() => setLang('en')}>English</button>
          <button className={cx('ar', lang === 'ar' && 'on')} onClick={() => setLang('ar')}>العربية</button>
        </div>
      </div>

      {/* Hint */}
      <div className="wtc-hint">
        <Icon name="hand" size={15} style={{ color: 'var(--fg4)' }} />
        {lang === 'ar'
          ? 'اسحب، أو جرّب تبويبات العرض التفاعلي في الشريحة الوسطى — ثم ابدأ. اضغط ⤢ لفتح أي هاتف بحجم أكبر.'
          : 'Swipe through, or try the interactive tabs on the middle slide — then Get started. Tap ⤢ to open any phone larger.'}
      </div>

      {/* Three treatments */}
      <div className="wtc-scroll">
        <div className="wtc-row">
          {WT_SKIN_META.map((m, i) => (
            <div className="wtc-col" key={m.key}>
              <div className="wtc-cap" dir={rtl ? 'rtl' : 'ltr'}>
                <span className="k">{'ABC'[i]}</span>
                <span className="n">{m.name[lang]}</span>
                <span className="t">· {m.tag[lang]}</span>
              </div>
              <PhoneWT skinKey={m.key} lang={lang} scale={scale} onExpand={setFocus} />
            </div>
          ))}
        </div>
      </div>

      {focus && <FocusView skinKey={focus} lang={lang} onClose={() => setFocus(null)} />}
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<WalkthroughCompare />);
