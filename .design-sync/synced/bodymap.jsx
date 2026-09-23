/* bodymap.jsx — anatomical region picker over the real SVG atlas in assets/body/.
   7 layers × 2 views; the skin layer is gender-specific.
   Every clickable area is an element in the SVG whose id starts with "region-"
   (sub-paths are suffixed -0, -1 … and normalise to one region), so the art
   files are the single source of truth for what can be tapped.

   Public interface is unchanged: <BodyMap selected={Set} onToggle initialGender />
   and HOTSPOTS / HP_FRONT / HP_BACK stay exported for label lookups. */

const BODY_LAYERS = [
  { id: 'skin',   icon: 'user',        file: null,        label: { en: 'Skin',    ar: 'الجلد'   } },
  { id: 'muscle', icon: 'dumbbell',    file: 'muscles',   label: { en: 'Muscle',  ar: 'العضلات' } },
  { id: 'bone',   icon: 'bone',        file: 'bones',     label: { en: 'Bone',    ar: 'العظام'  } },
  { id: 'joint',  icon: 'target',      file: 'joints',    label: { en: 'Joint',   ar: 'المفاصل' } },
  { id: 'tendon', icon: 'link-2',      file: 'tendons',   label: { en: 'Tendon',  ar: 'الأوتار' } },
  { id: 'nerve',  icon: 'zap',         file: 'nerves',    label: { en: 'Nerve',   ar: 'الأعصاب' } },
  { id: 'organ',  icon: 'heart-pulse', file: 'organs',    label: { en: 'Organ',   ar: 'الأعضاء' } },
];
/* legacy alias — older callers referenced LAYER_CFG */
const LAYER_CFG = Object.fromEntries(BODY_LAYERS.map(l => [l.id, l]));

/* ── Region labels, keyed by the id in the SVG (minus the "region-" prefix) ── */
const REGION_LABELS = {
  /* front — body */
  'head':        { en: 'Head',        ar: 'الرأس' },
  'neck':        { en: 'Neck',        ar: 'الرقبة' },
  'l-shoulder':  { en: 'L. Shoulder', ar: 'كتف أيسر' },
  'r-shoulder':  { en: 'R. Shoulder', ar: 'كتف أيمن' },
  'chest':       { en: 'Chest',       ar: 'الصدر' },
  'l-upper-arm': { en: 'L. Upper arm', ar: 'عضد أيسر' },
  'r-upper-arm': { en: 'R. Upper arm', ar: 'عضد أيمن' },
  'abdomen':     { en: 'Abdomen',     ar: 'البطن' },
  'l-elbow':     { en: 'L. Elbow',    ar: 'مرفق أيسر' },
  'r-elbow':     { en: 'R. Elbow',    ar: 'مرفق أيمن' },
  'l-forearm':   { en: 'L. Forearm',  ar: 'ساعد أيسر' },
  'r-forearm':   { en: 'R. Forearm',  ar: 'ساعد أيمن' },
  'pelvis':      { en: 'Pelvis',      ar: 'الحوض' },
  'l-hand':      { en: 'L. Hand',     ar: 'يد يسرى' },
  'r-hand':      { en: 'R. Hand',     ar: 'يد يمنى' },
  'l-thigh':     { en: 'L. Thigh',    ar: 'فخذ أيسر' },
  'r-thigh':     { en: 'R. Thigh',    ar: 'فخذ أيمن' },
  'l-knee':      { en: 'L. Knee',     ar: 'ركبة يسرى' },
  'r-knee':      { en: 'R. Knee',     ar: 'ركبة يمنى' },
  'l-shin':      { en: 'L. Shin',     ar: 'ساق يسرى' },
  'r-shin':      { en: 'R. Shin',     ar: 'ساق يمنى' },
  'l-foot':      { en: 'L. Foot',     ar: 'قدم يسرى' },
  'r-foot':      { en: 'R. Foot',     ar: 'قدم يمنى' },
  /* front — face */
  'sinuses':     { en: 'Sinuses',     ar: 'الجيوب الأنفية' },
  'l-eye':       { en: 'L. Eye',      ar: 'عين يسرى' },
  'r-eye':       { en: 'R. Eye',      ar: 'عين يمنى' },
  'l-ear':       { en: 'L. Ear',      ar: 'أذن يسرى' },
  'r-ear':       { en: 'R. Ear',      ar: 'أذن يمنى' },
  'jaw':         { en: 'Jaw',         ar: 'الفك' },
  /* back */
  'bk-head':       { en: 'Head (back)',   ar: 'الرأس (خلف)' },
  'bk-neck':       { en: 'Nape',          ar: 'مؤخرة الرقبة' },
  'bk-l-shoulder': { en: 'L. Shoulder',   ar: 'كتف أيسر' },
  'bk-r-shoulder': { en: 'R. Shoulder',   ar: 'كتف أيمن' },
  'bk-upper':      { en: 'Upper back',    ar: 'أعلى الظهر' },
  'bk-mid':        { en: 'Mid back',      ar: 'وسط الظهر' },
  'bk-lower':      { en: 'Lower back',    ar: 'أسفل الظهر' },
  'bk-l-glute':    { en: 'L. Glute',      ar: 'أرداف أيسر' },
  'bk-r-glute':    { en: 'R. Glute',      ar: 'أرداف أيمن' },
  'bk-l-hamstr':   { en: 'L. Hamstring',  ar: 'أوتار ركبة يسرى' },
  'bk-r-hamstr':   { en: 'R. Hamstring',  ar: 'أوتار ركبة يمنى' },
  'bk-l-calf':     { en: 'L. Calf',       ar: 'بطة ساق يسرى' },
  'bk-r-calf':     { en: 'R. Calf',       ar: 'بطة ساق يمنى' },
  'bk-l-heel':     { en: 'L. Heel',       ar: 'كعب أيسر' },
  'bk-r-heel':     { en: 'R. Heel',       ar: 'كعب أيمن' },
  'bk-l-ear':      { en: 'L. Ear',        ar: 'أذن يسرى' },
  'bk-r-ear':      { en: 'R. Ear',        ar: 'أذن يمنى' },
  /* organs */
  'heart':      { en: 'Heart',       ar: 'القلب' },
  'l-lung':     { en: 'L. Lung',     ar: 'رئة يسرى' },
  'r-lung':     { en: 'R. Lung',     ar: 'رئة يمنى' },
  'liver':      { en: 'Liver',       ar: 'الكبد' },
  'stomach':    { en: 'Stomach',     ar: 'المعدة' },
  'intestines': { en: 'Intestines',  ar: 'الأمعاء' },
  'bladder':    { en: 'Bladder',     ar: 'المثانة' },
  'l-kidney':   { en: 'L. Kidney',   ar: 'كلية يسرى' },
  'r-kidney':   { en: 'R. Kidney',   ar: 'كلية يمنى' },
};

const regionLabel = (id, lang) => (REGION_LABELS[id] || { en: id, ar: id })[lang] || id;

/* Back-compat shapes: callers do HOTSPOTS.find(h => h.id === id)?.label?.en */
const asHotspots = (ids) => ids.map(id => ({ id, label: REGION_LABELS[id] }));
const HP_FRONT = asHotspots(Object.keys(REGION_LABELS).filter(k => !k.startsWith('bk-')));
const HP_BACK  = asHotspots(Object.keys(REGION_LABELS).filter(k =>  k.startsWith('bk-')));
const HP_ALL   = [...HP_FRONT, ...HP_BACK];
const HOTSPOTS = HP_ALL;

/* ── SVG source + fetch cache ──────────────────────────────── */
const bodySrc = (layer, view, gender) => {
  const cfg = LAYER_CFG[layer];
  const key = `body-${cfg.file || gender}_${view}`;
  return (window.__resources && window.__resources[key]) || `assets/body/${cfg.file || gender}_${view}.svg`;
};
const bodyCache = new Map();
function loadBodySvg(src) {
  if (!bodyCache.has(src)) {
    bodyCache.set(src, fetch(src).then(r => {
      if (!r.ok) throw new Error(r.status + ' ' + src);
      return r.text();
    }));
  }
  return bodyCache.get(src);
}

/* strip the -0 / -12 sub-path suffix so every fragment maps to one region */
const normRegion = (rawId) => rawId.replace(/^region-/, '').replace(/-\d+$/, '');

/* ── Main component ────────────────────────────────────────── */
function BodyMap({ selected, onToggle, color, initialGender, showControls = true, allowedLayers }) {
  const { lang } = useApp();
  const layerChoices = allowedLayers && allowedLayers.length ? BODY_LAYERS.filter(l => allowedLayers.includes(l.id)) : BODY_LAYERS;
  const [view, setView]   = useState('front');
  const [layer, setLayer] = useState(layerChoices[0]?.id || 'skin');
  const [markup, setMarkup] = useState(null);
  const [failed, setFailed] = useState(false);
  const hostRef = useRef(null);

  const gender = (initialGender === 'male' || initialGender === 'female') ? initialGender : 'female';
  const accent = color || 'var(--app-accent)';
  const sel = selected instanceof Set ? selected : new Set();
  const src = bodySrc(layer, view, gender);

  useEffect(() => {
    let live = true;
    setMarkup(null); setFailed(false);
    loadBodySvg(src).then(txt => { if (live) setMarkup(txt); })
      .catch(() => { if (live) setFailed(true); });
    return () => { live = false; };
  }, [src]);

  /* Paint the selection onto whatever regions the loaded atlas contains.
     Opaque anatomy (organs, skin fills) gets an outline + glow; transparent
     hit-areas get a translucent accent wash. */
  useEffect(() => {
    const host = hostRef.current; if (!host || !markup) return;
    host.querySelectorAll('[id^="region-"]').forEach(el => {
      const on = sel.has(normRegion(el.id));
      const fill = (el.getAttribute('fill') || '').trim().toLowerCase();
      const transparent = !fill || fill === 'none' || /^#[0-9a-f]{6}00$/.test(fill) || fill === 'transparent';
      /* data attributes, not classList — SVG className is a read-only SVGAnimatedString */
      el.setAttribute('data-sel', on ? '1' : '0');
      el.setAttribute('data-wash', (on && (transparent || layer === 'skin')) ? '1' : '0');
    });
  }, [markup, selected, layer, view]);

  const click = (e) => {
    const el = e.target.closest && e.target.closest('[id^="region-"]');
    if (!el || !onToggle) return;
    onToggle(normRegion(el.id));
  };

  const chip = (on, disabled) => ({
    height: 34, padding: '0 13px', borderRadius: 'var(--radius-pill)',
    cursor: disabled ? 'default' : 'pointer', opacity: disabled ? 0.4 : 1,
    border: `1.5px solid ${on ? accent : 'var(--balsm-border)'}`,
    background: on ? 'var(--app-accent-50)' : '#fff',
    color: on ? accent : 'var(--fg2)',
    fontFamily: lang === 'ar' ? 'var(--font-arabic)' : 'var(--font-body)',
    fontSize: 'var(--pt-xs)', fontWeight: 600,
    display: 'flex', alignItems: 'center', gap: 5, flexShrink: 0, whiteSpace: 'nowrap',
  });

  const chosen = [...sel].map(id => regionLabel(id, lang));

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      {showControls && <>
        <div style={{ display: 'flex', gap: 5 }}>
          {[['front', lang === 'ar' ? 'أمامي' : 'Front'], ['back', lang === 'ar' ? 'خلفي' : 'Back']].map(([id, lbl]) => (
            <button key={id} style={chip(view === id)} onClick={() => setView(id)}>{lbl}</button>
          ))}
        </div>
        <div style={{ display: 'flex', gap: 5, overflowX: 'auto', paddingBottom: 2 }}>
          {layerChoices.map(l => (
            <button key={l.id} style={chip(layer === l.id)} onClick={() => setLayer(l.id)}>
              <Icon name={l.icon} size={12} />{l.label[lang]}
            </button>
          ))}
        </div>
      </>}

      <div style={{ fontSize: 'var(--pt-xs)', fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase', color: chosen.length ? 'var(--fg2)' : 'var(--fg4)', minHeight: 16, textAlign: 'center', lineHeight: 1.4 }}>
        {chosen.length === 0 ? (lang === 'ar' ? 'انقر لتحديد الموقع' : 'Tap to mark location') : chosen.join(' · ')}
      </div>

      <div className={cx('bm-host', layer === 'skin' && 'bm-skin', sel.size > 0 && 'bm-has-sel')} ref={hostRef} onClick={click}
        style={{ '--bm-accent': accent, minHeight: 220, height: 'auto', display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'visible' }}
        aria-label="Anatomy diagram">
        {markup
          ? <div style={{ width: '100%', maxWidth: 190 }} dangerouslySetInnerHTML={{ __html: markup }} />
          : <span className="meta">{failed
              ? (lang === 'ar' ? 'تعذّر تحميل الرسم' : 'Diagram unavailable')
              : (lang === 'ar' ? 'جارٍ التحميل…' : 'Loading…')}</span>}
      </div>
    </div>
  );
}

Object.assign(window, { BodyMap, BODY_LAYERS, LAYER_CFG, REGION_LABELS, regionLabel, HP_FRONT, HP_BACK, HP_ALL, HOTSPOTS });
