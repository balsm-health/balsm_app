/* app.jsx — shell: router, tab bar, context, scaling, Tweaks */

const ACCENTS = {
  blue:    { main: '#1283FF', d: '#0F6BCC', bg: '#E4F0FF', sh: 'rgba(18,131,255,.26)' },
  aqua:    { main: '#02BBB5', d: '#029E99', bg: '#E2F8F6', sh: 'rgba(2,187,181,.26)'  },
  emerald: { main: '#01C4A2', d: '#019A7F', bg: '#E1F8F1', sh: 'rgba(1,196,162,.26)'  },
  violet:  { main: '#8350DE', d: '#6A3DBB', bg: '#EEE7FB', sh: 'rgba(131,80,222,.26)' },
  mint:    { main: '#3FC366', d: '#2FA552', bg: '#E8F9EE', sh: 'rgba(85,215,127,.30)' },
};
const hexToKey = (hex) => Object.keys(ACCENTS).find(k => ACCENTS[k].main.toLowerCase() === hex.toLowerCase()) || 'blue';

/* Splash logo motion presets — key ↔ display label (dropdown order) */
const SPLASH_ANIM_LABEL = {
  spin: 'Spin', bloom: 'Bloom', breathe: 'Breathe', stagger: 'Stagger', unfold: 'Unfold',
  sway: 'Sway', float: 'Float', tilt: 'Tilt', wave: 'Wave', shimmer: 'Shimmer',
  twinkle: 'Twinkle', halo: 'Halo', aurora: 'Aurora', orbit: 'Orbit', pulse: 'Pulse',
};

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "lang": "en",
  "accent": "violet",
  "fontScale": 1,
  "splashAnim": "spin",
  "numpad": "custom",
  "vpW": 390,
  "vpH": 844
}/*EDITMODE-END*/;

/* Viewport presets — DS window-class reference sizes (RESPONSIVE.md §0) */
const VIEWPORTS = [
  { id: 'compact',  label: 'Compact',  w: 390,  h: 844  },
  { id: 'medium',   label: 'Medium',   w: 834,  h: 1194 },
  { id: 'expanded', label: 'Expanded', w: 1280, h: 800  },
  { id: 'wide',     label: 'Wide',     w: 1440, h: 900  },
  { id: 'min',      label: 'Min 800×600', w: 800, h: 600 },
];
const VP_MIN_W = 320, VP_MIN_H = 480, VP_MAX_W = 2560, VP_MAX_H = 1600;
const wcOf = (w) => w < 600 ? 'compact' : w < 1024 ? 'medium' : w < 1440 ? 'expanded' : 'wide';

/* Toolbar + single resizable frame. One render, one layout — only the size changes. */
function ViewportControl({ w, h, onChange }) {
  const short = h <= 700;
  return (
    <div className="vp-bar">
      {VIEWPORTS.map(p => (
        <button key={p.id} type="button" className={cx('vp-preset', p.w === w && p.h === h && 'on')} onClick={() => onChange(p.w, p.h)}>
          {p.label}<span className="vp-dim">{p.w}×{p.h}</span>
        </button>
      ))}
      <span className="vp-read"><b>{w}</b> × <b>{h}</b> · {wcOf(w)}{short && ' · short'}</span>
    </div>
  );
}
function ViewportFrame({ w, h, scale, onResize, children }) {
  const drag = useRef(null);
  const start = (axis) => (e) => {
    e.preventDefault();
    drag.current = { axis, x: e.clientX, y: e.clientY, w, h };
    const move = (ev) => {
      const d = drag.current; if (!d) return;
      const nw = d.axis !== 'y' ? Math.round(Math.min(VP_MAX_W, Math.max(VP_MIN_W, d.w + (ev.clientX - d.x) / scale))) : d.w;
      const nh = d.axis !== 'x' ? Math.round(Math.min(VP_MAX_H, Math.max(VP_MIN_H, d.h + (ev.clientY - d.y) / scale))) : d.h;
      onResize(nw, nh);
    };
    const up = () => { drag.current = null; window.removeEventListener('pointermove', move); window.removeEventListener('pointerup', up); };
    window.addEventListener('pointermove', move); window.addEventListener('pointerup', up);
  };
  return (
    <div className="vp-frame" style={{ width: w, height: h }}>
      {children}
      <div className="vp-handle vp-handle-x" onPointerDown={start('x')} />
      <div className="vp-handle vp-handle-y" onPointerDown={start('y')} />
      <div className="vp-handle vp-handle-xy" onPointerDown={start('xy')} />
    </div>
  );
}

function useFit(w, h, pad = 40) {
  const [scale, setScale] = useState(1);
  useEffect(() => {
    const fit = () => setScale(Math.min(1, (window.innerWidth - pad) / w, (window.innerHeight - pad) / h));
    fit();
    window.addEventListener('resize', fit);
    return () => window.removeEventListener('resize', fit);
  }, [w, h, pad]);
  return scale;
}

/* ── Shake detector ──────────────────────────────────────── */
function useShake(cbRef, threshold = 15) {
  const last = useRef(0);
  useEffect(() => {
    const handler = (e) => {
      const a = e.accelerationIncludingGravity || e.acceleration;
      if (!a) return;
      const mag = Math.sqrt((a.x||0)**2 + (a.y||0)**2 + (a.z||0)**2);
      if (mag > threshold && Date.now() - last.current > 1500) {
        last.current = Date.now();
        cbRef.current?.();
      }
    };
    window.addEventListener('devicemotion', handler, true);
    return () => window.removeEventListener('devicemotion', handler, true);
  }, [threshold]);
}

/* ── Tab bar ─────────────────────────────────────────────── */
/* ── App navigation — one component, three placements (Layer 1) ──
   compact: bottom bar · medium/expanded: 72px rail · wide: 240px sidebar.
   Placement is CSS-only (container queries on .app-body). */
function AppNav({ hidden }) {
  const { t, tab, setTab, openQuickLog } = useApp();
  const Item = ({ id, icon, label }) => (
    <button className={cx('tab', tab === id && 'active')} onClick={() => setTab(id)} aria-current={tab === id ? 'page' : undefined}>
      <Icon name={icon} size={24} stroke={tab === id ? 2.1 : 1.9} />
      <span>{label}</span>
    </button>
  );
  return (
    <nav className={cx('tabbar wc-chrome', hidden && 'nav-hidden')} aria-label="Main">
      <div className="nav-brand">
        <img src="assets/icon.svg?v=7" alt="" className="nav-mark" />
        <span className="nav-word">Balsm<span className="nav-tld">.health</span></span>
      </div>
      <Item id="home"    icon="home"        label={t('tab_home')}    />
      <Item id="map"     icon="map-pin"     label={t('tab_map')}     />
      <div className="tab tab-fab">
        <button className="fab" onClick={openQuickLog} aria-label={t('ql_title')}>
          <Icon name="plus" size={26} stroke={2.4} />
          <span className="fab-label">{t('ql_title')}</span>
        </button>
      </div>
      <Item id="meds"    icon="pill"        label={t('tab_meds')}    />
      <Item id="profile" icon="user"        label={t('tab_profile')} />
    </nav>
  );
}
const TabBar = AppNav;

function TabBarLegacy() {
  const { t, lang, tab, setTab, openQuickLog } = useApp();

  const Tab = ({ id, icon, label }) => (
    <button className={cx('tab', tab === id && 'active')} onClick={() => setTab(id)}>
      <Icon name={icon} size={24} stroke={tab === id ? 2.1 : 1.9} />
      <span>{label}</span>
    </button>
  );

  return (
    <div className="tabbar">
      <Tab id="home"    icon="home"        label={t('tab_home')}    />
      <Tab id="map"     icon="map-pin"     label={t('tab_map')}     />
      <div className="tab tab-fab">
        <div className="fab" onClick={openQuickLog}>
          <Icon name="plus" size={26} stroke={2.4} />
        </div>
      </div>
      <Tab id="meds"    icon="pill"        label={t('tab_meds')}    />
      <Tab id="profile" icon="user"        label={t('tab_profile')} />
    </div>
  );
}

/* ── Generic per-screen loading skeleton (replaces the old full-screen overlay) ── */
function ScreenSkeleton() {
  return (
    <div className="screen-scroll fade-in">
      <div className="pad-top" />
      <div className="appbar"><DSSkeleton variant="title" width={140} height={26} /></div>
      <div className="card" style={{ margin: '4px 20px 16px', padding: 20, display: 'flex', alignItems: 'center', gap: 16 }}>
        <DSSkeleton variant="circle" width={52} height={52} />
        <div style={{ flex: 1 }}><DSSkeleton variant="text" lines={2} lastWidth="70%" /></div>
      </div>
      <div className="card" style={{ margin: '0 20px 16px', padding: 0 }}>
        {[0, 1, 2].map(i => (
          <div key={i} className="med-row">
            <DSSkeleton variant="circle" width={40} height={40} />
            <div style={{ flex: 1 }}><DSSkeleton variant="text" lines={2} lastWidth="45%" /></div>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ── Main app (post-auth) ────────────────────────────────── */
function MainApp() {
  const { t, tab, setTab, flowOpen, openFlow, closeFlow, finishFlow, quickLogOpen, openQuickLog, closeQuickLog, navHidden } = useApp();
  const [navLoading, setNavLoading] = useState(false);
  const firstTab = useRef(true);
  useEffect(() => {
    if (firstTab.current) { firstTab.current = false; return; }
    setNavLoading(true);
    const navTimer = setTimeout(() => setNavLoading(false), 520);
    return () => clearTimeout(navTimer);
  }, [tab]);

  /* 'trends', 'records', 'appts' are sub-screens (not in the tab bar) reached from Home/Profile */
  const screenEl = navLoading
    ? <ScreenSkeleton key={tab} />
    : {
        home:    <HomeScreen />,
        trends:  <TrendsScreen />,
        map:     <MapScreen />,
        meds:    <MedsScreen />,
        profile: <ProfileScreen />,
        records: <RecordsScreen onBack={() => setTab('home')} />,
      }[tab] || <HomeScreen />;

  /* Sub-screens push the nav away at compact only; rail/sidebar persist at medium+ */
  const hideTabBar = tab === 'trends' || tab === 'records' || navHidden;

  return (
    <div className="screen app-shell">
      <AppNav hidden={hideTabBar} />
      <div className="app-main">{screenEl}</div>
      {quickLogOpen && !flowOpen && (
        <QuickLogSheet
          onClose={closeQuickLog}
          onFullCheckin={() => { closeQuickLog(); openFlow(); }}
        />
      )}
      {flowOpen && <ReportFlow onClose={closeFlow} onDone={finishFlow} />}
    </div>
  );
}

/* ── Root app ────────────────────────────────────────────── */
function App() {
  const [tw, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const lang   = tw.lang;
  const dir    = lang === 'ar' ? 'rtl' : 'ltr';
  const accentKey = tw.accent in ACCENTS ? tw.accent : 'blue';
  const A = ACCENTS[accentKey];

  const [route, setRoute]     = useState(() => (localStorage.getItem('balsm_wt_seen') ? 'welcome' : 'walkthrough'));
  const [wtReturnTo, setWtReturnTo] = useState('welcome');
  const [tab, setTab]         = useState('home');
  const [booting, setBooting] = useState(() => !sessionStorage.getItem('balsm_booted'));
  const finishBoot = useCallback(() => { setBooting(false); sessionStorage.setItem('balsm_booted', '1'); }, []);
  const replaySplash = useCallback(() => setBooting(true), []);
  const replayWalkthrough = useCallback(() => { setWtReturnTo('app'); setRoute('walkthrough'); }, []);
  const [authEmail, setAuthEmail]   = useState('');
  const [authIntent, setAuthIntent] = useState('signup'); // 'signup' | 'signin'
  const [profileComplete, setProfileComplete] = useState(true); // false right after signup until Personal details is saved
  const [today, setToday]               = useState(null);
  const [flowOpen, setFlowOpen]         = useState(false);
  const [quickLogOpen, setQuickLogOpen] = useState(false);
  const [pendingRecordType, setPendingRecordType] = useState(null);
  const [navHidden, setNavHidden] = useState(false);
  const [careTeamJump, setCareTeamJump] = useState(0);
  const [activeAccountId, setActiveAccountId] = useState('layla');
  const [extraAccounts, setExtraAccounts] = useState([]);
  const familyAccounts = [...FAMILY_ACCOUNTS, ...extraAccounts];
  const account = familyAccounts.find(a => a.id === activeAccountId) || familyAccounts[0];
  const addFamilyMember = ({ name, relation, dob, handle, status }) => {
    const palette = ['var(--petal-aqua)', 'var(--petal-blue)', 'var(--petal-violet)', 'var(--petal-mint)', 'var(--balsm-sun,#E5B428)'];
    const id = 'fam_' + Date.now();
    const initials = name.trim().split(/\s+/).slice(0, 2).map(w => w[0]).join('').toUpperCase() || '?';
    let age = null;
    if (dob) {
      const today = new Date();
      const birth = new Date(dob + 'T00:00:00');
      age = today.getFullYear() - birth.getFullYear();
      const hasHadBirthdayThisYear = (today.getMonth() > birth.getMonth()) || (today.getMonth() === birth.getMonth() && today.getDate() >= birth.getDate());
      if (!hasHadBirthdayThisYear) age -= 1;
      age = Math.max(0, age);
    }
    const acc = {
      id, name: { en: name, ar: name }, initials,
      color: palette[familyAccounts.length % palette.length],
      relation: { en: relation || 'Family member', ar: relation || 'فرد من الأسرة' },
      age, dob, since: { en: 'Today', ar: 'اليوم' }, conditions: [],
      handle: handle || null, status: status || 'linked',
    };
    setExtraAccounts(prev => [...prev, acc]);
    if (!status || status === 'linked') setActiveAccountId(id);
    return id;
  };
  /* Link requests — outgoing ones await the other person's approval; incoming ones await yours */
  const [linkRequests, setLinkRequests] = useState([
    { id: 'lr1', handle: 'yara.hassan', name: { en: 'Yara Hassan', ar: 'يارا حسن' }, initials: 'YH', color: 'var(--petal-aqua)',
      relation: { en: 'Sister', ar: 'الأخت' }, age: 34, dob: '1992-04-18',
      asks: { en: 'wants to add you to their family account', ar: 'تريد إضافتك إلى حساب أسرتها' },
      when: { en: '2 hours ago', ar: 'قبل ساعتين' } },
  ]);
  const approveLinkRequest = (reqId) => {
    const r = linkRequests.find(x => x.id === reqId);
    setLinkRequests(prev => prev.filter(x => x.id !== reqId));
    if (r) addFamilyMember({ name: r.name.en, relation: r.relation.en, dob: r.dob, handle: r.handle, status: 'linked' });
  };
  const declineLinkRequest = (reqId) => setLinkRequests(prev => prev.filter(x => x.id !== reqId));
  const cancelPendingLink = (accId) => {
    setExtraAccounts(prev => prev.filter(a => a.id !== accId));
    setActiveAccountId(cur => cur === accId ? 'layla' : cur);
  };
  const [countryCode, setCountryCode] = useState('EG');
  const country = COUNTRIES.find(c => c.code === countryCode) || COUNTRIES[0];

  const [storageProviders, setStorageProviders] = useState({ active: 'local' });

  /* ── Dev config ──────────────────────────────────────── */
  const [devOpen, setDevOpen] = useState(false);
  const [devShot, setDevShot] = useState(null);
  const devCbRef = useRef(null);
  const captureAndOpen = useCallback(async () => {
    let shot = null;
    try {
      if (window.html2canvas) {
        const el = document.querySelector('.screen') ||
                   document.querySelector('.stage-full > div');
        if (el) {
          const canvas = await window.html2canvas(el, {
            scale: 0.6, useCORS: true, logging: false, allowTaint: true,
          });
          shot = canvas.toDataURL('image/jpeg', 0.82);
        }
      }
    } catch {}
    setDevShot(shot);
    setDevOpen(true);
  }, []);
  devCbRef.current = captureAndOpen;
  useShake(devCbRef);
  useEffect(() => {
    const kh = (e) => {
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'D') {
        e.preventDefault();
        captureAndOpen();
      }
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && (e.key === 'B' || e.key === 'b')) {
        e.preventDefault();
        replaySplash();
      }
    };
    window.addEventListener('keydown', kh);
    window.openDevConfig = captureAndOpen;
    window.replaySplash = replaySplash;
    return () => {
      window.removeEventListener('keydown', kh);
      delete window.openDevConfig;
      delete window.replaySplash;
    };
  }, [captureAndOpen, replaySplash]);
  const switchCloudProvider = (to) => {
    setStorageProviders({ active: to });
    // Migrate all records that were on the old cloud to the new one
    const prev = storageProviders.active;
    if (prev !== 'local' && to !== 'local') {
      setRecordStorageMap(m => {
        const next = { ...m };
        HEALTH_RECORDS.forEach(r => { if ((m[r.id] || r.storage) === prev) next[r.id] = to; });
        return next;
      });
    }
  };

  /* Global record-storage overrides — updated by migrations & per-record manage actions */
  const [recordStorageMap, setRecordStorageMap] = useState({});
  const setRecordStorage = (id, loc) => setRecordStorageMap(m => ({ ...m, [id]: loc }));
  const migrateRecords   = (from, to) => {
    setRecordStorageMap(prev => {
      const next = { ...prev };
      HEALTH_RECORDS.forEach(r => { if ((prev[r.id] || r.storage) === from) next[r.id] = to; });
      return next;
    });
    setPrimaryStorage(to);
  };

  const t = useCallback((key) => (STR[key] && (STR[key][lang] ?? STR[key].en)) ?? key, [lang]);

  const go = (r) => {
    if (r === 'app')     { setTab('home'); setToday(null); }
    if (r === 'welcome') { setToday(null); if (!localStorage.getItem('balsm_wt_seen')) localStorage.setItem('balsm_wt_seen', '1'); }
    setRoute(r);
  };

  const ctx = {
    t, lang, dir, accent: accentKey,
    numpad: tw.numpad === 'native' ? 'native' : 'custom',
    splashAnim: tw.splashAnim || 'bloom',
    setLang: (l) => setTweak('lang', l),
    authEmail, setAuthEmail, authIntent, setAuthIntent,
    profileComplete, setProfileComplete,
    go, tab, setTab,
    today, completeCheckin: setToday,
    flowOpen,
    openFlow:  () => setFlowOpen(true),
    closeFlow: () => setFlowOpen(false),
    quickLogOpen,
    navHidden, setNavHidden,
    careTeamJump, openCareTeam: () => { setTab('profile'); setCareTeamJump(n => n + 1); },
    openQuickLog:  () => setQuickLogOpen(true),
    closeQuickLog: () => setQuickLogOpen(false),
    pendingRecordType, clearPendingRecordType: () => setPendingRecordType(null),
    addRecord: (type) => { setQuickLogOpen(false); setPendingRecordType(type); setTab('records'); },
    account, switchAccount: setActiveAccountId, familyAccounts, addFamilyMember,
    linkRequests, approveLinkRequest, declineLinkRequest, cancelPendingLink,
    country, setCountry: setCountryCode,
    storageProviders, switchCloudProvider,
    recordStorageMap, setRecordStorage, migrateRecords,
    replaySplash,
    replayWalkthrough,
    finishFlow: (toTab) => { setFlowOpen(false); setTab(toTab); },
  };

  const vpW = Number(tw.vpW) || 390, vpH = Number(tw.vpH) || 844;
  const setViewport = (w, h) => { setTweak('vpW', w); setTweak('vpH', h); };
  const scale = useFit(vpW, vpH + 44, 40);

  const AuthScreen = { welcome: WelcomeScreen, phone: PhoneScreen, otp: OtpScreen, profile: ProfileSetupScreen }[route];

  const accentVars = {
    '--app-accent':        A.main,
    '--app-accent-600':    A.d,
    '--app-accent-50':     A.bg,
    '--app-accent-shadow': `0 8px 22px ${A.sh}`,
    /* Bridge the accent Tweak into the design system's own primary tokens,
       so DS components (.b-btn-primary, focus rings, .b-badge--info) follow it. */
    '--balsm-primary':       A.main,
    '--balsm-primary-hover': A.d,
    '--balsm-primary-bg':    A.bg,
    '--ui-scale': tw.fontScale,
  };

  return (
    <AppCtx.Provider value={ctx}>
      <div className="stage" style={accentVars}>
        {/* Tablet/desktop: single responsive render in a resizable viewport frame */}
        <div className="stage-frame-wrap" style={{ display: 'flex', alignItems: 'flex-start', gap: 0 }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12, alignItems: 'flex-start' }}>
            <ViewportControl w={vpW} h={vpH} onChange={setViewport} />
            <div style={{ width: vpW * scale, height: vpH * scale }}>
              <div style={{ transform: `scale(${scale})`, transformOrigin: 'top left' }}>
              <ViewportFrame w={vpW} h={vpH} scale={scale} onResize={setViewport}>
                <div dir={dir} className="vp-app" style={{ height: '100%', position: 'absolute', inset: 0 }}>
                  <div className="app-body">
                  {route === 'app' ? <MainApp /> : route === 'walkthrough' ? <WalkthroughShell skin={WT_SKINS.petal} lang={lang} onDone={() => go(wtReturnTo)} /> : <AuthScreen />}
                  {devOpen && <DevConfigOverlay onClose={() => setDevOpen(false)} screenshot={devShot} />}
                  {booting && <SplashScreen onDone={finishBoot} />}
                  </div>
                </div>
              </ViewportFrame>
              </div>
            </div>
          </div>

          {/* Desktop companion panel — contextual to auth vs. signed-in app */}
          <div className="stage-companion">
            {route === 'app' ? (
              <>
                <div className="stage-companion-card">
                  <h3>{lang === 'ar' ? 'الحساب' : 'Patient'}</h3>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <div style={{ width: 44, height: 44, borderRadius: 9999, background: account.color, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 16 }}>{account.initials}</div>
                    <div>
                      <div style={{ fontWeight: 700, fontSize: 14, color: 'var(--fg1)' }}>{account.name[lang] ?? account.name.en}</div>
                      <div style={{ fontSize: 12, color: 'var(--fg3)', marginTop: 2 }}>{account.age} · {account.relation[lang] ?? account.relation.en}</div>
                    </div>
                  </div>
                </div>
                <div className="stage-companion-card">
                  <h3>{lang === 'ar' ? 'إجراءات سريعة' : 'Quick actions'}</h3>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                    {[
                      [lang === 'ar' ? 'تسجيل قراءة' : 'Log reading',  'activity', () => setQuickLogOpen(true)],
                      [lang === 'ar' ? 'عرض السجلات' : 'View records', 'folder',   () => setTab('records')],
                      [lang === 'ar' ? 'رعاية قريبة' : 'Nearby care',  'map-pin',  () => setTab('map')],
                      [lang === 'ar' ? 'إعادة شاشة البداية' : 'Replay splash', 'sparkles', replaySplash],
                      [lang === 'ar' ? 'إعادة الجولة التعريفية' : 'Replay walkthrough', 'layout-template', replayWalkthrough],
                    ].map(([label, icon, fn]) => (
                      <button key={label} className="b-btn b-btn-md b-btn-secondary b-btn--full" onClick={fn} style={{ height: 40, fontSize: 13, justifyContent: 'flex-start', paddingInlineStart: 12 }}>
                        <Icon name={icon} size={15} />{label}
                      </button>
                    ))}
                    <button className="b-btn b-btn-md b-btn--full" onClick={captureAndOpen}
                      style={{ height: 40, fontSize: 12, justifyContent: 'flex-start', paddingInlineStart: 12,
                        background: '#1A1A17', color: '#A3FF6E', border: 'none',
                        fontFamily: 'var(--font-mono)', letterSpacing: '0.03em', gap: 8 }}>
                      <Icon name="terminal" size={14} stroke={2.2} style={{ color: '#A3FF6E' }} />
                      Dev config
                    </button>
                  </div>
                </div>
                <div className="stage-companion-card" style={{ fontSize: 12, color: 'var(--fg3)', lineHeight: 1.5, textAlign: 'center' }}>
                  <img src={window.__resources ? window.__resources['logo-vertical'] : 'assets/logo-vertical.svg?v=7'} alt="Balsm" style={{ width: 48, display: 'block', margin: '0 auto 8px', opacity: 0.4 }} />
                  Balsm Patient App MVP
                </div>
              </>
            ) : (
              <div className="stage-companion-card" style={{ textAlign: 'center', padding: '28px 22px' }}>
                <img src={window.__resources ? window.__resources['logo-vertical'] : 'assets/logo-vertical.svg?v=7'} alt="Balsm.health" style={{ width: 64, display: 'block', margin: '0 auto 14px' }} />
                <div style={{ fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 19, color: 'var(--fg1)', letterSpacing: '-0.01em' }}>
                  Balsm<span style={{ fontWeight: 600, fontSize: 15, color: 'var(--fg3)' }}>.health</span>
                </div>
                <div style={{ fontSize: 13, color: 'var(--fg3)', lineHeight: 1.55, margin: '8px 0 20px', textWrap: 'pretty' }}>{t('w_sub')}</div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 12, textAlign: 'start' }}>
                  {[['smartphone', t('trust_device')], ['lock', t('trust_private')], ['cloud-off', t('trust_offline')]].map(([icon, label]) => (
                    <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 13, fontWeight: 600, color: 'var(--fg2)' }}>
                      <span style={{ width: 30, height: 30, borderRadius: 8, background: 'var(--app-accent-50)', color: 'var(--app-accent-600)', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                        <Icon name={icon} size={16} />
                      </span>
                      {label}
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Mobile: full-viewport without frame */}
        <div className="stage-full">
          <div dir={dir} className="vp-app" style={{ position: 'absolute', inset: 0, background: 'var(--balsm-surface, #fff)' }}>
            <div className="app-body">
            {route === 'app' ? <MainApp /> : route === 'walkthrough' ? <WalkthroughShell skin={WT_SKINS.petal} lang={lang} onDone={() => go(wtReturnTo)} /> : <AuthScreen />}
            {devOpen && <DevConfigOverlay onClose={() => setDevOpen(false)} screenshot={devShot} />}
            {booting && <SplashScreen onDone={finishBoot} />}
            </div>
          </div>
        </div>
      </div>

      {/* Floating DEV trigger — shake on mobile · Ctrl+Shift+D anywhere */}
      <button onClick={captureAndOpen}
        title="Dev Config (Ctrl+Shift+D)"
        style={{
          position: 'fixed', bottom: 20, left: 20, zIndex: 9990,
          display: 'flex', alignItems: 'center', gap: 6,
          background: '#1A1A17', color: '#A3FF6E',
          fontFamily: 'var(--font-mono)', fontSize: 10, fontWeight: 700, letterSpacing: '0.05em',
          padding: '6px 11px', borderRadius: 8, border: 'none', cursor: 'pointer',
          boxShadow: '0 2px 12px rgba(0,0,0,.28)', opacity: 0.72,
          transition: 'opacity 150ms',
        }}
        onMouseEnter={e => e.currentTarget.style.opacity = '1'}
        onMouseLeave={e => e.currentTarget.style.opacity = '.72'}>
        <Icon name="terminal" size={12} stroke={2.2} style={{ color: '#A3FF6E' }} />
        DEV
      </button>

      {/* Floating splash trigger — replay brand intro · Ctrl+Shift+B anywhere */}
      <button onClick={replaySplash}
        title="Replay splash (Ctrl+Shift+B)"
        style={{
          position: 'fixed', bottom: 20, left: 82, zIndex: 9990,
          display: 'flex', alignItems: 'center', gap: 6,
          background: '#FFFFFF', color: 'var(--balsm-wordmark, var(--balsm-ink-600))',
          fontFamily: 'var(--font-mono)', fontSize: 10, fontWeight: 700, letterSpacing: '0.05em',
          padding: '6px 11px', borderRadius: 8, border: '1px solid rgba(82,97,116,.18)', cursor: 'pointer',
          boxShadow: '0 2px 12px rgba(0,0,0,.14)', opacity: 0.72,
          transition: 'opacity 150ms',
        }}
        onMouseEnter={e => e.currentTarget.style.opacity = '1'}
        onMouseLeave={e => e.currentTarget.style.opacity = '.72'}>
        <Icon name="sparkles" size={12} stroke={2.2} style={{ color: 'var(--app-accent, #1283FF)' }} />
        SPLASH
      </button>

      <TweaksPanel>
        <TweakSection label="Viewport" />
        <TweakNumber label="Width" value={vpW} min={VP_MIN_W} max={VP_MAX_W} step={10} unit="px" onChange={(v) => setTweak('vpW', v)} />
        <TweakNumber label="Height" value={vpH} min={VP_MIN_H} max={VP_MAX_H} step={10} unit="px" onChange={(v) => setTweak('vpH', v)} />
        <TweakSection label={t('p_lang')} />
        <TweakRadio label="Language" value={lang === 'ar' ? 'العربية' : 'English'} options={['English', 'العربية']}
          onChange={(v) => setTweak('lang', v === 'العربية' ? 'ar' : 'en')} />
        <TweakSection label="Accent petal" />
        <TweakColor label="Accent" value={A.main}
          options={Object.values(ACCENTS).map(a => a.main)}
          onChange={(hex) => setTweak('accent', hexToKey(hex))} />
        <TweakSection label="Accessibility" />
        <TweakSlider label="Text size" value={tw.fontScale} min={0.9} max={1.3} step={0.05} unit="×"
          onChange={(v) => setTweak('fontScale', v)} />
        <TweakSection label="Number entry" />
        <TweakRadio label="Keypad" value={tw.numpad === 'native' ? 'Native' : 'Balsm pad'} options={['Balsm pad', 'Native']}
          onChange={(v) => setTweak('numpad', v === 'Native' ? 'native' : 'custom')} />
        <TweakSection label="Splash" />
        <TweakSelect label="Logo motion"
          value={SPLASH_ANIM_LABEL[tw.splashAnim] || 'Spin'}
          options={Object.values(SPLASH_ANIM_LABEL)}
          onChange={(v) => setTweak('splashAnim', v.toLowerCase())} />
        <TweakButton label="Replay splash screen" onClick={replaySplash} secondary />
        <TweakButton label="Replay walkthrough" onClick={replayWalkthrough} secondary />
      </TweaksPanel>
    </AppCtx.Provider>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
