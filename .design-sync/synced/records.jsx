/* records.jsx — health records vault: labs, scans, reports + add flow + detail */

const { Modal } = window.BalsmDesignSystem_51cdbf;

const REC_FILTERS = ['all', 'lab', 'scan', 'report'];

/* ── Document preview placeholder ───────────────────────── */
/* A record's files, normalised to a list (legacy single `attachment`/`photo` still work) */
const recAttList = (rec) => rec.attachments && rec.attachments.length ? rec.attachments
  : rec.attachment ? [rec.attachment]
  : rec.photo ? [{ url: rec.photo, kind: 'image', name: rec.title }] : [];

function DocPreview({ type, photo, attachment, attachments, title, height = 200 }) {
  const conf = RECORD_TYPES[type];
  const list = recAttList({ attachments, attachment, photo, title });
  if (list.length) return <AttachmentGallery atts={list} height={height} />;
  return (
    <div style={{
      height, borderRadius: 'var(--radius-lg)', background: 'var(--balsm-cream-100)',
      display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 10,
      position: 'relative', overflow: 'hidden', border: '1px solid var(--balsm-ink-100)',
    }}>
      <img src={window.__resources ? window.__resources['icon'] : 'assets/icon.svg?v=7'} alt="" style={{ position: 'absolute', right: -28, bottom: -28, width: 130, opacity: 0.07 }} />
      <div style={{ width: 56, height: 56, borderRadius: 'var(--radius-md)', background: conf.bg, color: conf.color, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Icon name={conf.icon} size={28} />
      </div>
      <span className="meta">Document preview</span>
    </div>
  );
}

/* ── Record detail ──────────────────────────────────────── */
function RecordDetail({ rec: recProp, onBack, onDelete, onStorageChange }) {
  const { t, lang, recordStorageMap, setRecordStorage } = useApp();
  // Merge global storage overrides (from migrations) into local state
  const [rec, setRec] = useState(() => ({
    ...recProp,
    storage: recordStorageMap[recProp.id] || recProp.storage,
  }));
  // Keep in sync if a migration runs while detail is open
  useEffect(() => {
    const override = recordStorageMap[rec.id];
    if (override && override !== rec.storage) setRec(r => ({ ...r, storage: override }));
  }, [recordStorageMap]);
  const [manageOpen, setManageOpen] = useState(false);
  const [viewOpen, setViewOpen] = useState(false);
  const recAtts = recAttList({ ...rec, title: rec.title[lang] });
  const recAtt = recAtts[0] || null;
  const conf = RECORD_TYPES[rec.type];
  const doc  = rec.sourceId === 'self' ? null : DOCTORS.find(d => d.id === rec.sourceId);

  const handleAction = (action, target) => {
    if (action === 'backup' || action === 'move') {
      const u = { ...rec, storage: target };
      setRec(u);
      setRecordStorage(rec.id, target);
      onStorageChange && onStorageChange(rec.id, target);
    } else if (action === 'remove_cloud') {
      const u = { ...rec, storage: 'local' };
      setRec(u);
      setRecordStorage(rec.id, 'local');
      onStorageChange && onStorageChange(rec.id, 'local');
    } else if (action === 'remove_dev') {
      setRec(r => ({ ...r, removedFromDevice: true }));
    } else if (action === 'delete_all') {
      onDelete && onDelete(rec.id); onBack();
    }
    setManageOpen(false);
  };

  return (
    <div className="screen fade-in">
      <div className="pad-top" />
      <div className="appbar">
        <button className="round-btn" onClick={onBack} aria-label="Back">
          <Icon name="arrow-left" style={{ transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
        </button>
        <div style={{ flex: 1 }} />
        <span className="b-badge" style={{ background: conf.bg, color: conf.color }}>{t(conf.oneKey)}</span>
      </div>

      <div className="screen-scroll">
        <div style={{ padding: '0 20px' }}>
          <h1 style={{ margin: '0 0 6px', fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', color: 'var(--fg1)', lineHeight: 1.25, textWrap: 'balance' }}>{rec.title[lang]}</h1>
          <div className="meta" style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
            <Icon name="calendar" size={13} />{rec.date[lang]}
            <span style={{ color: 'var(--balsm-ink-300)' }}>·</span>
            <span className="num">{rec.fileType}</span>
            {rec.pages > 1 && <><span style={{ color: 'var(--balsm-ink-300)' }}>·</span><span>{rec.pages} {t('pages')}</span></>}
          </div>
        </div>

        <div style={{ padding: '16px 20px 0' }}>
          <DocPreview type={rec.type} photo={rec.photo} attachment={rec.attachment} attachments={rec.attachments} title={rec.title[lang]} />
        </div>

        {/* Key result callout */}
        {rec.result && (
          <div className="card" style={{ margin: '16px 20px 0', padding: '14px 18px', display: 'flex', alignItems: 'center', gap: 12, borderLeft: `3px solid ${conf.color}` }}>
            <Icon name="sparkles" size={17} style={{ color: conf.color, flexShrink: 0 }} />
            <span style={{ fontSize: 'var(--pt-md)', fontWeight: 600, color: 'var(--fg1)' }}>{rec.result[lang]}</span>
          </div>
        )}

        {/* Tags */}
        {rec.tags && rec.tags.length > 0 && (
          <div style={{ padding: '16px 20px 0', display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {rec.tags.map((tg, i) => (
              <span key={i} style={{ display: 'inline-flex', alignItems: 'center', gap: 5, height: 28, padding: '0 12px', borderRadius: 'var(--radius-pill)', background: 'var(--app-accent-50)', color: 'var(--app-accent-600)', fontSize: 'var(--pt-sm)', fontWeight: 600 }}>
                <Icon name="tag" size={12} />{tg[lang] ?? tg.en ?? tg}
              </span>
            ))}
          </div>
        )}

        {/* Storage location — tappable */}
        <div style={{ padding: '16px 20px 0' }}>
          <div onClick={() => setManageOpen(true)} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 16px', borderRadius: 'var(--radius-lg)', background: STORAGE_CFG[rec.storage || 'local'].bg, border: `1.5px solid ${STORAGE_CFG[rec.storage || 'local'].border}`, cursor: 'pointer' }}>
            <Icon name={STORAGE_CFG[rec.storage || 'local'].icon} size={18} style={{ color: STORAGE_CFG[rec.storage || 'local'].color, flexShrink: 0 }} />
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 'var(--pt-sm)', fontWeight: 700, color: 'var(--fg1)' }}>
                {(rec.storage === 'local' || !rec.storage) ? t('store_local_only') : t('store_backed')}
                <span style={{ fontWeight: 400, color: 'var(--fg3)', marginInlineStart: 6 }}>· {STORAGE_CFG[rec.storage || 'local'].label[lang]}</span>
              </div>
              <div style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg3)', marginTop: 2, display: 'flex', alignItems: 'center', gap: 5 }}>
                <Icon name="settings-2" size={11} />{t('store_manage')}
              </div>
            </div>
            <StorageBadge storage={rec.storage || 'local'} />
          </div>
        </div>
        {manageOpen && <ManageStorageSheet rec={rec} onClose={() => setManageOpen(false)} onAction={handleAction} />}
        {viewOpen && recAtt && <AttachmentViewer atts={recAtts} title={rec.title[lang]} onClose={() => setViewOpen(false)} />}

        {/* Source */}
        <div className="row-head"><h2>{t('rec_source')}</h2></div>
        <div className="card" style={{ margin: '0 20px', padding: '14px 18px', display: 'flex', alignItems: 'center', gap: 13 }}>
          {doc ? (
            <>
              <DoctorAvatar doctor={doc} size={42} />
              <div className="grow">
                <div style={{ fontWeight: 600, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{doc.name[lang]}</div>
                <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', marginTop: 2 }}>{doc.specialty[lang]}</div>
              </div>
            </>
          ) : (
            <>
              <div style={{ width: 42, height: 42, borderRadius: 9999, background: 'var(--balsm-ink-100)', color: 'var(--fg2)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <Icon name="user" size={20} />
              </div>
              <div className="grow">
                <div style={{ fontWeight: 600, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{t('rec_self')}</div>
              </div>
            </>
          )}
        </div>

        <div style={{ padding: '20px 20px 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
          <button className={cx('b-btn b-btn-lg b-btn-primary b-btn--full', !recAtt && 'is-disabled')} disabled={!recAtt} onClick={() => recAtt && setViewOpen(true)}><Icon name="eye" size={19} />{recAtts.length > 1 ? `${t('rec_view')} (${recAtts.length})` : t('rec_view')}</button>
          <button className="b-btn b-btn-md b-btn-secondary b-btn--full"><Icon name="share-2" size={17} />{t('rec_share')}</button>
        </div>
        <div style={{ height: 28 }} />
      </div>
    </div>
  );
}

/* ── Manage-storage action sheet (per record) ──────────── */
function ManageStorageSheet({ rec, onClose, onAction }) {
  const { t, lang, storageProviders } = useApp();
  const cfg = STORAGE_CFG[rec.storage || 'local'];
  const isCloud = rec.storage === 'icloud' || rec.storage === 'gdrive' || rec.storage === 'balsmcloud';
  const [confirm, setConfirm] = useState(null); // 'remove_dev' | 'delete_all'
  const [toast, setToast]     = useState(null);

  const showToast = (msg) => {
    setToast(msg);
    setTimeout(() => { setToast(null); onClose(); }, 1600);
  };

  const connectedClouds = ['icloud', 'gdrive', 'balsmcloud'].filter(p => storageProviders[p]);

  if (confirm) {
    const isDev = confirm === 'remove_dev';
    return (
      <Modal open onClose={() => setConfirm(null)} closeOnScrim
        title={isDev ? t('store_remove_dev') : t('store_delete_all')} tone="danger">
        <p className="meta" style={{ margin:'0 0 16px', lineHeight:1.5 }}>
          {isDev ? t('store_remove_dev_h') : t('store_delete_all_h')}
        </p>
        <button className="b-btn b-btn-lg b-btn-danger b-btn--full" style={{ marginBottom:10 }} onClick={() => { onAction(isDev ? 'remove_dev' : 'delete_all'); showToast(isDev ? t('store_removed_dev') : null); }}>
          {isDev ? t('store_remove_dev') : t('store_delete_all')}
        </button>
        <button className="b-btn b-btn-md b-btn-secondary b-btn--full" onClick={() => setConfirm(null)}>{t('cancel')}</button>
      </Modal>
    );
  }

  return (
    <Modal open onClose={onClose} closeOnScrim
      title={<span style={{ display: 'flex', alignItems: 'center', gap: 10 }}><Icon name={cfg.icon} size={19} style={{ color: cfg.color }} />{t('store_manage')}</span>}>
      <div>
        {/* Current location indicator */}
        <div style={{ padding:'0 0 4px' }}>
          <div style={{ display:'flex', alignItems:'center', gap:10, padding:'11px 14px', borderRadius:'var(--radius-lg)', background:cfg.bg, border:`1px solid ${cfg.border}`, marginBottom:16 }}>
            <Icon name={cfg.icon} size={16} style={{ color:cfg.color, flexShrink:0 }} />
            <div style={{ flex:1, fontSize:'var(--pt-sm)', fontWeight:600, color:'var(--fg1)' }}>
              {isCloud ? t('store_backed') : t('store_local_only')}
              <span style={{ fontWeight:400, color:'var(--fg3)', marginInlineStart:6 }}>· {cfg.label[lang]}</span>
              {isCloud && <div style={{ fontWeight:400, color:'var(--fg3)', fontSize:'var(--pt-xs)', marginTop:2 }}>{lang==='ar' ? 'ملاحظة: يتوفر التخزين على الجهاز فقط حالياً — آي كلاود وجوجل درايف وبلسم كلاود قادمون قريباً.' : 'Note: only local storage is available right now — iCloud, Google Drive, and Balsm Cloud are coming later.'}</div>}
            </div>
            <StorageBadge storage={rec.storage || 'local'} size="xs" />
          </div>
        </div>

        {/* Actions */}
        <div style={{ display:'flex', flexDirection:'column', gap:10 }}>

          {/* Back up to cloud (if local & clouds connected) */}
          {!isCloud && connectedClouds.map(p => (
            <button key={p} className="b-btn b-btn-md b-btn-soft b-btn--full" style={{ height:52, justifyContent:'flex-start', gap:14, paddingInlineStart:16 }}
              onClick={() => { onAction('backup', p); showToast(t('store_backed_up')); }}>
              <div style={{ width:34, height:34, borderRadius:'var(--radius-md)', background:STORAGE_CFG[p].bg, color:STORAGE_CFG[p].color, display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}>
                <Icon name={STORAGE_CFG[p].icon} size={18} />
              </div>
              <span style={{ flex:1, textAlign:'start', fontWeight:600, fontSize:'var(--pt-md)' }}>
                {t('store_backup_to')} {STORAGE_CFG[p].label[lang]}
              </span>
              <Icon name="chevron-right" size={16} style={{ color:'var(--fg4)', transform: lang==='ar' ? 'scaleX(-1)' : 'none' }} />
            </button>
          ))}

          {/* No clouds connected hint */}
          {!isCloud && connectedClouds.length === 0 && (
            <div style={{ padding:'12px 14px', borderRadius:'var(--radius-lg)', background:'var(--balsm-ink-50)', display:'flex', alignItems:'center', gap:10 }}>
              <Icon name="info" size={16} style={{ color:'var(--fg3)', flexShrink:0 }} />
              <span className="meta" style={{ lineHeight:1.4 }}>Only local storage is available right now. iCloud, Google Drive, and Balsm Cloud are all coming later.</span>
            </div>
          )}

          {/* Move to other cloud (if already in one cloud) */}
          {isCloud && connectedClouds.filter(p => p !== rec.storage).map(p => (
            <button key={p} className="b-btn b-btn-md b-btn-soft b-btn--full" style={{ height:52, justifyContent:'flex-start', gap:14, paddingInlineStart:16 }}
              onClick={() => { onAction('move', p); showToast(t('store_backed_up')); }}>
              <div style={{ width:34, height:34, borderRadius:'var(--radius-md)', background:STORAGE_CFG[p].bg, color:STORAGE_CFG[p].color, display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}>
                <Icon name={STORAGE_CFG[p].icon} size={18} />
              </div>
              <span style={{ flex:1, textAlign:'start', fontWeight:600, fontSize:'var(--pt-md)' }}>
                {t('store_move_to')} {STORAGE_CFG[p].label[lang]}
              </span>
              <Icon name="chevron-right" size={16} style={{ color:'var(--fg4)', transform: lang==='ar' ? 'scaleX(-1)' : 'none' }} />
            </button>
          ))}

          {/* Remove from cloud (keep local) */}
          {isCloud && (
            <button className="b-btn b-btn-md b-btn-secondary b-btn--full" style={{ height:52, justifyContent:'flex-start', gap:14, paddingInlineStart:16 }}
              onClick={() => { onAction('remove_cloud'); showToast(t('store_removed_cloud')); }}>
              <div style={{ width:34, height:34, borderRadius:'var(--radius-md)', background:'var(--balsm-ink-50)', color:'var(--fg2)', display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}>
                <Icon name="cloud-off" size={18} />
              </div>
              <span style={{ flex:1, textAlign:'start', fontWeight:600, fontSize:'var(--pt-md)', color:'var(--fg1)' }}>
                {t('store_remove_cloud')} <span style={{ fontWeight:400, color:'var(--fg3)', fontSize:'var(--pt-sm)' }}>· keep on device</span>
              </span>
            </button>
          )}

          {/* Remove from device (keep cloud) */}
          {isCloud && (
            <button className="b-btn b-btn-md b-btn-secondary b-btn--full" style={{ height:52, justifyContent:'flex-start', gap:14, paddingInlineStart:16 }}
              onClick={() => setConfirm('remove_dev')}>
              <div style={{ width:34, height:34, borderRadius:'var(--radius-md)', background:'var(--balsm-ink-50)', color:'var(--fg2)', display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}>
                <Icon name="smartphone" size={18} />
              </div>
              <span style={{ flex:1, textAlign:'start', fontWeight:600, fontSize:'var(--pt-md)', color:'var(--fg1)' }}>
                {t('store_remove_dev')} <span style={{ fontWeight:400, color:'var(--fg3)', fontSize:'var(--pt-sm)' }}>· keep in cloud</span>
              </span>
            </button>
          )}

          {/* Delete everywhere / Delete record */}
          <button className="b-btn b-btn-md" style={{ height:52, justifyContent:'flex-start', gap:14, paddingInlineStart:16, background:'var(--balsm-danger-bg)', color:'var(--balsm-danger)', border:'none' }}
            onClick={() => setConfirm('delete_all')}>
            <div style={{ width:34, height:34, borderRadius:'var(--radius-md)', background:'rgba(212,74,60,0.12)', color:'var(--balsm-danger)', display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}>
              <Icon name="trash-2" size={18} />
            </div>
            <span style={{ flex:1, textAlign:'start', fontWeight:600, fontSize:'var(--pt-md)' }}>
              {isCloud ? t('store_delete_all') : t('store_delete_rec')}
            </span>
          </button>
        </div>

        {/* Toast */}
        {toast && (
          <div style={{ position:'fixed', bottom:24, left:20, right:20, background:'var(--balsm-ink-900)', color:'#fff', borderRadius:'var(--radius-lg)', padding:'12px 16px', display:'flex', alignItems:'center', gap:10, zIndex:9600 }}>
            <Icon name="check-circle" size={18} style={{ color:'var(--petal-mint)', flexShrink:0 }} />
            <span style={{ fontSize:'var(--pt-sm)', fontWeight:600 }}>{toast}</span>
          </div>
        )}
      </div>
    </Modal>
  );
}
function AddRecordSheet({ onClose, onAdd, initialType = null }) {
  const { t, lang } = useApp();
  const [step, setStep]   = useState(initialType ? 'form' : 'type');   // type | form | done
  const [type, setType]   = useState(initialType);
  const [title, setTitle] = useState('');
  const [date, setDate]   = useState(() => new Date().toISOString().slice(0, 10));
  const [dateOpen, setDateOpen] = useState(false);
  const [time, setTime]   = useState(() => new Date().toTimeString().slice(0, 5));
  const { TimePicker } = dsCheck();
  const { DateTimeRow, CalIcon, ClockIcon, fmtRowDate, fmtRowTime } = window;
  const [files, setFiles] = useState([]);
  const [tags, setTags]   = useState([]);
  const [tagDraft, setTagDraft] = useState('');
  const fileRef = useRef(null);

  const SUGGESTED_TAGS = {
    lab:    [{ en: 'Diabetes', ar: 'السكري' }, { en: 'Cholesterol', ar: 'الكولسترول' }, { en: 'Kidney', ar: 'الكلى' }, { en: 'Thyroid', ar: 'الغدة' }],
    scan:   [{ en: 'Chest', ar: 'الصدر' }, { en: 'Abdomen', ar: 'البطن' }, { en: 'Bone', ar: 'العظام' }, { en: 'Follow-up', ar: 'متابعة' }],
    report: [{ en: 'Cardiology', ar: 'القلب' }, { en: 'Surgery', ar: 'جراحة' }, { en: 'Follow-up', ar: 'متابعة' }, { en: 'Referral', ar: 'تحويل' }],
  };

  const addTag = (label) => {
    const obj = typeof label === 'string' ? { en: label.trim(), ar: label.trim() } : label;
    const v = (obj.en || '').trim();
    if (!v) return;
    if (!tags.some(tg => (tg.en || '').toLowerCase() === v.toLowerCase() || (tg.ar || '') === (obj.ar || ''))) {
      setTags(prev => [...prev, { en: v, ar: obj.ar || v }]);
    }
    setTagDraft('');
  };
  const removeTag = (i) => setTags(prev => prev.filter((_, idx) => idx !== i));

  const fmtDate = (iso) => {
    const d = new Date(iso + 'T00:00:00');
    if (isNaN(d)) return { en: 'Today', ar: 'اليوم' };
    return {
      en: d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }),
      ar: d.toLocaleDateString('ar-EG', { day: '2-digit', month: 'long', year: 'numeric' }),
    };
  };

  const save = () => {
    onAdd({
      id: 'r' + Date.now(),
      type,
      title: { en: title || t(RECORD_TYPES[type].oneKey), ar: title || t(RECORD_TYPES[type].oneKey) },
      date: fmtDate(date),
      time,
      tags,
      sourceId: 'self',
      fileType: files.length ? ({ image: 'Image', video: 'Video', pdf: 'PDF', link: 'Link' }[files[0].kind] || 'File') : 'PDF',
      pages: 1,
      result: null,
      attachments: files,
      attachment: files[0] || null,
      photo: files[0] && files[0].kind === 'image' ? files[0].url : null,
    });
    setStep('done');
    setTimeout(onClose, 1600);
  };

  return (
    <>
      <style>{`@keyframes arSlideUp{from{transform:translateY(110%)}to{transform:none}}`}</style>
      <div className="app-scrim" onClick={onClose} style={{ position: 'absolute', inset: 0, zIndex: 40, background: 'rgba(20,32,43,0.36)', backdropFilter: 'blur(2px)' }} />
      <div className="app-sheet app-sheet--lg" style={{
        position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 41,
        background: '#fff', borderRadius: '20px 20px 0 0',
        maxHeight: '90%', display: 'flex', flexDirection: 'column',
        animation: 'arSlideUp 0.3s cubic-bezier(0.16,1,0.3,1) both',
      }}>
        <div style={{ padding: '10px 16px 0', flexShrink: 0 }}>
          {step === 'type' && <div className="sheet-grab" />}
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, paddingBottom: 10, borderBottom: '1px solid var(--balsm-ink-100)' }}>
            {step === 'form' && <button className="round-btn ghost" onClick={() => setStep('type')}><Icon name="arrow-left" size={18} /></button>}
            <div style={{ flex: 1, fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-lg)', color: 'var(--fg1)' }}>
              {step === 'done' ? '' : step === 'type' ? t('rec_pick_type') : t(RECORD_TYPES[type].oneKey)}
            </div>
            <button className="round-btn ghost" onClick={onClose}><Icon name="x" size={18} /></button>
          </div>
        </div>

        <div style={{ flex: 1, overflowY: 'auto', padding: '16px 20px 36px' }}>
          {/* Step: pick type */}
          {step === 'type' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {Object.entries(RECORD_TYPES).map(([key, conf]) => (
                <div key={key} onClick={() => { setType(key); setStep('form'); }} style={{
                  display: 'flex', alignItems: 'center', gap: 14, padding: '16px 16px',
                  border: '1.5px solid var(--balsm-border)', borderRadius: 'var(--radius-lg)', cursor: 'pointer',
                }}>
                  <div style={{ width: 46, height: 46, borderRadius: 'var(--radius-md)', background: conf.bg, color: conf.color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <Icon name={conf.icon} size={23} />
                  </div>
                  <div style={{ flex: 1, fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg1)' }}>{t(conf.oneKey)}</div>
                  <Icon name="chevron-right" size={18} style={{ color: 'var(--fg4)', transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
                </div>
              ))}
            </div>
          )}

          {/* Step: form */}
          {step === 'form' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
              <div className="field">
                <label>{t('rec_title')}</label>
                <input className="b-input" value={title} onChange={e => setTitle(e.target.value)} placeholder={t('rec_title_ph')} />
              </div>

              <div className="b-dtgroup">
                <button type="button" className="b-dtrow__head" onClick={() => setDateOpen(true)}>
                  <span className="b-dtrow__icon" style={{ background: 'var(--balsm-danger-50, #FCEAE7)', color: 'var(--balsm-danger, #D44A3C)' }}><CalIcon /></span>
                  <span className="b-dtrow__label">{t('rec_date')}</span>
                  <span className="b-dtrow__value" style={{ color: date ? 'var(--petal-blue)' : 'var(--fg3)' }}>
                    {date ? fmtRowDate(date, lang) : (lang === 'ar' ? 'اختر تاريخاً' : 'Select a date')}
                  </span>
                </button>
                {TimePicker && (
                  <DateTimeRow icon={<ClockIcon />} chipBg="var(--petal-blue-50, #E4F0FF)" chipColor="var(--petal-blue)"
                    label={lang === 'ar' ? 'الوقت' : 'Time'} valueText={fmtRowTime(time, lang)}>
                    <TimePicker value={time} onChange={setTime} use12Hour />
                  </DateTimeRow>
                )}
              </div>

              <div className="field">
                <label>{t('rec_tags')}</label>
                {tags.length > 0 && (
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 8 }}>
                    {tags.map((tg, i) => (
                      <span key={i} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, height: 30, padding: '0 6px 0 12px', borderRadius: 'var(--radius-pill)', background: 'var(--app-accent-50)', color: 'var(--app-accent-600)', fontSize: 'var(--pt-sm)', fontWeight: 600 }}>
                        {tg[lang] ?? tg.en ?? tg}
                        <button onClick={() => removeTag(i)} aria-label="Remove tag" style={{ width: 18, height: 18, borderRadius: 999, border: 'none', background: 'transparent', color: 'var(--app-accent-600)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                          <Icon name="x" size={13} />
                        </button>
                      </span>
                    ))}
                  </div>
                )}
                <input className="b-input" value={tagDraft}
                  onChange={e => setTagDraft(e.target.value)}
                  onKeyDown={e => { if (e.key === 'Enter' || e.key === ',') { e.preventDefault(); addTag(tagDraft); } }}
                  placeholder={t('rec_tags_ph')} />
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 8 }}>
                  {(SUGGESTED_TAGS[type] || []).filter(s => !tags.some(tg => (tg.en) === s.en)).map((s, i) => (
                    <button key={i} onClick={() => addTag(s)} style={{ display: 'inline-flex', alignItems: 'center', gap: 5, height: 30, padding: '0 12px', borderRadius: 'var(--radius-pill)', border: '1.5px dashed var(--balsm-border-strong)', background: '#fff', color: 'var(--fg2)', fontSize: 'var(--pt-sm)', fontWeight: 600, cursor: 'pointer', fontFamily: lang === 'ar' ? 'var(--font-arabic)' : 'var(--font-body)' }}>
                      <Icon name="plus" size={13} style={{ color: 'var(--fg3)' }} />{s[lang] ?? s.en}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label style={{ fontSize: 'var(--pt-sm)', fontWeight: 600, color: 'var(--fg2)', display: 'block', marginBottom: 8 }}>{t('rec_attach')}</label>
                <AttachmentInput inputRef={fileRef} onPick={picked => setFiles(f => [...f, ...picked])} />
                {files.length ? (
                  <AttachmentGallery atts={files} height={180}
                    onRemove={i => setFiles(f => f.filter((_, n) => n !== i))}
                    onAdd={() => fileRef.current?.click()} />
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12, padding: '26px 16px', border: '1.5px dashed var(--balsm-border-strong)', borderRadius: 'var(--radius-md)', background: 'var(--balsm-cream-50)' }}>
                    <Icon name="upload-cloud" size={30} style={{ color: 'var(--fg3)' }} />
                    <p className="meta" style={{ margin: 0, textAlign: 'center', lineHeight: 1.5 }}>{t('rec_attach_h')}</p>
                    <div style={{ display: 'flex', gap: 10, marginTop: 2 }}>
                      <button className="b-btn b-btn-md b-btn-soft" style={{ height: 42, fontSize: 'var(--pt-sm)' }} onClick={() => fileRef.current?.click()}><Icon name="camera" size={16} />{t('rec_take_photo')}</button>
                      <button className="b-btn b-btn-md b-btn-secondary" style={{ height: 42, fontSize: 'var(--pt-sm)' }} onClick={() => fileRef.current?.click()}><Icon name="folder" size={16} />{t('rec_from_files')}</button>
                    </div>
                  </div>
                )}
              </div>

              <button className="b-btn b-btn-lg b-btn-primary b-btn--full" onClick={save}>{t('add_record')}</button>
            </div>
          )}

          {/* Step: done */}
          {step === 'done' && (
            <div style={{ textAlign: 'center', padding: '20px 0 12px' }}>
              <div className="confirm-mark" style={{ width: 72, height: 72, margin: '0 auto 14px' }}><Icon name="check" size={36} /></div>
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', color: 'var(--fg1)', marginBottom: 8 }}>{t('rec_added')}</div>
              <p className="meta" style={{ margin: 0 }}>{t('rec_added_h')}</p>
            </div>
          )}
        </div>
      </div>
      {dateOpen && (
        <DobPicker lang={lang} value={date} initialYearsBack={0}
          title={lang === 'ar' ? 'تاريخ السجل' : 'Record date'}
          onPick={iso => setDate(iso)} onClose={() => setDateOpen(false)} />
      )}
    </>
  );
}

/* ── Records screen ─────────────────────────────────────── */
function RecordsScreen({ onBack }) {
  const { t, lang, recordStorageMap, pendingRecordType, clearPendingRecordType } = useApp();
  const [records, setRecords] = useState(HEALTH_RECORDS);
  const [filter, setFilter]   = useState('all');
  const [query, setQuery]     = useState('');
  const [selected, setSelected] = useState(null);
  const [addOpen, setAddOpen]   = useState(false);
  const [addType, setAddType]   = useState(null);
  useEffect(() => {
    if (pendingRecordType) { setAddType(pendingRecordType); setAddOpen(true); clearPendingRecordType(); }
  }, [pendingRecordType]);
  const [loading, setLoading]   = useState(true);
  useEffect(() => { const tm = setTimeout(() => setLoading(false), 700); return () => clearTimeout(tm); }, []);

  if (selected) return (
    <RecordDetail
      rec={selected}
      onBack={() => setSelected(null)}
      onDelete={(id) => { setRecords(prev => prev.filter(r => r.id !== id)); setSelected(null); }}
      onStorageChange={(id, st) => setRecords(prev => prev.map(r => r.id === id ? { ...r, storage: st } : r))}
    />
  );

  const byType = filter === 'all' ? records : records.filter(r => r.type === filter);
  const q = query.trim().toLowerCase();
  const shown = !q ? byType : byType.filter(r => {
    const doc = r.sourceId === 'self' ? null : DOCTORS.find(d => d.id === r.sourceId);
    const hay = [
      r.title?.en, r.title?.ar,
      r.result?.en, r.result?.ar,
      r.date?.en, r.date?.ar,
      doc?.name?.en, doc?.name?.ar,
      ...(r.tags || []).flatMap(tg => [tg.en, tg.ar, typeof tg === 'string' ? tg : '']),
    ].filter(Boolean).join(' ').toLowerCase();
    return hay.includes(q);
  });

  return (
    <div className="screen fade-in">
      <div className="pad-top" />
      <div className="appbar">
        <button className="round-btn" onClick={onBack} aria-label="Back">
          <Icon name="arrow-left" style={{ transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
        </button>
        <h1 style={{ flex: 1, margin: 0, fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', letterSpacing: '-0.01em', color: 'var(--fg1)' }}>{t('records')}</h1>
      </div>

      {/* Search */}
      <div style={{ padding: '0 20px 12px' }}>
        <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
          <Icon name="search" size={17} style={{ position: 'absolute', insetInlineStart: 14, color: 'var(--fg4)', pointerEvents: 'none' }} />
          <input className="b-input" value={query} onChange={e => setQuery(e.target.value)}
            placeholder={t('rec_search_ph')}
            style={{ paddingInlineStart: 40, paddingInlineEnd: query ? 40 : 14 }} />
          {query && (
            <button onClick={() => setQuery('')} aria-label={t('rec_search_clear')}
              style={{ position: 'absolute', insetInlineEnd: 8, width: 28, height: 28, borderRadius: 999, border: 'none', background: 'var(--balsm-ink-100)', color: 'var(--fg2)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="x" size={15} />
            </button>
          )}
        </div>
      </div>

      {/* Filter chips */}
      <div style={{ display: 'flex', gap: 8, padding: '0 20px 14px', overflowX: 'auto' }}>
        {REC_FILTERS.map(f => (
          <button key={f} onClick={() => setFilter(f)} style={{
            flexShrink: 0, height: 36, padding: '0 16px', borderRadius: 'var(--radius-pill)', cursor: 'pointer',
            border: `1.5px solid ${filter === f ? 'var(--app-accent)' : 'var(--balsm-border)'}`,
            background: filter === f ? 'var(--app-accent-50)' : '#fff',
            color: filter === f ? 'var(--app-accent-600)' : 'var(--fg2)',
            fontFamily: lang === 'ar' ? 'var(--font-arabic)' : 'var(--font-body)', fontSize: 'var(--pt-sm)', fontWeight: 600,
          }}>{f === 'all' ? t('all_records') : t(RECORD_TYPES[f].labelKey)}</button>
        ))}
      </div>

      <div className="screen-scroll" style={{ paddingTop: 0 }}>
        {loading ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '0 20px' }}>
            {[0,1,2,3,4].map(i => (
              <div key={i} className="card" style={{ padding: 14, display: 'flex', alignItems: 'center', gap: 13 }}>
                <DSSkeleton variant="rect" width={46} height={46} radius="var(--radius-md)" />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <DSSkeleton variant="title" width={`${64 - i * 6}%`} />
                  <div style={{ height: 6 }} />
                  <DSSkeleton variant="text" width="42%" />
                </div>
              </div>
            ))}
          </div>
        ) : shown.length > 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '0 20px' }}>
            {shown.map(rec => {
              const conf = RECORD_TYPES[rec.type];
              const doc = rec.sourceId === 'self' ? null : DOCTORS.find(d => d.id === rec.sourceId);
              return (
                <div key={rec.id} className="card" onClick={() => setSelected(rec)} style={{ padding: 14, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 13 }}>
                  <div style={{ width: 46, height: 46, borderRadius: 'var(--radius-md)', background: conf.bg, color: conf.color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <Icon name={conf.icon} size={22} />
                  </div>
                  <div className="grow" style={{ minWidth: 0 }}>
                    <div style={{ fontWeight: 600, fontSize: 'var(--pt-md)', color: 'var(--fg1)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{rec.title[lang]}</div>
                    <div style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg3)', marginTop: 2, display: 'flex', alignItems: 'center', gap: 6 }}>
                      <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{rec.date[lang]} · {doc ? doc.name[lang] : t('rec_self')}</span>
                      {(rec.attachment || rec.photo || (rec.attachments && rec.attachments.length)) && (
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, flexShrink: 0, color: 'var(--app-accent-600)', fontWeight: 600, fontSize: 'var(--pt-xs)' }}>
                          <Icon name="paperclip" size={12} />{rec.attachments && rec.attachments.length > 1 ? rec.attachments.length : rec.fileType}
                        </span>
                      )}
                    </div>
                  </div>
                  <StorageBadge storage={recordStorageMap[rec.id] || rec.storage || 'local'} size="xs" />
                  <Icon name="chevron-right" size={17} style={{ color: 'var(--fg4)', flexShrink: 0, transform: lang === 'ar' ? 'scaleX(-1)' : 'none' }} />
                </div>
              );
            })}
          </div>
        ) : (
          <div className="card" style={{ margin: '0 20px', padding: '36px 26px', textAlign: 'center' }}>
            <Icon name={(q || filter !== 'all') ? 'search-x' : 'folder-open'} size={36} style={{ color: 'var(--fg4)', display: 'block', margin: '0 auto 14px' }} />
            {(q || filter !== 'all') ? (
              <>
                <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg2)', marginBottom: 8 }}>{t('rec_no_results')}</div>
                <p className="meta" style={{ margin: '0 0 16px', lineHeight: 1.5 }}>{q ? `${t('rec_no_results_h')} "${query}"` : t('rec_no_results_h2')}</p>
                <button className="b-btn b-btn-md b-btn-soft" style={{ height: 42 }} onClick={() => { setQuery(''); setFilter('all'); }}><Icon name="rotate-ccw" size={16} />{t('rec_clear_filters')}</button>
              </>
            ) : (
              <>
                <div style={{ fontWeight: 700, fontSize: 'var(--pt-md)', color: 'var(--fg2)', marginBottom: 8 }}>{t('rec_empty')}</div>
                <p className="meta" style={{ margin: '0 0 16px', lineHeight: 1.5 }}>{t('rec_empty_h')}</p>
                <button className="b-btn b-btn-md b-btn-primary" style={{ height: 44 }} onClick={() => { setAddType(null); setAddOpen(true); }}><Icon name="plus" size={17} />{t('add_record')}</button>
              </>
            )}
          </div>
        )}
        <div style={{ height: 24 }} />
      </div>

      {/* Floating add-record FAB */}
      {!loading && records.length > 0 && (
        <button className="rec-fab" onClick={() => { setAddType(null); setAddOpen(true); }} aria-label={t('add_record')}>
          <Icon name="plus" size={24} stroke={2.4} />
        </button>
      )}

      {addOpen && <AddRecordSheet initialType={addType} onClose={() => { setAddOpen(false); setAddType(null); }} onAdd={(r) => setRecords(prev => [r, ...prev])} />}
    </div>
  );
}

Object.assign(window, { RecordsScreen, RecordDetail, AddRecordSheet, ManageStorageSheet });
