/* auth.jsx — Welcome → Phone → OTP → Profile setup */

/* Calm mood face drawn from arcs (no emoji) — shared with report flow */
function MoodFace({ level, size = 34, color }) {
  // level 1..5 → mouth curvature. eyes are simple dots.
  const curve = { 1: 7, 2: 3, 3: 0, 4: -4, 5: -8 }[level] ?? 0;
  const cy = 21 + (curve > 0 ? 1 : 0);
  const d = `M9 ${cy} Q17 ${cy + curve * 1.4} 25 ${cy}`;
  return (
    <svg width={size} height={size} viewBox="0 0 34 34" fill="none" style={{ display: 'block' }}>
      <circle cx="12.5" cy="14" r="1.9" fill={color} />
      <circle cx="21.5" cy="14" r="1.9" fill={color} />
      <path d={d} stroke={color} strokeWidth="2.4" strokeLinecap="round" />
    </svg>
  );
}

/* Apple + Google brand icons (inline SVG, no external deps) */
function AppleIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
      <path d="M17.05 20.28c-.98.95-2.05.86-3.08.38-1.08-.49-2.07-.48-3.2 0-1.42.61-2.17.44-3.05-.38C2.38 14.9 3.2 7.05 9.32 6.72c1.35.07 2.28.74 3.07.8 1.16-.22 2.27-.92 3.5-.83 1.5.12 2.63.72 3.36 1.82-3.1 1.86-2.37 5.95.48 7.1-.57 1.53-1.31 3.04-2.68 4.67zM12.03 6.65c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"/>
    </svg>
  );
}
function GoogleIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24">
      <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
      <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
      <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z"/>
      <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
    </svg>
  );
}

/* Splash — brand moment shown once on cold launch, before onboarding.
   Watercolor petal backdrop → petal lockup blooms → brand promise →
   thin fill track, then cross-fades into the Welcome screen. */
function SplashScreen({ onDone }) {
  const { lang, splashAnim } = useApp();
  const [exiting, setExiting] = useState(false);
  useEffect(() => {
    const reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const hold = reduce ? 1200 : 2300;
    const t1 = setTimeout(() => setExiting(true), hold);
    const t2 = setTimeout(() => onDone && onDone(), hold + 360);
    return () => { clearTimeout(t1); clearTimeout(t2); };
  }, []);
  return (
    <div className={cx('splash', exiting && 'splash--out')} data-anim={splashAnim || 'bloom'} dir={lang === 'ar' ? 'rtl' : 'ltr'}>
      <div className="splash-bg" style={{ backgroundImage: `url(${window.__resources ? window.__resources['balsm-bg'] : 'assets/balsm-background.png?v=7'})` }} />
      <div className="splash-grad" />
      <div className="splash-core">
        <div className="splash-logo-wrap">
          <div className="splash-aura" />
          <div className="splash-ring" />
          <div className="splash-orbit">
            {[0, 1, 2, 3, 4].map(i => <span key={i} style={{ '--i': i }} />)}
          </div>
          <div className="splash-pulse"><span /><span /><span /></div>
          <div className="splash-shadow" />
          <PetalMark className="splash-logo" />
          <div className="splash-sheen" />
        </div>
        <div className="splash-promise" style={{ textWrap: 'balance' }}>
          {lang === 'ar' ? 'رعايتك. بياناتك. نطامك.' : 'Your care. Your data. Your system.'}
        </div>
      </div>
      <div className="splash-foot">
        <div className="splash-eyebrow">{lang === 'ar' ? 'مفتوح · عربي · موثوق' : 'Open · Arab · Trusted'}</div>
        <div className="splash-dots"><span /><span /><span /><span /><span /></div>
      </div>
    </div>
  );
}

function WelcomeScreen() {
  const { t, lang, setLang, go, setAuthIntent } = useApp();
  return (
    <div className="welcome fade-in">
      <div className="wbg" style={{ backgroundImage: `url(${window.__resources ? window.__resources['balsm-bg'] : 'assets/balsm-background.png?v=7'})` }} />
      <div className="wgrad" />
      <div className="pad-top" />
      <div className="wbody">
        <img className="wlogo" src={window.__resources ? window.__resources['logo-vertical'] : 'assets/logo-vertical.svg?v=7'} alt="Balsm.health" />
        <div className="wtitle" style={{ textWrap: 'balance' }}>{t('w_title')}</div>
        <div className="wsub" style={{ textWrap: 'pretty' }}>{t('w_sub')}</div>
        <div className="wactions">
          {/* Email is the only sign-in route in this release — Apple/Google not yet supported on iOS */}
          <button className="b-btn b-btn-lg b-btn-primary b-btn--full" onClick={() => { setAuthIntent('signup'); go('phone'); }}>{t('w_start')}</button>

          <div className="signin-link" onClick={() => { setAuthIntent('signin'); go('phone'); }}>
            {t('w_have')} <b>{t('w_signin')}</b>
          </div>
        </div>
      </div>
      <div className="trust">
        <div className="ti"><Icon name="smartphone" size={22} /><span>{t('trust_device')}</span></div>
        <div className="ti"><Icon name="lock" size={22} /><span>{t('trust_private')}</span></div>
        <div className="ti"><Icon name="cloud-off" size={22} /><span>{t('trust_offline')}</span></div>
      </div>
      <div style={{ display: 'flex', justifyContent: 'center', padding: '4px 20px 0' }}>
        <button
          onClick={() => setLang(lang === 'ar' ? 'en' : 'ar')}
          aria-label={lang === 'ar' ? 'Switch to English' : 'التبديل إلى العربية'}
          style={{
            display: 'flex', alignItems: 'center', gap: 7, height: 38, padding: '0 16px',
            borderRadius: 999, cursor: 'pointer',
            background: 'rgba(26,26,23,0.42)', border: '1px solid rgba(255,255,255,0.32)',
            color: '#fff', fontWeight: 700, fontSize: 'var(--pt-sm)',
          }}>
          <Icon name="languages" size={17} />
          <span style={{ fontFamily: lang === 'ar' ? 'var(--font-body)' : 'var(--font-arabic)' }}>
            {lang === 'ar' ? 'English' : 'العربية'}
          </span>
        </button>
      </div>
      <div className="pad-bottom" />
    </div>
  );
}

function AuthHeader({ onBack, step }) {
  return (
    <div className="appbar">
      <button className="round-btn" onClick={onBack} aria-label="Back"><Icon name="arrow-left" /></button>
      <div className="grow" />
      {step && (
        <div className="segmented" style={{ padding: 4, gap: 4, background: 'transparent', border: 'none' }}>
          {[0,1,2].map(i => (
            <span key={i} style={{
              width: i === step - 1 ? 22 : 7, height: 7, borderRadius: 999,
              background: i <= step - 1 ? 'var(--app-accent)' : 'var(--balsm-ink-200)',
              transition: 'all .25s var(--ease-out)', display: 'inline-block',
            }} />
          ))}
        </div>
      )}
    </div>
  );
}

function PhoneScreen() {
  const { t, lang, go, authEmail, setAuthEmail, authIntent } = useApp();
  const isSignup = authIntent !== 'signin';
  const [val, setVal] = useState(authEmail || '');
  const [password, setPassword] = useState('');
  const [showPw, setShowPw] = useState(false);
  const [forgotOpen, setForgotOpen] = useState(false);

  const emailOk = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(val);
  const passwordOk = password.length >= 6;
  const ok = emailOk && passwordOk;

  const [signingIn, setSigningIn] = useState(false);
  const submit = () => {
    if (!ok || signingIn) return;
    setAuthEmail(val);
    if (isSignup) { go('otp'); return; } // registration must be verified by code before entering the app
    setSigningIn(true); setTimeout(() => go('app'), 900);
  };

  const title = isSignup ? t('em_pw_signup_title') : t('em_pw_title');
  const help  = isSignup ? t('em_pw_signup_help')  : t('em_pw_help');

  return (
    <div className="screen cream fade-in">
      <div className="pad-top" />
      <AuthHeader onBack={() => go('welcome')} step={1} />
      <div className="screen-scroll px-20">
        <h1 className="title" style={{ margin: '18px 0 8px' }}>{title}</h1>
        <p className="body" style={{ margin: '0 0 24px' }}>{help}</p>
        <div className="gap-16">
          <div className="field">
            <label>{t('em_label')}</label>
            <input className="b-input" type="email" inputMode="email" autoFocus dir="ltr" autoComplete="email"
              placeholder={t('em_ph')} value={val}
              onChange={e => setVal(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && submit()}
            />
          </div>
          <div className="field">
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
              <label style={{ fontSize: 'var(--pt-sm)', fontWeight: 600, color: 'var(--fg2)' }}>{t('pw_label')}</label>
              {!isSignup && (
                <button type="button" onClick={() => setForgotOpen(true)}
                  style={{ background: 'none', border: 'none', padding: 0, fontSize: 'var(--pt-xs)', fontWeight: 700, color: 'var(--app-accent)', cursor: 'pointer' }}>
                  {t('forgot_pw')}
                </button>
              )}
            </div>
            <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
              <input className="b-input" type={showPw ? 'text' : 'password'} dir="ltr" autoComplete={isSignup ? 'new-password' : 'current-password'}
                placeholder={t('pw_ph')} value={password}
                onChange={e => setPassword(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && submit()}
                style={{ paddingInlineEnd: 44 }}
              />
              <button type="button" onClick={() => setShowPw(s => !s)} aria-label={showPw ? t('pw_hide') : t('pw_show')}
                style={{ position: 'absolute', insetInlineEnd: 4, background: 'none', border: 'none', cursor: 'pointer', width: 36, height: 36, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--fg3)' }}>
                <Icon name={showPw ? 'eye-off' : 'eye'} size={17} />
              </button>
            </div>
          </div>
        </div>
      </div>
      <div className="flow-foot" style={{ flexDirection: 'column', gap: 14 }}>
        <DSProgressButton block variant="primary" loading={signingIn} disabled={!ok} onClick={submit}>
          {signingIn ? (lang === 'ar' ? 'جارٍ تسجيل الدخول…' : 'Signing in…') : (isSignup ? t('pw_signup') : t('pw_signin'))}
        </DSProgressButton>
        <TermsLine />
      </div>
      {forgotOpen && <ForgotPasswordSheet email={val} onClose={() => setForgotOpen(false)} />}
    </div>
  );
}

/* Forgot-password — OTP-verified reset: email → code → new password → done */
function ForgotPasswordSheet({ email, onClose }) {
  const { t } = useApp();
  const [step, setStep] = useState('email'); // email | code | newpass | done
  const [val, setVal] = useState(email || '');
  const [code, setCode] = useState('');
  const [secs, setSecs] = useState(28);
  const [pw1, setPw1] = useState('');
  const [pw2, setPw2] = useState('');
  const [showPw, setShowPw] = useState(false);
  const [busy, setBusy] = useState(false);
  const emailOk = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(val);
  const codeOk = code.length === 6;
  const pwOk = pw1.length >= 6 && pw1 === pw2;

  useEffect(() => {
    if (step !== 'code' || secs <= 0) return;
    const id = setTimeout(() => setSecs(s => s - 1), 1000);
    return () => clearTimeout(id);
  }, [step, secs]);

  const sendCode = () => { if (!emailOk || busy) return; setBusy(true); setTimeout(() => { setBusy(false); setStep('code'); setSecs(28); }, 800); };
  const verifyCode = () => { if (!codeOk || busy) return; setBusy(true); setTimeout(() => { setBusy(false); setStep('newpass'); }, 700); };
  useEffect(() => { if (step === 'code' && code.length === 6) { const id = setTimeout(verifyCode, 260); return () => clearTimeout(id); } }, [code]);
  const resetPw = () => { if (!pwOk || busy) return; setBusy(true); setTimeout(() => { setBusy(false); setStep('done'); }, 800); };

  const titles = { email: 'fp_title', code: 'otp_title', newpass: 'fp_newpass_title', done: 'fp_done_title' };

  return (
    <SettingsSheet title={t(titles[step])} onClose={onClose}>
      {step === 'email' && (
        <>
          <p className="body" style={{ margin: '0 0 20px', lineHeight: 1.6 }}>{t('fp_help')}</p>
          <div className="field" style={{ marginBottom: 20 }}>
            <label>{t('em_label')}</label>
            <input className="b-input" type="email" inputMode="email" dir="ltr" autoFocus autoComplete="email"
              placeholder={t('em_ph')} value={val} onChange={e => setVal(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && sendCode()} />
          </div>
          <DSProgressButton block variant="primary" loading={busy} disabled={!emailOk} onClick={sendCode}>{t('fp_send')}</DSProgressButton>
        </>
      )}
      {step === 'code' && (
        <>
          <p className="body" style={{ margin: '0 0 24px', lineHeight: 1.6 }}>
            {t('fp_code_help')} <b style={{ color: 'var(--fg1)', direction: 'ltr', display: 'inline-block' }}>{val}</b>
          </p>
          <OtpBoxes code={code} setCode={setCode} autoFocus />
          <div style={{ textAlign: 'center', margin: '20px 0 4px' }}>
            {secs > 0
              ? <span className="meta">{t('otp_in')} <b className="num">{secs}s</b></span>
              : <button className="b-btn b-btn-md b-btn-ghost" onClick={() => setSecs(28)}>{t('otp_resend')}</button>}
          </div>
          <DSProgressButton block variant="primary" loading={busy} disabled={!codeOk} onClick={verifyCode} style={{ marginTop: 16 }}>{t('fp_verify')}</DSProgressButton>
        </>
      )}
      {step === 'newpass' && (
        <>
          <p className="body" style={{ margin: '0 0 20px', lineHeight: 1.6 }}>{t('fp_newpass_help')}</p>
          <div className="gap-16">
            <div className="field">
              <label>{t('np_label')}</label>
              <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
                <input className="b-input" type={showPw ? 'text' : 'password'} dir="ltr" autoFocus autoComplete="new-password"
                  placeholder={t('pw_ph')} value={pw1} onChange={e => setPw1(e.target.value)} style={{ paddingInlineEnd: 44 }} />
                <button type="button" onClick={() => setShowPw(s => !s)} aria-label={showPw ? t('pw_hide') : t('pw_show')}
                  style={{ position: 'absolute', insetInlineEnd: 4, background: 'none', border: 'none', cursor: 'pointer', width: 36, height: 36, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--fg3)' }}>
                  <Icon name={showPw ? 'eye-off' : 'eye'} size={17} />
                </button>
              </div>
            </div>
            <div className="field">
              <label>{t('np2_label')}</label>
              <input className="b-input" type={showPw ? 'text' : 'password'} dir="ltr" autoComplete="new-password"
                placeholder={t('pw_ph')} value={pw2} onChange={e => setPw2(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && resetPw()} />
            </div>
            {pw2 && pw1 !== pw2 && <div className="meta" style={{ color: 'var(--balsm-danger)' }}>{t('np_mismatch')}</div>}
          </div>
          <DSProgressButton block variant="primary" loading={busy} disabled={!pwOk} onClick={resetPw} style={{ marginTop: 20 }}>{t('fp_reset')}</DSProgressButton>
        </>
      )}
      {step === 'done' && (
        <div style={{ textAlign: 'center', padding: '10px 4px 4px' }}>
          <div style={{ width: 56, height: 56, borderRadius: '50%', background: 'var(--petal-mint-50)', color: 'var(--petal-mint-600)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px' }}>
            <Icon name="check-circle-2" size={26} />
          </div>
          <p className="body" style={{ margin: '0 0 20px', lineHeight: 1.6 }}>{t('fp_done_help')}</p>
          <button className="b-btn b-btn-lg b-btn-primary b-btn--full" onClick={onClose}>{t('fp_done')}</button>
        </div>
      )}
    </SettingsSheet>
  );
}

/* Shared 6-digit OTP box row — used by registration verify, forgot-password, change-email */
function OtpBoxes({ code, setCode, autoFocus }) {
  const inputRef = useRef(null);
  useEffect(() => { autoFocus && inputRef.current && inputRef.current.focus(); }, []);
  return (
    <div className="otp-row" onClick={() => inputRef.current && inputRef.current.focus()} dir="ltr">
      {[0,1,2,3,4,5].map(i => (
        <div key={i} className={cx('otp-box', code[i] && 'filled', code.length === i && 'active')}>
          {code[i] || ''}
        </div>
      ))}
      <input
        ref={inputRef} inputMode="numeric" maxLength={6}
        value={code} onChange={e => setCode(e.target.value.replace(/\D/g, '').slice(0,6))}
        style={{ position: 'absolute', opacity: 0, pointerEvents: 'none', height: 0 }}
      />
    </div>
  );
}

/* ── Accept terms & privacy ─────────────────────────────────────────── */
function OtpScreen() {
  const { t, lang, go, authEmail, setProfileComplete } = useApp();
  const [code, setCode] = useState('');
  const [secs, setSecs] = useState(28);
  useEffect(() => {
    if (secs <= 0) return;
    const id = setTimeout(() => setSecs(s => s - 1), 1000);
    return () => clearTimeout(id);
  }, [secs]);
  const ok = code.length === 6;
  const [verifying, setVerifying] = useState(false);
  const submit = () => { if (!ok || verifying) return; setVerifying(true); setTimeout(() => { setProfileComplete(false); go('app'); }, 950); };
  // auto-submit on 6th digit
  useEffect(() => { if (code.length === 6) { const id = setTimeout(submit, 280); return () => clearTimeout(id); } }, [code]);
  return (
    <div className="screen cream fade-in">
      <div className="pad-top" />
      <AuthHeader onBack={() => go('phone')} step={2} />
      <div className="screen-scroll px-20">
        <h1 className="title mt-8" style={{ margin: '8px 0 8px' }}>{t('otp_title')}</h1>
        <p className="body" style={{ margin: '0 0 28px' }}>
          {t('em_otp_h')} <b style={{ color: 'var(--fg1)', direction: 'ltr', display: 'inline-block' }}>{authEmail}</b>
        </p>
        <OtpBoxes code={code} setCode={setCode} autoFocus />
        <div style={{ textAlign: 'center', marginTop: 24 }}>
          {secs > 0
            ? <span className="meta">{t('otp_in')} <b className="num">{secs}s</b></span>
            : <button className="b-btn b-btn-md b-btn-ghost" onClick={() => setSecs(28)}>{t('otp_resend')}</button>}
        </div>
      </div>
      <div className="flow-foot">
        <DSProgressButton block variant="primary" loading={verifying} disabled={!ok} onClick={submit}>
          {verifying ? (lang === 'ar' ? 'جارٍ التحقق…' : 'Verifying…') : t('verify')}
        </DSProgressButton>
      </div>
    </div>
  );
}

/* Change email — Security settings, OTP-verified before the new address is committed */
function ChangeEmailSheet({ onClose }) {
  const { t, authEmail, setAuthEmail } = useApp();
  const [step, setStep] = useState('email'); // email | code | done
  const [val, setVal] = useState('');
  const [code, setCode] = useState('');
  const [secs, setSecs] = useState(28);
  const [busy, setBusy] = useState(false);
  const emailOk = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(val) && val !== authEmail;
  const codeOk = code.length === 6;

  useEffect(() => {
    if (step !== 'code' || secs <= 0) return;
    const id = setTimeout(() => setSecs(s => s - 1), 1000);
    return () => clearTimeout(id);
  }, [step, secs]);

  const sendCode = () => { if (!emailOk || busy) return; setBusy(true); setTimeout(() => { setBusy(false); setStep('code'); setSecs(28); }, 800); };
  const verify = () => { if (!codeOk || busy) return; setBusy(true); setTimeout(() => { setBusy(false); setAuthEmail(val); setStep('done'); }, 700); };
  useEffect(() => { if (step === 'code' && code.length === 6) { const id = setTimeout(verify, 260); return () => clearTimeout(id); } }, [code]);

  const titles = { email: 'ce_title', code: 'otp_title', done: 'ce_done_title' };
  return (
    <SettingsSheet title={t(titles[step])} onClose={onClose}>
      {step === 'email' && (
        <>
          <div className="field" style={{ marginBottom: 14 }}>
            <label>{t('ce_current')}</label>
            <div className="b-input" style={{ display: 'flex', alignItems: 'center', color: 'var(--fg3)', direction: 'ltr' }}>{authEmail}</div>
          </div>
          <div className="field" style={{ marginBottom: 20 }}>
            <label>{t('ce_new_label')}</label>
            <input className="b-input" type="email" inputMode="email" dir="ltr" autoFocus autoComplete="email"
              placeholder={t('em_ph')} value={val} onChange={e => setVal(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && sendCode()} />
          </div>
          <DSProgressButton block variant="primary" loading={busy} disabled={!emailOk} onClick={sendCode}>{t('ce_send')}</DSProgressButton>
        </>
      )}
      {step === 'code' && (
        <>
          <p className="body" style={{ margin: '0 0 24px', lineHeight: 1.6 }}>
            {t('ce_code_help')} <b style={{ color: 'var(--fg1)', direction: 'ltr', display: 'inline-block' }}>{val}</b>
          </p>
          <OtpBoxes code={code} setCode={setCode} autoFocus />
          <div style={{ textAlign: 'center', margin: '20px 0 4px' }}>
            {secs > 0
              ? <span className="meta">{t('otp_in')} <b className="num">{secs}s</b></span>
              : <button className="b-btn b-btn-md b-btn-ghost" onClick={() => setSecs(28)}>{t('otp_resend')}</button>}
          </div>
          <DSProgressButton block variant="primary" loading={busy} disabled={!codeOk} onClick={verify} style={{ marginTop: 16 }}>{t('ce_verify')}</DSProgressButton>
        </>
      )}
      {step === 'done' && (
        <div style={{ textAlign: 'center', padding: '10px 4px 4px' }}>
          <div style={{ width: 56, height: 56, borderRadius: '50%', background: 'var(--petal-mint-50)', color: 'var(--petal-mint-600)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px' }}>
            <Icon name="check-circle-2" size={26} />
          </div>
          <p className="body" style={{ margin: '0 0 4px', lineHeight: 1.6 }}>
            {t('ce_done_help')} <b style={{ color: 'var(--fg1)', direction: 'ltr', display: 'inline-block' }}>{val}</b>
          </p>
          <button className="b-btn b-btn-lg b-btn-primary b-btn--full" style={{ marginTop: 16 }} onClick={onClose}>{t('ce_done_btn')}</button>
        </div>
      )}
    </SettingsSheet>
  );
}

/* Username availability hook — shared by ProfileSetup & PersonalDetails */
const TAKEN_HANDLES = new Set(['layla','hassan','balsm','admin','doctor','health','user','support','test','omar','sara','mona','ahmed']);
function useUsername(initial) {
  const [handle, setHandleRaw] = useState(initial || '');
  const [status, setStatus]    = useState('idle'); // idle | checking | available | taken | invalid
  const timerRef = useRef(null);

  const isValid = (v) => /^[a-z0-9_]{3,20}$/.test(v);

  const setHandle = (raw) => {
    const v = raw.toLowerCase().replace(/[^a-z0-9_]/g, '');
    setHandleRaw(v);
    if (!v) { setStatus('idle'); return; }
    if (!isValid(v)) { setStatus('invalid'); return; }
    setStatus('checking');
    clearTimeout(timerRef.current);
    timerRef.current = setTimeout(() => {
      setStatus(TAKEN_HANDLES.has(v) ? 'taken' : 'available');
    }, 700);
  };

  return [handle, setHandle, status];
}

function UsernameField({ handle, setHandle, status, t, lang }) {
  const icon = { idle: null, checking: 'loader', available: 'check-circle-2', taken: 'x-circle', invalid: 'alert-circle' }[status];
  const col  = { idle: 'var(--fg4)', checking: 'var(--fg3)', available: 'var(--petal-mint-600)', taken: 'var(--balsm-danger)', invalid: 'var(--balsm-sun-500)' }[status];
  const msg  = { idle: '', checking: t('un_checking'), available: t('un_avail'), taken: t('un_taken'), invalid: t('un_invalid') }[status];
  return (
    <div className="field">
      <label>{t('un_label')}</label>
      <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
        <span style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', fontSize: 'var(--pt-sm)', fontWeight: 700, color: 'var(--fg3)', fontFamily: 'var(--font-mono)', userSelect: 'none', zIndex: 1, lineHeight: 1, pointerEvents: 'none' }}>@</span>
        <input className="b-input num" dir="ltr" placeholder={t('un_ph')} value={handle}
          onChange={e => setHandle(e.target.value)}
          style={{ paddingLeft: 28, paddingRight: icon ? 36 : 12 }} />
        {icon && (
          <span style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', display: 'flex', alignItems: 'center' }}>
            <Icon name={icon} size={17} style={{ color: col, animation: status === 'checking' ? 'spin 0.9s linear infinite' : 'none' }} />
          </span>
        )}
      </div>
      {msg && <div style={{ fontSize: 'var(--pt-xs)', color: col, marginTop: 4, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 5 }}>{msg}</div>}
    </div>
  );
}

/* Profile setup — retired from the signup flow (profile is completed later from the Profile tab). Kept for reference. */
function ProfileSetupScreen() {
  const { t, lang, go } = useApp();
  const [firstName, setFirstName] = useState('');
  const [lastName,  setLastName]  = useState('');
  const name = (firstName + ' ' + lastName).trim();
  const [dob, setDob]       = useState(''); // ISO yyyy-mm-dd
  const [dobOpen, setDobOpen] = useState(false);
  const [gender, setGender] = useState('female');

  // Auto-suggest handle from name
  const suggest = (f, l) => (f + (l ? '_' + l : '')).toLowerCase().replace(/[^a-z0-9_]/g, '').slice(0, 20);
  const [handle, setHandle, unStatus] = useUsername('');

  // When name changes and handle is still empty/was auto-suggested, update
  const prevSuggest = useRef('');
  useEffect(() => {
    const s = suggest(firstName, lastName);
    if (handle === '' || handle === prevSuggest.current) {
      prevSuggest.current = s;
      if (s.length >= 3) setHandle(s);
    }
  }, [firstName, lastName]);

  const ok = name.trim().length > 1 && (unStatus === 'available' || unStatus === 'idle');
  const [creating, setCreating] = useState(false);
  const createAccount = () => { if (!ok || creating) return; setCreating(true); setTimeout(() => go('app'), 1150); };

  return (
    <div className="screen cream fade-in">
      <div className="pad-top" />
      <AuthHeader onBack={() => go('otp')} step={3} />
      <div className="screen-scroll px-20" style={{ paddingBottom: 12 }}>
        <h1 className="title mt-8" style={{ margin: '8px 0 8px' }}>{t('pf_title')}</h1>
        <p className="body" style={{ margin: '0 0 24px' }}>{t('pf_help')}</p>
        <div className="gap-16">
          <div style={{ display: 'flex', gap: 12 }}>
            <div className="field" style={{ flex: 1 }}>
              <label>{t('pf_fname')}</label>
              <input className="b-input" placeholder={t('pf_fname_ph')} value={firstName} onChange={e => setFirstName(e.target.value)} />
            </div>
            <div className="field" style={{ flex: 1 }}>
              <label>{t('pf_lname')}</label>
              <input className="b-input" placeholder={t('pf_lname_ph')} value={lastName} onChange={e => setLastName(e.target.value)} />
            </div>
          </div>
          <div className="field">
            <UsernameField handle={handle} setHandle={setHandle} status={unStatus} t={t} lang={lang} />
            {handle && (
              <div style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg3)', marginTop: 6, display: 'flex', alignItems: 'center', gap: 5 }}>
                <Icon name="link" size={12} />
                <span dir="ltr" style={{ fontFamily: 'var(--font-mono)', color: 'var(--fg3)' }}>balsm.health/@{handle}</span>
              </div>
            )}
          </div>
          <div className="field">
            <label>{t('pf_dob')}</label>
            <button type="button" className="b-input" onClick={() => setDobOpen(true)}
              style={{ display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer', textAlign: 'start' }}>
              <Icon name="calendar" size={17} style={{ color: 'var(--fg3)', flexShrink: 0 }} />
              <span className={dob ? 'num' : ''} style={{ flex: 1, color: dob ? 'var(--fg1)' : 'var(--fg3)', direction: 'ltr', textAlign: 'start' }}>
                {dob ? fmtDob(dob, lang) : (lang === 'ar' ? 'يوم / شهر / سنة' : 'DD / MM / YYYY')}
              </span>
              <Icon name="chevron-down" size={15} style={{ color: 'var(--fg3)', flexShrink: 0 }} />
            </button>
          </div>
          <div className="field">
            <label>{t('pf_gender')}</label>
            <div className="segmented">
              <button className={cx(gender === 'female' && 'active')} onClick={() => setGender('female')}>{t('pf_female')}</button>
              <button className={cx(gender === 'male' && 'active')} onClick={() => setGender('male')}>{t('pf_male')}</button>
            </div>
          </div>
        </div>
      </div>
      <div className="flow-foot" style={{ flexDirection: 'column', gap: 12 }}>
        <DSProgressButton block variant="primary" loading={creating} disabled={!ok} onClick={createAccount}>
          {creating ? (lang === 'ar' ? 'جارٍ إنشاء حسابك…' : 'Creating your account…') : t('pf_create')}
        </DSProgressButton>
        <p className="meta" style={{ textAlign: 'center', margin: 0, display: 'flex', gap: 6, justifyContent: 'center', alignItems: 'center' }}>
          <Icon name="shield-check" size={14} />{t('pf_secure')}
        </p>
      </div>
      {dobOpen && (
        <DobPicker lang={lang} value={dob}
          onPick={iso => setDob(iso)} onClose={() => setDobOpen(false)} />
      )}
    </div>
  );
}

/* ── Date-of-birth calendar picker ──────────────────────── */
function fmtDob(iso, lang) {
  const [y, m, d] = iso.split('-').map(Number);
  const months = lang === 'ar'
    ? ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر']
    : ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return `${d} ${months[m - 1]} ${y}`;
}

function DobPicker({ onClose, onPick, value, lang, title, initialYearsBack = 25 }) {
  const today = new Date();
  const init = value ? new Date(value + 'T00:00:00') : new Date(today.getFullYear() - initialYearsBack, today.getMonth(), 1);
  const [view, setView] = useState({ y: init.getFullYear(), m: init.getMonth() });
  const [sel, setSel] = useState(value || '');
  const [mode, setMode] = useState('day'); // 'day' | 'year'

  const months = lang === 'ar'
    ? ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر']
    : ['January','February','March','April','May','June','July','August','September','October','November','December'];
  const wd = lang === 'ar' ? ['أحد','إثن','ثلا','أرب','خمي','جمع','سبت'] : ['Su','Mo','Tu','We','Th','Fr','Sa'];

  const firstDay = new Date(view.y, view.m, 1).getDay();
  const daysIn = new Date(view.y, view.m + 1, 0).getDate();
  const cells = [];
  for (let i = 0; i < firstDay; i++) cells.push(null);
  for (let d = 1; d <= daysIn; d++) cells.push(d);

  const prevMonth = () => setView(v => v.m === 0 ? { y: v.y - 1, m: 11 } : { y: v.y, m: v.m - 1 });
  const nextMonth = () => setView(v => v.m === 11 ? { y: v.y + 1, m: 0 } : { y: v.y, m: v.m + 1 });

  const pick = (d) => {
    const iso = `${view.y}-${String(view.m + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    setSel(iso);
  };
  const isFuture = (d) => new Date(view.y, view.m, d) > today;
  const years = []; for (let y = today.getFullYear(); y >= 1920; y--) years.push(y);

  return (
    <>
      <style>{`@keyframes dobUp{from{transform:translateY(110%)}to{transform:none}}`}</style>
      <div className="app-scrim" onClick={onClose} style={{ position: 'absolute', inset: 0, zIndex: 60, background: 'rgba(20,32,43,0.36)' }} />
      <div className="app-sheet" style={{
        position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 61,
        background: '#fff', borderRadius: '20px 20px 0 0',
        display: 'flex', flexDirection: 'column', maxHeight: '82%',
        animation: 'dobUp 0.3s cubic-bezier(0.16,1,0.3,1) both',
      }}>
        <div style={{ padding: '10px 20px 0', flexShrink: 0 }}>
          <div className="sheet-grab" style={{ margin: '0 auto 12px' }} />
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: 14 }}>
            <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-lg)', color: 'var(--fg1)' }}>
              {title || (lang === 'ar' ? 'تاريخ الميلاد' : 'Date of birth')}
            </div>
            <button className="round-btn ghost" onClick={onClose}><Icon name="x" size={17} /></button>
          </div>
        </div>

        <div style={{ padding: '0 20px 8px', overflowY: 'auto' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
            <button className="round-btn ghost" onClick={prevMonth} aria-label="Previous month">
              <Icon name={lang === 'ar' ? 'chevron-right' : 'chevron-left'} size={18} />
            </button>
            <button onClick={() => setMode(mode === 'year' ? 'day' : 'year')}
              style={{ border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 6,
                fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>
              {months[view.m]} {view.y}
              <Icon name="chevron-down" size={15} style={{ color: 'var(--fg3)' }} />
            </button>
            <button className="round-btn ghost" onClick={nextMonth} aria-label="Next month">
              <Icon name={lang === 'ar' ? 'chevron-left' : 'chevron-right'} size={18} />
            </button>
          </div>

          {mode === 'year' ? (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8, paddingBottom: 12 }}>
              {years.map(y => (
                <button key={y} onClick={() => { setView(v => ({ ...v, y })); setMode('day'); }}
                  className="num" style={{
                    height: 42, borderRadius: 12, cursor: 'pointer',
                    border: '1.5px solid ' + (y === view.y ? 'var(--app-accent)' : 'var(--balsm-border)'),
                    background: y === view.y ? 'var(--app-accent)' : '#fff',
                    color: y === view.y ? '#fff' : 'var(--fg1)', fontWeight: 600, fontSize: 'var(--pt-sm)',
                  }}>{y}</button>
              ))}
            </div>
          ) : (
            <>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 2, marginBottom: 6 }}>
                {wd.map((w, i) => (
                  <div key={i} style={{ textAlign: 'center', fontSize: 'var(--pt-xs)', fontWeight: 700, color: 'var(--fg3)' }}>{w}</div>
                ))}
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 2 }}>
                {cells.map((d, i) => {
                  if (d === null) return <div key={i} />;
                  const iso = `${view.y}-${String(view.m + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
                  const active = sel === iso;
                  const disabled = isFuture(d);
                  return (
                    <button key={i} disabled={disabled} onClick={() => pick(d)}
                      className="num" style={{
                        aspectRatio: '1', borderRadius: '50%', border: 'none', cursor: disabled ? 'default' : 'pointer',
                        background: active ? 'var(--app-accent)' : 'transparent',
                        color: disabled ? 'var(--balsm-ink-200)' : active ? '#fff' : 'var(--fg1)',
                        fontWeight: active ? 700 : 500, fontSize: 'var(--pt-sm)',
                      }}>{d}</button>
                  );
                })}
              </div>
            </>
          )}
        </div>

        <div style={{ padding: '12px 20px calc(env(safe-area-inset-bottom, 0px) + 20px)', flexShrink: 0, borderTop: '1px solid var(--balsm-ink-50)' }}>
          <button className={cx('b-btn b-btn-lg b-btn-primary b-btn--full', !sel && 'is-disabled')}
            onClick={() => { if (sel) { onPick(sel); onClose(); } }}>
            {sel ? (lang === 'ar' ? 'تأكيد' : 'Confirm') : (lang === 'ar' ? 'اختر تاريخاً' : 'Select a date')}
          </button>
        </div>
      </div>
    </>
  );
}

Object.assign(window, { MoodFace, SplashScreen, WelcomeScreen, PhoneScreen, OtpScreen, OtpBoxes, ProfileSetupScreen, UsernameField, useUsername, AppleIcon, GoogleIcon, TAKEN_HANDLES, DobPicker, fmtDob, ForgotPasswordSheet, ChangeEmailSheet });
