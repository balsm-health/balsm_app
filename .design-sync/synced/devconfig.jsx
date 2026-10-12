/* devconfig.jsx — Developer Config overlay
   Triggered: device shake · Ctrl+Shift+D · floating DEV button · companion panel
   Sections:  Environment switcher · Console log viewer · Bug reporter          */

/* ─── Log interceptor — runs once at script load ──────────────────────────── */
const _DLOGS  = [];
const _DCBS   = new Set();

(function patchConsole() {
  ['log', 'info', 'warn', 'error'].forEach(level => {
    const orig = console[level].bind(console);
    console[level] = (...args) => {
      const msg = args.map(a => {
        if (a == null) return String(a);
        try { return typeof a === 'object' ? JSON.stringify(a) : String(a); } catch { return '[Object]'; }
      }).join(' ');
      _DLOGS.push({ level, msg, ts: new Date() });
      if (_DLOGS.length > 600) _DLOGS.splice(0, 60);
      _DCBS.forEach(fn => fn());
      orig(...args);
    };
  });
  window.addEventListener('error', e => {
    _DLOGS.push({ level: 'error', msg: `Uncaught: ${e.message} (${e.filename}:${e.lineno})`, ts: new Date() });
    _DCBS.forEach(fn => fn());
  });
  window.addEventListener('unhandledrejection', e => {
    _DLOGS.push({ level: 'error', msg: `UnhandledRejection: ${e.reason}`, ts: new Date() });
    _DCBS.forEach(fn => fn());
  });
})();

function useDevLogs() {
  const [, tick] = useState(0);
  useEffect(() => {
    const fn = () => tick(n => n + 1);
    _DCBS.add(fn);
    return () => _DCBS.delete(fn);
  }, []);
  return _DLOGS; /* mutable ref — re-render is driven by tick */
}

/* ─── Constants ───────────────────────────────────────────────────────────── */
const DC_ENVS = [
  { id: 'local',   label: 'Local',      url: 'http://localhost:3000',            dot: '#3FC366', bg: '#E8F9EE', fg: '#1A6033' },
  { id: 'dev',     label: 'Dev',        url: 'https://api.dev.balsm.health',     dot: '#1283FF', bg: '#E4F0FF', fg: '#08407A' },
  { id: 'staging', label: 'Staging',    url: 'https://api.staging.balsm.health', dot: '#E5B428', bg: '#FDF5DC', fg: '#7A5A0F' },
  { id: 'prod',    label: 'Production', url: 'https://api.balsm.health',         dot: '#D44A3C', bg: '#FBEBE7', fg: '#7A2A20' },
];

const DC_FLAGS = [
  { id: 'offline',  label: 'Force offline mode',  desc: 'Simulate no network connectivity'    },
  { id: 'slow_net', label: 'Throttle to 3G',       desc: 'Limit API throughput to 400 kbps'   },
  { id: 'mock_api', label: 'Mock API responses',   desc: 'Serve fixture data instead of live' },
  { id: 'rtl_dbg',  label: 'RTL debug overlay',    desc: 'Highlight directionality issues'    },
];

const DC_SELS = [
  ['low', 'Low'], ['medium', 'Medium'], ['high', 'High'], ['critical', 'Critical'],
];

/* ─── DevConfigOverlay ─────────────────────────────────────────────────────── */
function DevConfigOverlay({ onClose, screenshot }) {
  const [tab,       setTab]       = useState('env');
  const [envId,     setEnvId]     = useState(() => localStorage.getItem('balsm_dev_env') || 'dev');
  const [confProd,     setConfProd]     = useState(false);
  const [savedEnvs,    setSavedEnvs]    = useState(() => { try { return JSON.parse(localStorage.getItem('balsm_dev_saved_envs') || '[]'); } catch { return []; } });
  const [addingCustom, setAddingCustom] = useState(false);
  const [editingId,    setEditingId]    = useState(null);
  const [newName,      setNewName]      = useState('');
  const [newUrl,       setNewUrl]       = useState('');
  const [editName,     setEditName]     = useState('');
  const [editUrl,      setEditUrl]      = useState('');
  const [encKey]                        = useState(() => {
    let k = localStorage.getItem('balsm_dev_log_key');
    if (!k) { k = Array.from(crypto.getRandomValues(new Uint8Array(20))).map(b => b.toString(16).padStart(2,'0')).join(''); localStorage.setItem('balsm_dev_log_key', k); }
    return k;
  });
  const [sendStatus,   setSendStatus]   = useState(null); /* null|'sending'|'sent'|'error' */

  const [flags,     setFlags]     = useState(() => {
    const out = {};
    DC_FLAGS.forEach(f => { out[f.id] = localStorage.getItem(`balsm_flag_${f.id}`) === '1'; });
    return out;
  });
  const [logFilter, setLogFilter] = useState('all');
  const [logSearch, setLogSearch] = useState('');
  const [bugTitle,  setBugTitle]  = useState('');
  const [bugDesc,   setBugDesc]   = useState('');
  const [bugSev,    setBugSev]    = useState('medium');
  const [copied,    setCopied]    = useState(false);
  const logsEl   = useRef(null);
  const allLogs  = useDevLogs();
  const savedEnv = savedEnvs.find(e => e.id === envId);
  const envBase  = DC_ENVS.find(e => e.id === envId) || DC_ENVS[1];
  const env      = savedEnv ? { id: savedEnv.id, label: savedEnv.name, url: savedEnv.url, dot: 'var(--balsm-ink-600)', bg: '#F4F3EC', fg: 'var(--balsm-ink-800)' } : envBase;
  const errCount = allLogs.filter(l => l.level === 'error').length;

  const filteredLogs = allLogs.filter(l =>
    (logFilter === 'all' || l.level === logFilter) &&
    (!logSearch || l.msg.toLowerCase().includes(logSearch.toLowerCase()))
  );

  /* auto-scroll log terminal */
  useEffect(() => {
    if (tab === 'logs' && logsEl.current)
      logsEl.current.scrollTop = logsEl.current.scrollHeight;
  });

  /* log the open event once */
  useEffect(() => { console.info('[DevConfig] overlay opened'); }, []);

  const pickEnv = id => {
    if (id === 'prod' && envId !== 'prod') { setConfProd(true); return; }
    localStorage.setItem('balsm_dev_env', id);
    setEnvId(id);
    setConfProd(false);
    console.info(`[DevConfig] env → ${id}`);
  };

  const addSavedEnv = () => {
    if (!newName.trim() || !newUrl.trim()) return;
    const id = `saved_${Date.now()}`;
    const next = [...savedEnvs, { id, name: newName.trim(), url: newUrl.trim() }];
    setSavedEnvs(next);
    localStorage.setItem('balsm_dev_saved_envs', JSON.stringify(next));
    setNewName(''); setNewUrl(''); setAddingCustom(false);
    pickEnv(id);
  };

  const deleteSavedEnv = (id, ev) => {
    ev?.stopPropagation();
    const next = savedEnvs.filter(e => e.id !== id);
    setSavedEnvs(next);
    localStorage.setItem('balsm_dev_saved_envs', JSON.stringify(next));
    if (envId === id) { localStorage.setItem('balsm_dev_env', 'dev'); setEnvId('dev'); }
  };

  const commitEdit = (id) => {
    if (!editName.trim() || !editUrl.trim()) return;
    const next = savedEnvs.map(e => e.id === id ? { ...e, name: editName.trim(), url: editUrl.trim() } : e);
    setSavedEnvs(next);
    localStorage.setItem('balsm_dev_saved_envs', JSON.stringify(next));
    setEditingId(null);
  };

  const saveEncryptedLogs = async () => {
    const payload = { meta: { ts: new Date().toISOString(), env: env.label, url: env.url }, logs: allLogs.map(l => ({ level: l.level, msg: l.msg, ts: l.ts.toISOString() })) };
    try {
      const raw = new TextEncoder().encode(encKey.padEnd(32,'0').slice(0,32));
      const ck  = await crypto.subtle.importKey('raw', raw, 'AES-GCM', false, ['encrypt']);
      const iv  = crypto.getRandomValues(new Uint8Array(12));
      const enc = await crypto.subtle.encrypt({ name:'AES-GCM', iv }, ck, new TextEncoder().encode(JSON.stringify(payload)));
      const bundle = { v:1, alg:'AES-256-GCM', iv: btoa(String.fromCharCode(...iv)), data: btoa(String.fromCharCode(...new Uint8Array(enc))), keyHint: encKey.slice(0,8)+'…' };
      const a = Object.assign(document.createElement('a'), { href: URL.createObjectURL(new Blob([JSON.stringify(bundle,null,2)], {type:'application/json'})), download: `balsm-logs-${Date.now()}.enc.json` });
      a.click();
    } catch(err) { console.error('[DevConfig] encrypt failed:', err.message); }
  };

  const sendToServer = async () => {
    if (!env.url) return;
    setSendStatus('sending');
    const payload = { meta: { ts: new Date().toISOString(), env: env.label }, logs: allLogs.map(l => ({ level: l.level, msg: l.msg, ts: l.ts.toISOString() })) };
    try {
      const res = await fetch(`${env.url}/api/dev/logs`, { method:'POST', headers:{ 'Content-Type':'application/json', 'X-Dev-Key': encKey }, body: JSON.stringify(payload) });
      setSendStatus(res.ok ? 'sent' : 'error');
    } catch { setSendStatus('error'); }
    setTimeout(() => setSendStatus(null), 3200);
  };

  const commitProd = () => { setConfProd(false); pickEnv('prod'); };

  const toggleFlag = id => {
    const next = !flags[id];
    setFlags(p => ({ ...p, [id]: next }));
    localStorage.setItem(`balsm_flag_${id}`, next ? '1' : '0');
    console.info(`[DevConfig] flag ${id} → ${next}`);
  };

  const exportLogs = () => {
    const text = allLogs.map(l =>
      `${l.ts.toISOString()} [${l.level.toUpperCase().padEnd(5)}] ${l.msg}`
    ).join('\n');
    const a = Object.assign(document.createElement('a'), {
      href: URL.createObjectURL(new Blob([text], { type: 'text/plain' })),
      download: `balsm-${Date.now()}.log`,
    });
    a.click();
  };

  const clearLogs = () => { _DLOGS.splice(0); _DCBS.forEach(fn => fn()); };

  const copyReport = () => {
    const lines = [
      '# Bug Report — Balsm Patient App',
      `Date:     ${new Date().toISOString()}`,
      `Env:      ${env.label} (${env.url})`,
      `Severity: ${bugSev}`,
      `Title:    ${bugTitle || '(untitled)'}`,
      '',
      '## Description',
      bugDesc || '(none)',
      '',
      '## Last 20 log entries',
      ...allLogs.slice(-20).map(l => `[${l.level.toUpperCase().padEnd(5)}] ${l.msg}`),
      '',
      '## Context',
      `UA:       ${navigator.userAgent}`,
      `Viewport: ${window.innerWidth}×${window.innerHeight}`,
      `URL:      ${location.href}`,
    ].join('\n');
    navigator.clipboard?.writeText(lines).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2500);
    });
  };

  /* ── Render ───────────────────────────────────────────────────────────── */
  return (
    <>
      <style>{`
        @keyframes dcUp { from { transform:translateY(100%) } to { transform:none } }
        .dc-tab { flex:1; min-width:0; height:40px; border:0; background:transparent;
          font-family:var(--font-body); font-size:13px; font-weight:600; color:var(--fg3);
          cursor:pointer; border-bottom:2.5px solid transparent;
          transition:color 150ms, border-color 150ms;
          display:flex; align-items:center; justify-content:center; gap:5px; white-space:nowrap; padding:0; }
        .dc-tab.on { color:var(--app-accent); border-bottom-color:var(--app-accent); }
        .dc-env { display:flex; align-items:center; gap:13px; padding:13px 14px;
          border-radius:var(--radius-lg); border:1.5px solid; cursor:pointer; transition:all 150ms; }
        .dc-tog { width:42px; height:24px; border-radius:999px; position:relative; cursor:pointer;
          flex-shrink:0; transition:background 200ms; }
        .dc-tog-k { position:absolute; top:2px; width:20px; height:20px; border-radius:50%;
          background:#fff; box-shadow:0 1px 3px rgba(0,0,0,.25); transition:left 180ms var(--ease-out); }
        .dc-log { font-family:var(--font-mono); font-size:10.5px; line-height:1.7; padding:1px 0;
          border-bottom:1px solid rgba(255,255,255,.05); word-break:break-all; white-space:pre-wrap; }
        .dc-sev { flex:1; height:36px; border:1px solid var(--balsm-border);
          border-radius:var(--radius-sm); background:#fff; font-family:var(--font-body);
          font-size:12px; font-weight:600; color:var(--fg3); cursor:pointer; transition:all 150ms; }
        .dc-sev.on { background:var(--balsm-ink-900); color:#fff; border-color:var(--balsm-ink-900); }
        .dc-lbtn { height:26px; padding:0 10px; border-radius:999px; border:1px solid var(--balsm-border);
          font-family:var(--font-mono); font-size:11px; font-weight:600; cursor:pointer; transition:all 150ms; }
      `}</style>

      {/* Backdrop */}
      <div onClick={onClose} style={{ position:'absolute', inset:0, zIndex:50,
        background:'rgba(26,26,23,.55)', backdropFilter:'blur(4px)' }} />

      {/* Sheet */}
      <div style={{ position:'absolute', bottom:0, left:0, right:0, zIndex:51,
        background:'#FAFAF7', borderRadius:'20px 20px 0 0',
        height:'90%', display:'flex', flexDirection:'column',
        animation:'dcUp .3s cubic-bezier(0.16,1,0.3,1) both' }}>

        {/* Drag handle */}
        <div style={{ paddingTop:10, flexShrink:0, display:'flex', justifyContent:'center' }}>
          <div style={{ width:38, height:4, borderRadius:999, background:'var(--balsm-ink-200)' }} />
        </div>

        {/* Header */}
        <div style={{ padding:'10px 20px 0', flexShrink:0 }}>
          <div style={{ display:'flex', alignItems:'center', gap:12, paddingBottom:12 }}>
            <div style={{ width:38, height:38, borderRadius:10, background:'#1A1A17',
              display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}>
              <Icon name="terminal" size={18} stroke={2} style={{ color:'#A3FF6E' }} />
            </div>
            <div style={{ flex:1 }}>
              <div style={{ fontFamily:'var(--font-display)', fontWeight:700, fontSize:17,
                color:'var(--fg1)', lineHeight:1 }}>Dev Config</div>
              <div style={{ display:'flex', alignItems:'center', gap:6, marginTop:3 }}>
                <span style={{ fontFamily:'var(--font-mono)', fontSize:10, color:'var(--fg4)' }}>
                  balsm-patient · internal
                </span>
                <span style={{ display:'inline-flex', alignItems:'center', gap:4,
                  padding:'1px 8px', borderRadius:999,
                  background:env.bg, fontSize:10, fontWeight:700, color:env.fg }}>
                  <span style={{ width:6, height:6, borderRadius:'50%',
                    background:env.dot, display:'inline-block' }} />
                  {env.label}
                </span>
              </div>
            </div>
            <button className="round-btn ghost" onClick={onClose}>
              <Icon name="x" size={18} />
            </button>
          </div>

          {/* Tab strip */}
          <div style={{ display:'flex', margin:'0 -20px',
            borderTop:'1px solid var(--balsm-ink-100)',
            borderBottom:'1px solid var(--balsm-ink-100)',
            background:'#fff', padding:'0 20px' }}>
            {[
              ['env',  'server',      'Environment'],
              ['logs', 'scroll-text', errCount > 0 ? `Logs · ${errCount} err` : 'Logs'],
              ['bug',  'bug',         'Report bug'],
            ].map(([id, icon, label]) => (
              <button key={id} className={`dc-tab${tab===id?' on':''}`} onClick={() => setTab(id)}>
                <Icon name={icon} size={13} />{label}
              </button>
            ))}
          </div>
        </div>

        {/* Scrollable body */}
        <div style={{ flex:1, overflowY:'auto', padding:'16px 20px 52px' }}>

          {/* ── ENVIRONMENT ─────────────────────────────────────────────── */}
          {tab==='env' && <>
            <div className="eyebrow-l" style={{ marginBottom:10 }}>Backend</div>
            <div style={{ display:'flex', flexDirection:'column', gap:8 }}>
              {/* ── Presets ── */}
              {DC_ENVS.map(e => {
                const on = envId === e.id;
                return (
                  <div key={e.id} className="dc-env"
                    style={{ borderColor: on ? e.dot : 'var(--balsm-border)', background: on ? e.bg : '#fff' }}
                    onClick={() => pickEnv(e.id)}>
                    <div style={{ width:10, height:10, borderRadius:'50%', background:e.dot, flexShrink:0,
                      boxShadow: on ? `0 0 0 3px ${e.bg}, 0 0 0 5px ${e.dot}` : 'none', transition:'box-shadow 200ms' }} />
                    <div style={{ flex:1, minWidth:0 }}>
                      <div style={{ display:'flex', alignItems:'center', gap:7 }}>
                        <span style={{ fontWeight:700, fontSize:14, color: on ? e.fg : 'var(--fg1)' }}>{e.label}</span>
                        {e.id==='prod' && <span style={{ fontSize:9, fontWeight:800, letterSpacing:'0.06em', padding:'1px 5px', borderRadius:3, background:'#FBEBE7', color:'#D44A3C' }}>LIVE</span>}
                      </div>
                      <div style={{ fontFamily:'var(--font-mono)', fontSize:11, color: on ? e.fg : 'var(--fg4)', marginTop:1, opacity:.85, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>{e.url}</div>
                    </div>
                    {on && <Icon name="check-circle-2" size={19} style={{ color:e.dot, flexShrink:0 }} />}
                  </div>
                );
              })}

              {/* ── Saved custom envs ── */}
              {savedEnvs.length > 0 && (
                <>
                  <div style={{ fontSize:10, fontWeight:700, letterSpacing:'0.14em', textTransform:'uppercase',
                    color:'var(--fg4)', padding:'4px 2px 6px', marginTop:4,
                    borderTop:'1px solid var(--balsm-ink-100)' }}>Saved</div>
                  {savedEnvs.map(se => {
                    const on = envId === se.id;
                    return (
                      <div key={se.id}>
                        <div className="dc-env"
                          style={{ borderColor: on ? 'var(--balsm-ink-600)' : 'var(--balsm-border)', background: on ? '#F4F3EC' : '#fff' }}
                          onClick={() => pickEnv(se.id)}>
                          <div style={{ width:10, height:10, borderRadius:'50%', background:'var(--balsm-ink-600)', flexShrink:0,
                            boxShadow: on ? '0 0 0 3px #F4F3EC, 0 0 0 5px var(--balsm-ink-600)' : 'none', transition:'box-shadow 200ms' }} />
                          <div style={{ flex:1, minWidth:0 }}>
                            <span style={{ fontWeight:700, fontSize:14, color: on ? 'var(--balsm-ink-800)' : 'var(--fg1)' }}>{se.name}</span>
                            <div style={{ fontFamily:'var(--font-mono)', fontSize:11, color: on ? 'var(--balsm-ink-600)' : 'var(--fg4)', marginTop:1, opacity:.85, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>{se.url}</div>
                          </div>
                          <div style={{ display:'flex', alignItems:'center', gap:4, flexShrink:0 }}>
                            {on && <Icon name="check-circle-2" size={18} style={{ color:'var(--balsm-ink-600)' }} />}
                            <button onClick={ev => { ev.stopPropagation(); if (editingId===se.id) { setEditingId(null); } else { setEditingId(se.id); setEditName(se.name); setEditUrl(se.url); } }}
                              style={{ border:'none', background:'rgba(0,0,0,.07)', cursor:'pointer', padding:'3px 8px', borderRadius:4, fontFamily:'var(--font-mono)', fontSize:10, color:'var(--balsm-ink-600)', fontWeight:700 }}>edit</button>
                            <button onClick={ev => deleteSavedEnv(se.id, ev)}
                              style={{ border:'none', background:'transparent', cursor:'pointer', padding:'2px 3px', color:'var(--fg4)', display:'flex', alignItems:'center', borderRadius:4 }}>
                              <Icon name="x" size={14} />
                            </button>
                          </div>
                        </div>

                        {editingId === se.id && (
                          <div style={{ marginTop:6, padding:'12px', background:'#F4F3EC', border:'1.5px solid var(--balsm-ink-600)', borderRadius:'var(--radius-lg)' }}>
                            <div style={{ display:'flex', flexDirection:'column', gap:8 }}>
                              {[['name', editName, setEditName], ['url', editUrl, setEditUrl]].map(([lbl, val, set]) => (
                                <div key={lbl} style={{ display:'flex', alignItems:'center', gap:8 }}>
                                  <span style={{ fontFamily:'var(--font-mono)', fontSize:10, color:'var(--balsm-ink-600)', width:34, flexShrink:0 }}>{lbl}</span>
                                  <input value={val} onChange={ev => set(ev.target.value)}
                                    onKeyDown={ev => { if (ev.key==='Enter') commitEdit(se.id); if (ev.key==='Escape') setEditingId(null); }}
                                    style={{ flex:1, border:'1px solid var(--balsm-border)', borderRadius:6, padding:'5px 9px', fontFamily:'var(--font-mono)', fontSize:12, color:'var(--balsm-ink-800)', outline:'none', background:'#fff' }} />
                                </div>
                              ))}
                              <div style={{ display:'flex', gap:8, justifyContent:'flex-end' }}>
                                <button onClick={() => setEditingId(null)}
                                  style={{ border:'1px solid var(--balsm-border)', background:'transparent', cursor:'pointer', borderRadius:6, padding:'5px 12px', fontFamily:'var(--font-mono)', fontSize:11, color:'var(--balsm-ink-600)' }}>Cancel</button>
                                <button onClick={() => commitEdit(se.id)}
                                  style={{ border:'none', background:'var(--balsm-ink-800)', cursor:'pointer', borderRadius:6, padding:'5px 12px', fontFamily:'var(--font-mono)', fontSize:11, fontWeight:700, color:'#F4F3EC' }}>Save</button>
                              </div>
                            </div>
                          </div>
                        )}
                      </div>
                    );
                  })}
                </>
              )}

              {/* ── Add custom ── */}
              {!addingCustom ? (
                <button onClick={() => { setAddingCustom(true); setNewName(''); setNewUrl(''); }}
                  style={{ display:'flex', alignItems:'center', gap:8, width:'100%', padding:'10px 14px',
                    border:'1.5px dashed var(--balsm-border)', borderRadius:'var(--radius-lg)',
                    background:'transparent', cursor:'pointer', color:'var(--fg3)',
                    fontFamily:'var(--font-body)', fontSize:13, fontWeight:600, transition:'all 150ms' }}>
                  <Icon name="plus" size={15} />Add custom environment
                </button>
              ) : (
                <div style={{ padding:'12px', background:'var(--balsm-ink-50)', border:'1.5px solid var(--balsm-border)', borderRadius:'var(--radius-lg)' }}>
                  <div style={{ fontSize:10, fontWeight:700, letterSpacing:'0.1em', textTransform:'uppercase', color:'var(--fg3)', marginBottom:10 }}>New environment</div>
                  <div style={{ display:'flex', flexDirection:'column', gap:8 }}>
                    {[['name', newName, setNewName, 'My Staging'], ['url', newUrl, setNewUrl, 'https://api.example.com']].map(([lbl, val, set, ph]) => (
                      <div key={lbl} style={{ display:'flex', alignItems:'center', gap:8 }}>
                        <span style={{ fontFamily:'var(--font-mono)', fontSize:10, color:'var(--fg3)', width:34, flexShrink:0 }}>{lbl}</span>
                        <input value={val} onChange={ev => set(ev.target.value)} placeholder={ph}
                          onKeyDown={ev => { if (ev.key==='Enter') addSavedEnv(); if (ev.key==='Escape') setAddingCustom(false); }}
                          style={{ flex:1, border:'1px solid var(--balsm-border)', borderRadius:6, padding:'6px 9px', fontFamily:'var(--font-mono)', fontSize:12, color:'var(--fg1)', outline:'none', background:'#fff' }} />
                      </div>
                    ))}
                    <div style={{ display:'flex', gap:8, justifyContent:'flex-end', marginTop:2 }}>
                      <button onClick={() => setAddingCustom(false)}
                        style={{ border:'1px solid var(--balsm-border)', background:'#fff', cursor:'pointer', borderRadius:6, padding:'6px 14px', fontFamily:'var(--font-body)', fontSize:12, color:'var(--fg3)' }}>Cancel</button>
                      <button onClick={addSavedEnv} disabled={!newName.trim() || !newUrl.trim()}
                        style={{ border:'none', borderRadius:6, padding:'6px 14px', fontFamily:'var(--font-body)', fontSize:12, fontWeight:700,
                          background: newName.trim()&&newUrl.trim() ? 'var(--app-accent)' : 'var(--balsm-ink-200)',
                          color: newName.trim()&&newUrl.trim() ? '#fff' : 'var(--fg4)',
                          cursor: newName.trim()&&newUrl.trim() ? 'pointer' : 'default' }}>Save</button>
                    </div>
                  </div>
                </div>
              )}
            </div>

            {/* Production confirm */}
            {confProd && (
              <div style={{ marginTop:12, padding:'14px 16px',
                background:'#FBEBE7', border:'1.5px solid #D44A3C',
                borderRadius:'var(--radius-lg)' }}>
                <div style={{ display:'flex', gap:10, marginBottom:12 }}>
                  <Icon name="alert-triangle" size={18}
                    style={{ color:'#D44A3C', flexShrink:0, marginTop:1 }} />
                  <div>
                    <div style={{ fontWeight:700, fontSize:14, color:'#7A2A20' }}>
                      Switch to production?
                    </div>
                    <div style={{ fontSize:12, color:'#9B3A2F', marginTop:3, lineHeight:1.5 }}>
                      Real patient data. Real consequences. Any action here is permanent.
                    </div>
                  </div>
                </div>
                <div style={{ display:'flex', gap:8 }}>
                  <button className="b-btn b-btn-md b-btn-secondary"
                    style={{ flex:1, height:40, fontSize:13 }}
                    onClick={() => setConfProd(false)}>Cancel</button>
                  <button className="b-btn b-btn-md"
                    style={{ flex:1, height:40, fontSize:13, background:'#D44A3C', color:'#fff' }}
                    onClick={commitProd}>Switch anyway</button>
                </div>
              </div>
            )}

            {/* Feature flags */}
            <div className="eyebrow-l" style={{ margin:'20px 0 10px' }}>Feature flags</div>
            <div style={{ background:'#fff', borderRadius:'var(--radius-lg)',
              border:'1px solid var(--balsm-border)', overflow:'hidden' }}>
              {DC_FLAGS.map((f, i) => (
                <div key={f.id} onClick={() => toggleFlag(f.id)} style={{
                  display:'flex', alignItems:'center', gap:14, padding:'13px 16px',
                  borderTop: i>0 ? '1px solid var(--balsm-ink-100)' : 'none',
                  cursor:'pointer',
                  background: flags[f.id] ? 'var(--app-accent-50)' : 'transparent',
                  transition:'background 150ms',
                }}>
                  <div style={{ flex:1 }}>
                    <div style={{ fontWeight:600, fontSize:13, color:'var(--fg1)' }}>{f.label}</div>
                    <div style={{ fontSize:11, color:'var(--fg3)', marginTop:1 }}>{f.desc}</div>
                  </div>
                  <div className="dc-tog"
                    style={{ background: flags[f.id] ? 'var(--app-accent)' : 'var(--balsm-ink-200)' }}>
                    <div className="dc-tog-k" style={{ left: flags[f.id] ? 20 : 2 }} />
                  </div>
                </div>
              ))}
            </div>

            {/* Build info */}
            <div style={{ marginTop:20, padding:'12px 14px', background:'#1A1A17',
              borderRadius:10, fontFamily:'var(--font-mono)', fontSize:10.5, color:'#555', lineHeight:1.9 }}>
              <div style={{ color:'#A3FF6E', fontWeight:700, marginBottom:4, fontSize:11 }}>// build</div>
              <div><span style={{ color:'#3D3D36' }}>version  </span><span style={{ color:'#C8C8BE' }}>0.2.0-alpha</span></div>
              <div><span style={{ color:'#3D3D36' }}>react    </span><span style={{ color:'#C8C8BE' }}>18.3.1</span></div>
              <div><span style={{ color:'#3D3D36' }}>built    </span><span style={{ color:'#C8C8BE' }}>{new Date().toLocaleDateString('en', { day:'2-digit', month:'short', year:'numeric' })}</span></div>
              <div><span style={{ color:'#3D3D36' }}>user     </span><span style={{ color:'#C8C8BE' }}>{navigator.userAgent.split(')')[0].split('(')[1] || 'unknown'}</span></div>
            </div>
          </>}

          {/* ── LOGS ────────────────────────────────────────────────────── */}
          {tab==='logs' && <>
            {/* Summary stats */}
            <div className="eyebrow-l" style={{ marginBottom:10 }}>Summary</div>
            <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:8, marginBottom:20 }}>
              {[
                { label:'Total',    val: allLogs.length,                                          dot:'#C8C8BE' },
                { label:'Errors',   val: allLogs.filter(l=>l.level==='error').length,             dot:'#F87171' },
                { label:'Warnings', val: allLogs.filter(l=>l.level==='warn').length,              dot:'#FBBF24' },
              ].map(s => (
                <div key={s.label} style={{ background:'#fff', border:'1px solid var(--balsm-border)',
                  borderRadius:'var(--radius-lg)', padding:'12px 14px' }}>
                  <div style={{ display:'flex', alignItems:'center', gap:6, marginBottom:4 }}>
                    <span style={{ width:7, height:7, borderRadius:'50%', background:s.dot, flexShrink:0 }} />
                    <span style={{ fontSize:11, color:'var(--fg3)', fontWeight:600 }}>{s.label}</span>
                  </div>
                  <div style={{ fontFamily:'var(--font-mono)', fontWeight:700, fontSize:22, color:'var(--fg1)', lineHeight:1 }}>{s.val}</div>
                </div>
              ))}
            </div>

            <div style={{ fontSize:11, color:'var(--fg3)', marginBottom:6 }}>
              Last entry: {allLogs.length ? allLogs[allLogs.length-1].ts.toLocaleTimeString('en',{hour12:false}) : '—'}
            </div>

            {/* Encryption key display */}
            <div className="eyebrow-l" style={{ margin:'16px 0 8px' }}>Encryption key</div>
            <div style={{ background:'#1A1A17', borderRadius:10, padding:'11px 14px',
              display:'flex', alignItems:'center', gap:10, marginBottom:20 }}>
              <Icon name="key-round" size={14} style={{ color:'#A3FF6E', flexShrink:0 }} />
              <span style={{ fontFamily:'var(--font-mono)', fontSize:11, color:'#C8C8BE',
                letterSpacing:'0.06em', flex:1, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>
                {encKey}
              </span>
              <button onClick={() => navigator.clipboard?.writeText(encKey)}
                style={{ border:'none', background:'rgba(255,255,255,.07)', cursor:'pointer',
                  borderRadius:5, padding:'3px 8px', fontFamily:'var(--font-mono)',
                  fontSize:10, color:'#888', flexShrink:0 }}>copy</button>
            </div>

            {/* Actions */}
            <div className="eyebrow-l" style={{ marginBottom:10 }}>Export</div>
            <div style={{ display:'flex', flexDirection:'column', gap:8 }}>
              <button className="b-btn b-btn-md b-btn-secondary b-btn--full" onClick={saveEncryptedLogs}
                style={{ height:50, fontSize:13, justifyContent:'flex-start', paddingInlineStart:16, gap:12 }}>
                <div style={{ width:34, height:34, borderRadius:8, background:'var(--app-accent-50)',
                  display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}>
                  <Icon name="lock" size={16} style={{ color:'var(--app-accent)' }} />
                </div>
                <div style={{ textAlign:'left' }}>
                  <div style={{ fontWeight:700, fontSize:13 }}>Save encrypted file</div>
                  <div style={{ fontSize:11, color:'var(--fg3)', fontWeight:400 }}>AES-256-GCM · .enc.json</div>
                </div>
              </button>

              <button className="b-btn b-btn-md b-btn-secondary b-btn--full" onClick={sendToServer}
                disabled={sendStatus==='sending'}
                style={{ height:50, fontSize:13, justifyContent:'flex-start', paddingInlineStart:16, gap:12,
                  opacity: sendStatus==='sending' ? .6 : 1 }}>
                <div style={{ width:34, height:34, borderRadius:8,
                  background: sendStatus==='sent' ? 'var(--petal-mint-50)' : sendStatus==='error' ? '#FBEBE7' : 'var(--balsm-ink-50)',
                  display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}>
                  <Icon name={sendStatus==='sent' ? 'check' : sendStatus==='error' ? 'alert-triangle' : sendStatus==='sending' ? 'loader' : 'send'}
                    size={16} style={{ color: sendStatus==='sent' ? 'var(--petal-mint)' : sendStatus==='error' ? 'var(--balsm-danger)' : 'var(--fg2)' }} />
                </div>
                <div style={{ textAlign:'left' }}>
                  <div style={{ fontWeight:700, fontSize:13 }}>
                    {sendStatus==='sending' ? 'Sending…' : sendStatus==='sent' ? 'Sent!' : sendStatus==='error' ? 'Failed to send' : 'Send to server'}
                  </div>
                  <div style={{ fontSize:11, color:'var(--fg3)', fontWeight:400 }}>POST {env.url}/api/dev/logs</div>
                </div>
              </button>

              <button className="b-btn b-btn-md b-btn-secondary b-btn--full" onClick={clearLogs}
                style={{ height:44, fontSize:13, gap:8, color:'var(--balsm-danger)', borderColor:'var(--balsm-danger)' }}>
                <Icon name="trash-2" size={15} />Clear all logs
              </button>
            </div>

            <div style={{ marginTop:16, display:'flex', alignItems:'flex-start', gap:8,
              padding:'10px 12px', background:'var(--balsm-ink-50)', borderRadius:8 }}>
              <Icon name="shield" size={14} style={{ color:'var(--fg3)', flexShrink:0, marginTop:1 }} />
              <span style={{ fontSize:11, color:'var(--fg3)', lineHeight:1.5 }}>
                Log content is never shown here. Save encrypted or send to your server to inspect.
              </span>
            </div>
          </>}

          {/* ── BUG REPORT ──────────────────────────────────────────────── */}
          {tab==='bug' && <>
            <div className="eyebrow-l" style={{ marginBottom:8 }}>Screenshot</div>
            <div style={{ borderRadius:'var(--radius-lg)', border:'1px solid var(--balsm-border)',
              overflow:'hidden', minHeight:130, display:'flex', alignItems:'center',
              justifyContent:'center', background:'var(--balsm-ink-50)', marginBottom:16 }}>
              {screenshot ? (
                <img src={screenshot}
                  style={{ maxWidth:'100%', maxHeight:220, display:'block', objectFit:'contain' }}
                  alt="App screenshot" />
              ) : (
                <div style={{ display:'flex', flexDirection:'column', alignItems:'center',
                  gap:8, color:'var(--fg4)', padding:'24px 0' }}>
                  <Icon name="image" size={26} />
                  <span style={{ fontSize:12, fontFamily:'var(--font-mono)' }}>
                    No screenshot captured
                  </span>
                </div>
              )}
            </div>

            <div className="field" style={{ marginBottom:12 }}>
              <label>Title</label>
              <input className="b-input" style={{ height:46, fontSize:13 }}
                placeholder="Brief description of the bug"
                value={bugTitle} onChange={e => setBugTitle(e.target.value)} />
            </div>

            <div className="field" style={{ marginBottom:12 }}>
              <label>Steps to reproduce</label>
              <textarea className="textarea" style={{ minHeight:80, fontSize:13 }}
                placeholder={'1. Go to…\n2. Tap…\n3. Expected: …\n4. Actual: …'}
                value={bugDesc} onChange={e => setBugDesc(e.target.value)} />
            </div>

            <div className="field" style={{ marginBottom:14 }}>
              <label>Severity</label>
              <div style={{ display:'flex', gap:6 }}>
                {DC_SELS.map(([id, label]) => (
                  <button key={id} className={`dc-sev${bugSev===id?' on':''}`}
                    onClick={() => setBugSev(id)}>{label}</button>
                ))}
              </div>
            </div>

            {/* Auto context */}
            <div style={{ background:'#1A1A17', borderRadius:10, padding:'12px 14px',
              fontFamily:'var(--font-mono)', fontSize:10.5, color:'#555',
              lineHeight:1.9, marginBottom:16 }}>
              <div style={{ color:'#A3FF6E', fontWeight:700, marginBottom:4, fontSize:11 }}>
                // context auto-attached
              </div>
              <div>
                <span style={{ color:'#3D3D36' }}>env      </span>
                <span style={{ color:'#C8C8BE' }}>{env.label} — {env.url}</span>
              </div>
              <div>
                <span style={{ color:'#3D3D36' }}>time     </span>
                <span style={{ color:'#C8C8BE' }}>{new Date().toISOString()}</span>
              </div>
              <div>
                <span style={{ color:'#3D3D36' }}>logs     </span>
                <span style={{ color:'#C8C8BE' }}>
                  {allLogs.length} entries ·{' '}
                  <span style={{ color: errCount > 0 ? '#F87171' : '#C8C8BE' }}>
                    {errCount} errors
                  </span>
                </span>
              </div>
              <div>
                <span style={{ color:'#3D3D36' }}>viewport </span>
                <span style={{ color:'#C8C8BE' }}>{window.innerWidth}×{window.innerHeight}</span>
              </div>
            </div>

            <button className="b-btn b-btn-md b-btn-primary b-btn--full" onClick={copyReport}>
              <Icon name={copied ? 'check' : 'copy'} size={17} />
              {copied ? 'Copied to clipboard!' : 'Copy report to clipboard'}
            </button>
          </>}

        </div>
      </div>
    </>
  );
}

Object.assign(window, { DevConfigOverlay });
