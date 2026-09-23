/* map.jsx — nearby health entities: SVG Cairo map + HTML pins + list view */

/* ── SVG map background ────────────────────────────────────── */
const MAP_W = 390, MAP_H = 430;
const USER_X = 220, USER_Y = 218;

function CairoMap({ shownIds, selectedId, onPinClick }) {
  const entities = HEALTH_ENTITIES.filter(e => shownIds.includes(e.id));

  return (
    <div style={{ width: '100%', height: '100%', position: 'relative', overflow: 'hidden', background: '#F2F1E8' }}>
      {/* ── SVG background ── */}
      <svg viewBox={`0 0 ${MAP_W} ${MAP_H}`} width="100%" height="100%"
        preserveAspectRatio="xMidYMid slice" style={{ position: 'absolute', inset: 0, display: 'block' }}>

        <rect width={MAP_W} height={MAP_H} fill="#F2F1E8" />

        {/* City blocks */}
        {[[0,0,130,88],[0,100,112,120],[0,234,96,84],[0,330,134,100],
          [234,0,156,82],[240,90,74,108],[318,90,72,94],
          [222,210,84,92],[316,200,74,122],[224,316,166,114]
        ].map(([x,y,w,h],i) => <rect key={i} x={x} y={y} width={w} height={h} fill="#ECEADF" rx="3" />)}

        {/* Nile river */}
        <path d="M 148 0 C 145 62, 138 102, 135 168 C 132 224, 138 272, 142 430
                 L 198 430 C 202 272, 208 224, 205 168 C 202 102, 195 62, 192 0 Z"
          fill="#C2DCF0" />
        {/* Nile label */}
        <text x="170" y="44" textAnchor="middle" fontSize="8" fill="#7BA8C8"
          fontWeight="700" fontFamily="sans-serif" letterSpacing="1">NILE · النيل</text>

        {/* Gezira Island */}
        <path d="M 155 86 C 162 79, 177 76, 187 81 C 197 86, 201 110, 201 150
                 C 201 190, 197 220, 187 230 C 177 240, 159 237, 151 226
                 C 143 215, 141 190, 141 150 C 141 110, 148 93, 155 86 Z"
          fill="#C8E8BE" />
        <text x="171" y="162" textAnchor="middle" fontSize="7.5" fill="#5A8A4A"
          fontWeight="700" fontFamily="sans-serif">الجزيرة</text>

        {/* Corniche roads */}
        <path d="M 204 0 C 212 62, 216 124, 214 182 C 212 242, 209 302, 204 430"
          fill="none" stroke="#FFF" strokeWidth="8" />
        <path d="M 130 0 C 126 62, 122 124, 122 182 C 122 242, 124 302, 130 430"
          fill="none" stroke="#FFF" strokeWidth="8" />

        {/* Major roads */}
        {[90, 224, 328].map(y => <line key={y} x1="0" y1={y} x2={MAP_W} y2={y} stroke="#FFF" strokeWidth="7" />)}
        {[62, 216, 318].map(x => <line key={x} x1={x} y1="0" x2={x} y2={MAP_H} stroke="#FFF" strokeWidth="7" />)}

        {/* Minor roads */}
        <line x1="0"   y1="150" x2="130" y2="150" stroke="#F4F3E8" strokeWidth="3.5" />
        <line x1="204" y1="150" x2={MAP_W} y2="150" stroke="#F4F3E8" strokeWidth="3.5" />
        <line x1="0"   y1="280" x2="130" y2="280" stroke="#F4F3E8" strokeWidth="3.5" />
        <line x1="204" y1="280" x2={MAP_W} y2="280" stroke="#F4F3E8" strokeWidth="3.5" />
        <line x1="0"   y1="384" x2={MAP_W} y2="384" stroke="#F4F3E8" strokeWidth="3.5" />
        <line x1="270" y1="90"  x2="270"  y2={MAP_H} stroke="#F4F3E8" strokeWidth="3.5" />

        {/* Area labels */}
        {[
          [50,  52,  'Agouza'],
          [270, 162, 'Tahrir'],
          [354, 42,  'Heliopolis'],
          [46,  296, 'Garden City'],
          [270, 278, 'Dokki'],
          [354, 242, 'Nasr City'],
          [354, 360, 'New Cairo'],
        ].map(([x,y,label]) => (
          <text key={label} x={x} y={y} textAnchor="middle" fontSize="7.5"
            fill="#A8A89A" fontFamily="sans-serif" fontWeight="600">{label}</text>
        ))}

        {/* User location */}
        <circle cx={USER_X} cy={USER_Y} r="18" fill="rgba(18,131,255,0.10)" />
        <circle cx={USER_X} cy={USER_Y} r="10" fill="rgba(18,131,255,0.22)" />
        <circle cx={USER_X} cy={USER_Y} r="6"  fill="#1283FF" />
        <circle cx={USER_X} cy={USER_Y} r="6"  fill="none" stroke="#fff" strokeWidth="2.5" />
      </svg>

      {/* ── HTML pins (absolute over SVG) ── */}
      {entities.map(e => {
        const cfg = ENTITY_TYPES[e.type];
        const sel = e.id === selectedId;
        const pinW = sel ? 40 : 32;
        return (
          <div key={e.id} onClick={() => onPinClick(e)} style={{
            position: 'absolute',
            left: (e.x / MAP_W * 100) + '%',
            top:  (e.y / MAP_H * 100) + '%',
            transform: 'translate(-50%, -100%)',
            cursor: 'pointer',
            zIndex: sel ? 10 : 5,
            filter: sel ? `drop-shadow(0 4px 10px ${cfg.color}88)` : 'drop-shadow(0 2px 5px rgba(20,32,43,0.22))',
            transition: 'filter var(--dur-fast) var(--ease-out)',
          }}>
            <div style={{
              width: pinW, height: pinW, borderRadius: 9999,
              background: sel ? cfg.color : '#fff',
              color: sel ? '#fff' : cfg.color,
              border: `2.5px solid ${cfg.color}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              transition: 'all var(--dur-fast) var(--ease-out)',
            }}>
              <Icon name={cfg.icon} size={sel ? 18 : 15} stroke={2} />
            </div>
            <div style={{
              width: 0, height: 0,
              borderLeft: '5px solid transparent',
              borderRight: '5px solid transparent',
              borderTop: `7px solid ${cfg.color}`,
              margin: '-1px auto 0',
            }} />
          </div>
        );
      })}
    </div>
  );
}

/* ── Entity bottom card ────────────────────────────────────── */
function EntityCard({ entity, onClose }) {
  const { t, lang } = useApp();
  const cfg = ENTITY_TYPES[entity.type];
  return (
    <>
      <style>{`@keyframes ecUp{from{transform:translateY(110%)}to{transform:none}}`}</style>
      <div className="app-scrim" onClick={onClose} style={{ position: 'absolute', inset: 0, zIndex: 18 }} />
      <div className="app-sheet" style={{
        position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 20,
        background: '#fff', borderRadius: '20px 20px 0 0',
        boxShadow: '0 -4px 32px rgba(20,32,43,0.14)',
        animation: 'ecUp 0.26s cubic-bezier(0.16,1,0.3,1) both',
        paddingBottom: 32,
      }}>
        <div className="sheet-grab" style={{ margin: '10px auto 14px' }} />
        <div style={{ padding: '0 18px' }}>
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 13, marginBottom: 14 }}>
            <div style={{ width: 50, height: 50, borderRadius: 'var(--radius-md)', background: cfg.bg, color: cfg.color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <Icon name={cfg.icon} size={24} />
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-lg)', color: 'var(--fg1)', lineHeight: 1.2, textWrap: 'balance' }}>{entity.name[lang]}</div>
              <span style={{ display: 'inline-flex', alignItems: 'center', marginTop: 5, padding: '3px 10px', borderRadius: 'var(--radius-pill)', background: cfg.bg, color: cfg.color, fontSize: 'var(--pt-xs)', fontWeight: 700 }}>{cfg.label[lang]}</span>
            </div>
            <button className="round-btn ghost" onClick={onClose} style={{ flexShrink: 0 }}><Icon name="x" size={16} /></button>
          </div>

          {/* Detail rows */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 9, marginBottom: 18 }}>
            {[
              { icon: 'map-pin',    text: entity.addr[lang] },
              { icon: 'clock',      text: entity.hours },
              { icon: 'navigation', text: entity.distance + ' ' + t('map_distance') },
              { icon: 'star',       text: entity.rating + ' / 5', star: true },
            ].map((row, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 'var(--pt-sm)', color: 'var(--fg2)' }}>
                <Icon name={row.icon} size={16} style={{ color: row.star ? 'var(--balsm-sun-500)' : 'var(--fg4)', flexShrink: 0 }} />
                <span style={{ fontWeight: row.star ? 600 : 400 }}>{row.text}</span>
              </div>
            ))}
          </div>

          {/* CTAs */}
          <div style={{ display: 'flex', gap: 10 }}>
            <button className="b-btn b-btn-lg b-btn-primary" style={{ flex: 1, height: 50 }} onClick={() => window.open(`tel:${entity.phone}`)}>
              <Icon name="phone" size={18} />{t('map_call')}
            </button>
            <button className="b-btn b-btn-lg b-btn-secondary" style={{ flex: 1, height: 50 }}>
              <Icon name="navigation" size={18} />{t('map_directions')}
            </button>
          </div>
        </div>
      </div>
    </>
  );
}

/* ── Offline map download sheet ────────────────────────────── */
function gSeedMB(name) {
  let h = 0; for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) >>> 0;
  return Math.round((6 + (h % 2200) / 100) * 10) / 10;
}

function OfflineMapSheet({ onClose }) {
  const { t, lang } = useApp();
  const { Modal } = dsCheck();
  const [downloaded, setDownloaded] = useState(() => {
    try { return new Set(JSON.parse(localStorage.getItem('balsm_offline_govs') || '[]')); } catch (e) { return new Set(); }
  });
  const [busy, setBusy] = useState(null); // governorate en name mid-download

  const persist = (set) => { try { localStorage.setItem('balsm_offline_govs', JSON.stringify([...set])); } catch (e) {} };

  const download = (gov) => {
    setBusy(gov.en);
    setTimeout(() => {
      setBusy(null);
      setDownloaded(prev => { const n = new Set(prev); n.add(gov.en); persist(n); return n; });
    }, 1000);
  };
  const remove = (gov) => setDownloaded(prev => { const n = new Set(prev); n.delete(gov.en); persist(n); return n; });

  return (
    <Modal open onClose={onClose} closeOnScrim size="md" icon={<Icon name="download" size={19} />} title={t('map_offline_title')}>
      <div style={{ padding: '0 20px 24px' }}>
        <p className="meta" style={{ margin: '0 0 16px', lineHeight: 1.5 }}>{t('map_offline_desc')}</p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, maxHeight: '52vh', overflowY: 'auto' }}>
          {GOVERNORATES.map(gov => {
            const mb = gSeedMB(gov.en);
            const isDown = downloaded.has(gov.en);
            const isBusy = busy === gov.en;
            return (
              <div key={gov.en} style={{
                display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px',
                borderRadius: 'var(--radius-lg)', border: '1px solid var(--balsm-border)', background: '#fff',
              }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{gov[lang]}</div>
                  <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg4)', marginTop: 3 }}>
                    {mb} MB · {isDown ? t('map_offline_saved_lbl') : t('map_offline_no_data')}
                  </div>
                </div>
                {isDown ? (
                  <button className="b-btn b-btn-md" style={{ flexShrink: 0, borderRadius: 'var(--radius-pill)', background: 'var(--balsm-danger-50, #FBE9E7)', color: 'var(--balsm-danger)', border: 'none' }} onClick={() => remove(gov)}>
                    {t('map_offline_delete')}
                  </button>
                ) : (
                  <button className="b-btn b-btn-md b-btn-soft" style={{ flexShrink: 0, borderRadius: 'var(--radius-pill)' }} disabled={isBusy} onClick={() => download(gov)}>
                    {isBusy && <Icon name="loader-2" size={13} style={{ animation: 'spin 0.8s linear infinite' }} />}
                    {isBusy ? t('map_offline_downloading') : t('map_offline_download')}
                  </button>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </Modal>
  );
}

/* ── Map screen ────────────────────────────────────────────── */
function MapScreen({ onBack }) {
  const { t, lang, setTab } = useApp();
  const handleBack = onBack || (() => setTab('home'));
  const [query,      setQuery]      = useState('');
  const [activeType, setActiveType] = useState('all');
  const [viewMode,   setViewMode]   = useState('map'); // 'map' | 'list'
  const [selected,   setSelected]   = useState(null);
  const [typeOpen,   setTypeOpen]   = useState(false);
  const [offlineOpen, setOfflineOpen] = useState(false);
  const typeRef = useRef(null);
  useEffect(() => {
    if (!typeOpen) return;
    const onDoc = (e) => { if (typeRef.current && !typeRef.current.contains(e.target)) setTypeOpen(false); };
    document.addEventListener('mousedown', onDoc);
    return () => document.removeEventListener('mousedown', onDoc);
  }, [typeOpen]);

  const filtered = HEALTH_ENTITIES.filter(e => {
    const matchType = activeType === 'all' || e.type === activeType;
    const q = query.trim().toLowerCase();
    const matchQ = !q || e.name.en.toLowerCase().includes(q) || e.name.ar.includes(query.trim()) || e.addr.en.toLowerCase().includes(q);
    return matchType && matchQ;
  });

  const selectEntity = (e) => setSelected(s => s?.id === e.id ? null : e);

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', background: 'var(--balsm-surface, #fff)' }}>
      <div className="pad-top" />

      {/* App bar — no back button when used as primary tab */}
      <div className="appbar" style={{ flexShrink: 0 }}>
        <h1 style={{ flex: 1, margin: 0, fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', letterSpacing: '-0.01em', color: 'var(--fg1)' }}>
          {t('map_nearby')}
        </h1>
        <button className="round-btn ghost" style={{ flexShrink: 0, marginInlineEnd: 6 }} onClick={() => setOfflineOpen(true)} title={t('map_offline_title')}>
          <Icon name="download" size={18} />
        </button>
        <button className="b-btn b-btn-md b-btn-soft" style={{ height: 40, padding: '0 14px', fontSize: 'var(--pt-sm)', flexShrink: 0 }}
          onClick={() => { setViewMode(v => v === 'map' ? 'list' : 'map'); setSelected(null); }}>
          <Icon name={viewMode === 'map' ? 'list' : 'map'} size={16} />
          {viewMode === 'map' ? t('map_list') : t('map_map')}
        </button>
      </div>
      {offlineOpen && <OfflineMapSheet onClose={() => setOfflineOpen(false)} />}

      {/* Search */}
      <div style={{ padding: '0 20px 10px', flexShrink: 0, position: 'relative' }}>
        <Icon name="search" size={17} style={{ position: 'absolute', inlineStart: 34, top: '50%', transform: 'translateY(-50%)', color: 'var(--fg4)', pointerEvents: 'none' }} />
        <input className="b-input" style={{ paddingInlineStart: 40, paddingInlineEnd: query ? 36 : 12 }} placeholder={t('map_search_ph')}
          value={query} onChange={e => { setQuery(e.target.value); setSelected(null); }} />
        {query && (
          <button onClick={() => { setQuery(''); setSelected(null); }} style={{
            position: 'absolute', inlineEnd: 34, top: '50%', transform: 'translateY(-50%)',
            background: 'var(--balsm-ink-200)', border: 'none', borderRadius: 999,
            width: 20, height: 20, display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer', padding: 0,
          }}>
            <Icon name="x" size={11} style={{ color: 'var(--fg2)' }} />
          </button>
        )}
      </div>

      {/* Filter dropdown */}
      <div style={{ position: 'relative', padding: '0 20px 12px', flexShrink: 0 }} ref={typeRef}>
        {(() => {
          const cfg   = ENTITY_TYPES[activeType] || null;
          const color = cfg ? cfg.color : 'var(--app-accent)';
          const label = cfg ? cfg.label[lang] : t('map_all');
          return (
            <button onClick={() => setTypeOpen(v => !v)} style={{
              display: 'flex', alignItems: 'center', gap: 8, height: 40, padding: '0 14px', borderRadius: 'var(--radius-md)',
              border: '1.5px solid var(--balsm-border)', background: '#fff', color: 'var(--fg1)', fontWeight: 600, fontSize: 'var(--pt-sm)', cursor: 'pointer',
              fontFamily: lang === 'ar' ? 'var(--font-arabic)' : 'var(--font-body)',
            }}>
              {cfg && <Icon name={cfg.icon} size={15} style={{ color }} stroke={2} />}
              <span className="grow" style={{ textAlign: 'start' }}>{label}</span>
              <Icon name="chevron-down" size={15} style={{ color: 'var(--fg3)', transform: typeOpen ? 'rotate(180deg)' : 'none', transition: 'transform var(--dur-fast) var(--ease-out)' }} />
            </button>
          );
        })()}
        {typeOpen && (
          <div style={{
            position: 'absolute', top: 46, insetInlineStart: 20, zIndex: 20, minWidth: 210,
            background: '#fff', borderRadius: 'var(--radius-lg)', border: '1px solid var(--balsm-border)',
            boxShadow: 'var(--shadow-md, 0 8px 24px rgba(20,32,43,0.14))', padding: 6,
          }}>
            {[['all', null], ...Object.entries(ENTITY_TYPES)].map(([key, cfg]) => {
              const active = activeType === key;
              const color  = cfg ? cfg.color : 'var(--app-accent)';
              const label  = cfg ? cfg.label[lang] : t('map_all');
              return (
                <div key={key} onClick={() => { setActiveType(key); setSelected(null); setTypeOpen(false); }} style={{
                  display: 'flex', alignItems: 'center', gap: 10, padding: '10px 10px', borderRadius: 'var(--radius-sm)', cursor: 'pointer',
                  background: active ? 'var(--balsm-ink-50)' : 'transparent',
                }}>
                  {cfg ? <Icon name={cfg.icon} size={15} style={{ color, flexShrink: 0 }} stroke={2} /> : <Icon name="layout-grid" size={15} style={{ color, flexShrink: 0 }} />}
                  <span style={{ flex: 1, fontSize: 'var(--pt-sm)', fontWeight: active ? 700 : 500, color: 'var(--fg1)' }}>{label}</span>
                  {active && <Icon name="check" size={14} style={{ color, flexShrink: 0 }} />}
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* ── Map view ── */}
      {viewMode === 'map' && (
        <div style={{ flex: 1, position: 'relative', overflow: 'hidden' }}>
          {filtered.length > 0 ? (
            <CairoMap shownIds={filtered.map(e => e.id)} selectedId={selected?.id} onPinClick={selectEntity} />
          ) : (
            <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 12, background: 'var(--balsm-cream-50)' }}>
              <Icon name="map-x" size={40} style={{ color: 'var(--fg4)' }} />
              <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg2)' }}>{t('map_no_results')}</div>
              <div className="meta" style={{ textAlign: 'center', maxWidth: 200 }}>{t('map_no_res_h')}</div>
              <button className="b-btn b-btn-md b-btn-soft" style={{ height: 40 }} onClick={() => { setQuery(''); setActiveType('all'); }}>{lang === 'ar' ? 'مسح البحث' : 'Clear search'}</button>
            </div>
          )}

          {/* Count badge */}
          <div style={{
            position: 'absolute', top: 12, right: lang === 'ar' ? 'auto' : 14, left: lang === 'ar' ? 14 : 'auto',
            background: 'rgba(255,255,255,0.94)', borderRadius: 'var(--radius-pill)',
            padding: '5px 13px', fontSize: 'var(--pt-xs)', fontWeight: 700, color: 'var(--fg2)',
            boxShadow: 'var(--shadow-sm)', backdropFilter: 'blur(6px)',
          }}>
            {filtered.length} {t('map_found')}
          </div>

          {/* Recenter button */}
          <button className="round-btn" style={{
            position: 'absolute', bottom: selected ? 220 : 20, right: lang === 'ar' ? 'auto' : 14, left: lang === 'ar' ? 14 : 'auto',
            background: '#fff', boxShadow: 'var(--shadow-md)', transition: 'bottom var(--dur-base) var(--ease-out)',
          }}>
            <Icon name="locate-fixed" size={20} style={{ color: 'var(--app-accent)' }} />
          </button>

          {/* Entity card */}
          {selected && <EntityCard entity={selected} onClose={() => setSelected(null)} />}
        </div>
      )}

      {/* ── List view ── */}
      {viewMode === 'list' && (
        <div className="screen-scroll" style={{ paddingTop: 0, flex: 1 }}>
          {filtered.length > 0 ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '0 20px' }}>
              {filtered.map(entity => {
                const cfg = ENTITY_TYPES[entity.type];
                return (
                  <div key={entity.id} className="card" onClick={() => selectEntity(entity)} style={{
                    padding: '14px 16px', cursor: 'pointer',
                    display: 'flex', alignItems: 'flex-start', gap: 13,
                    border: selected?.id === entity.id ? `1.5px solid ${cfg.color}` : '1.5px solid var(--balsm-border)',
                    background: selected?.id === entity.id ? cfg.bg : '#fff',
                  }}>
                    <div style={{ width: 46, height: 46, borderRadius: 'var(--radius-md)', background: cfg.bg, color: cfg.color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                      <Icon name={cfg.icon} size={22} />
                    </div>
                    <div className="grow">
                      <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{entity.name[lang]}</div>
                      <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', marginTop: 2 }}>{entity.addr[lang]}</div>
                      <div style={{ display: 'flex', gap: 14, marginTop: 8, flexWrap: 'wrap' }}>
                        {[
                          { icon: 'navigation', text: entity.distance },
                          { icon: 'clock',      text: entity.hours },
                          { icon: 'star',       text: entity.rating, star: true },
                        ].map((r, i) => (
                          <span key={i} style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 'var(--pt-xs)', color: 'var(--fg3)' }}>
                            <Icon name={r.icon} size={11} style={{ color: r.star ? 'var(--balsm-sun-500)' : 'var(--fg4)' }} />
                            <span style={{ fontWeight: r.star ? 700 : 400, color: r.star ? 'var(--fg2)' : 'var(--fg3)' }}>{r.text}</span>
                          </span>
                        ))}
                      </div>
                    </div>
                    <button className="b-btn b-btn-md b-btn-soft" style={{ height: 38, padding: '0 12px', flexShrink: 0, fontSize: 'var(--pt-xs)' }}
                      onClick={ev => { ev.stopPropagation(); window.open(`tel:${entity.phone}`); }}>
                      <Icon name="phone" size={14} />
                    </button>
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="card" style={{ margin: '0 20px', padding: '36px 24px', textAlign: 'center' }}>
              <Icon name="map-pin-off" size={32} style={{ color: 'var(--fg4)', display: 'block', margin: '0 auto 12px' }} />
              <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg2)', marginBottom: 6 }}>{t('map_no_results')}</div>
              <p className="meta" style={{ margin: 0 }}>{t('map_no_res_h')}</p>
            </div>
          )}
          <div style={{ height: 24 }} />
        </div>
      )}
      {viewMode === 'list' && selected && <EntityCard entity={selected} onClose={() => setSelected(null)} />}
    </div>
  );
}

Object.assign(window, { MapScreen, CairoMap, EntityCard });
