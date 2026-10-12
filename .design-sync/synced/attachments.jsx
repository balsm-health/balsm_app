/* attachments.jsx — shared attachment model, thumbnail card, and full-screen viewer
   Attachment: { url, kind: 'image'|'video'|'pdf'|'link', name, size? } */

const attKindOf = (file) => file.type.startsWith('image/') ? 'image' : file.type.startsWith('video/') ? 'video' : file.type === 'application/pdf' ? 'pdf' : 'link';
const attFromFile = (file) => ({ url: URL.createObjectURL(file), kind: attKindOf(file), name: file.name, size: file.size });
const attFmtSize = (b) => !b ? '' : b > 1048576 ? (b / 1048576).toFixed(1) + ' MB' : Math.max(1, Math.round(b / 1024)) + ' KB';
const ATT_ACCEPT = 'image/*,video/*,application/pdf';
const ATT_ICON = { image: 'image', video: 'video', pdf: 'file-text', link: 'link' };
const ATT_LABEL = { image: { en: 'Photo', ar: 'صورة' }, video: { en: 'Video', ar: 'فيديو' }, pdf: { en: 'PDF', ar: 'PDF' }, link: { en: 'Link', ar: 'رابط' } };

/* Thumbnail / row card. Tap → opens viewer. Optional onRemove shows an × badge. */
function AttachmentThumb({ att, height = 180, onRemove, onOpen, compact, style }) {
  const { lang } = useApp();
  const [open, setOpen] = useState(false);
  if (!att) return null;
  const visual = att.kind === 'image' || att.kind === 'video';
  const fire = () => onOpen ? onOpen() : setOpen(true);
  if (compact) return (
    <>
      <div onClick={fire} role="button" tabIndex={0} onKeyDown={e => e.key === 'Enter' && fire()} title={att.name || ''}
        style={{ position: 'relative', height, cursor: 'pointer', borderRadius: 'var(--radius-lg)', overflow: 'hidden', border: '1px solid var(--balsm-border)', background: visual ? 'var(--balsm-ink-800)' : 'var(--balsm-cream-50)', display: 'flex', alignItems: 'center', justifyContent: 'center', ...style }}>
        {att.kind === 'image' && <img src={att.url} alt={att.name || ''} style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />}
        {att.kind === 'video' && <video src={att.url} muted playsInline preload="metadata" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />}
        {!visual && (
          <div style={{ textAlign: 'center', padding: 8, color: 'var(--fg2)' }}>
            <Icon name={ATT_ICON[att.kind]} size={22} style={{ color: 'var(--petal-violet)' }} />
            <div style={{ fontSize: 'var(--pt-xs)', fontWeight: 600, marginTop: 4 }}>{ATT_LABEL[att.kind][lang]}</div>
          </div>
        )}
        {att.kind === 'video' && (
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', pointerEvents: 'none' }}>
            <div style={{ width: 30, height: 30, borderRadius: 999, background: 'rgba(31,45,61,0.72)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="play" size={14} /></div>
          </div>
        )}
        {onRemove && (
          <button onClick={e => { e.stopPropagation(); onRemove(); }} aria-label="Remove"
            style={{ position: 'absolute', top: 5, insetInlineEnd: 5, width: 24, height: 24, borderRadius: 999, background: 'rgba(31,45,61,0.65)', border: 'none', color: '#fff', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="x" size={12} />
          </button>
        )}
      </div>
      {open && <AttachmentViewer att={att} onClose={() => setOpen(false)} />}
    </>
  );
  return (
    <>
      <div onClick={fire} role="button" tabIndex={0} onKeyDown={e => e.key === 'Enter' && fire()}
        style={{ position: 'relative', cursor: 'pointer', borderRadius: 'var(--radius-lg)', overflow: 'hidden', border: '1px solid var(--balsm-border)', background: visual ? 'var(--balsm-ink-800)' : 'var(--balsm-surface)', ...style }}>
        {att.kind === 'image' && <img src={att.url} alt={att.name || ''} style={{ width: '100%', height, objectFit: 'cover', display: 'block' }} />}
        {att.kind === 'video' && <video src={att.url} muted playsInline preload="metadata" style={{ width: '100%', height, objectFit: 'cover', display: 'block' }} />}
        {visual && (
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', pointerEvents: 'none' }} key="badge">
            <div style={{ width: 44, height: 44, borderRadius: 999, background: 'rgba(31,45,61,0.72)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name={att.kind === 'video' ? 'play' : 'maximize-2'} size={20} />
            </div>
          </div>
        )}
        {!visual && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '14px 16px' }}>
            <div style={{ width: 42, height: 42, borderRadius: 'var(--radius-md)', background: 'var(--petal-violet-50)', color: 'var(--petal-violet)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <Icon name={ATT_ICON[att.kind]} size={20} />
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontWeight: 600, fontSize: 'var(--pt-sm)', color: 'var(--fg1)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} dir="ltr">{att.name || att.url}</div>
              <div style={{ fontSize: 'var(--pt-xs)', color: 'var(--fg3)', marginTop: 2 }}>{ATT_LABEL[att.kind][lang]}{att.size ? ` · ${attFmtSize(att.size)}` : ''}{att.pages > 1 ? ` · ${att.pages} ${lang === 'ar' ? 'صفحات' : 'pages'}` : ''}</div>
            </div>
            <Icon name="eye" size={18} style={{ color: 'var(--fg4)', flexShrink: 0 }} />
          </div>
        )}
        {visual && att.name && (
          <div style={{ position: 'absolute', insetInline: 0, bottom: 0, padding: '8px 12px', background: 'linear-gradient(transparent, rgba(31,45,61,0.7))', color: '#fff', fontSize: 'var(--pt-xs)', fontWeight: 600, display: 'flex', gap: 6, alignItems: 'center' }}>
            <Icon name={ATT_ICON[att.kind]} size={13} /><span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{att.name}</span>
          </div>
        )}
        {onRemove && (
          <button onClick={e => { e.stopPropagation(); onRemove(); }} aria-label="Remove"
            style={{ position: 'absolute', top: 8, insetInlineEnd: 8, width: 30, height: 30, borderRadius: 999, background: 'rgba(31,45,61,0.6)', border: 'none', color: '#fff', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="x" size={15} />
          </button>
        )}
      </div>
      {open && <AttachmentViewer att={att} onClose={() => setOpen(false)} />}
    </>
  );
}

/* A record's files, as a list. First file leads; the rest tile beneath it.
   Any tile opens the paging viewer at that index. */
function AttachmentGallery({ atts, height = 200, onRemove, onAdd, addLabel }) {
  const { lang } = useApp();
  const [at, setAt] = useState(-1);
  const list = (atts || []).filter(Boolean);
  if (!list.length && !onAdd) return null;
  const [lead, ...rest] = list;
  return (
    <div>
      {lead && (
        <div className="att-lead"><AttachmentThumb att={lead} height={height} onOpen={() => setAt(0)} onRemove={onRemove && (() => onRemove(0))} /></div>
      )}
      {(rest.length > 0 || onAdd) && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(108px, 1fr))', gap: 8, marginTop: 8 }}>
          {rest.map((a, i) => (
            <AttachmentThumb key={i} att={a} height={96} compact onOpen={() => setAt(i + 1)} onRemove={onRemove && (() => onRemove(i + 1))} />
          ))}
          {onAdd && (
            <button onClick={onAdd} style={{ height: lead ? 96 : 84, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 6, border: '1.5px dashed var(--balsm-border-strong)', borderRadius: 'var(--radius-lg)', background: 'var(--balsm-cream-50)', color: 'var(--fg2)', cursor: 'pointer', font: 'inherit', fontSize: 'var(--pt-xs)', fontWeight: 600 }}>
              <Icon name="plus" size={18} style={{ color: 'var(--fg3)' }} />
              {addLabel || (lang === 'ar' ? 'إضافة ملف' : 'Add file')}
            </button>
          )}
        </div>
      )}
      {list.length > 0 && (
        <div className="meta" style={{ marginTop: 8, display: 'flex', alignItems: 'center', gap: 5 }}>
          <Icon name="paperclip" size={12} />
          {list.length} {lang === 'ar' ? (list.length === 1 ? 'ملف' : 'ملفات') : (list.length === 1 ? 'file' : 'files')}
        </div>
      )}
      {at >= 0 && <AttachmentViewer atts={list} index={at} onClose={() => setAt(-1)} />}
    </div>
  );
}

/* Full-surface viewer. Image: fit + tap-to-zoom. Video: native controls. PDF: inline frame with open/download fallback.
   Takes a list + starting index so a record's files page in place. */
function AttachmentViewer({ att, atts, index = 0, title, onClose }) {
  const { lang } = useApp();
  const list = (atts && atts.length ? atts : [att]).filter(Boolean);
  const [i, setI] = useState(Math.min(Math.max(index, 0), list.length - 1));
  const cur = list[i] || list[0];
  const [zoom, setZoom] = useState(false);
  const [pdfOk, setPdfOk] = useState(true);
  const [host, setHost] = useState(null);
  const anchor = useRef(null);
  const step = (d) => { setI(v => (v + d + list.length) % list.length); setZoom(false); setPdfOk(true); };
  useEffect(() => {
    const k = e => {
      if (e.key === 'Escape') onClose();
      if (list.length > 1 && (e.key === 'ArrowRight' || e.key === 'ArrowLeft')) step(e.key === 'ArrowRight' ? 1 : -1);
    };
    window.addEventListener('keydown', k); return () => window.removeEventListener('keydown', k);
  }, [list.length]);
  // Portal to the app root so the viewer covers nav rail + content at every window class
  useEffect(() => { setHost(anchor.current ? anchor.current.closest('.app-body') : null); }, []);
  return <><span ref={anchor} style={{ display: 'none' }} />{host ? ReactDOM.createPortal(
    <AttViewerBody att={cur} list={list} i={i} step={step} title={title} onClose={onClose}
      zoom={zoom} setZoom={setZoom} pdfOk={pdfOk} setPdfOk={setPdfOk} lang={lang} />, host) : null}</>;
}
function AttViewerBody({ att, list, i, step, title, onClose, zoom, setZoom, pdfOk, setPdfOk, lang }) {
  const many = list.length > 1;
  const label = att.name || title || ATT_LABEL[att.kind][lang];
  const isLink = att.kind === 'link';
  return (
    <div className="att-viewer" role="dialog" aria-label={label}>
      <div className="att-bar">
        <button className="att-ibtn" onClick={onClose} aria-label={lang === 'ar' ? 'إغلاق' : 'Close'}><Icon name="x" size={22} /></button>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontWeight: 600, fontSize: 'var(--pt-md)', color: '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{label}</div>
          <div style={{ fontSize: 'var(--pt-xs)', color: 'rgba(255,255,255,0.7)' }}>
            {ATT_LABEL[att.kind][lang]}{att.size ? ` · ${attFmtSize(att.size)}` : ''}
            {many && <span dir="ltr" style={{ fontFamily: 'var(--font-mono)' }}> · {i + 1}/{list.length}</span>}
          </div>
        </div>
        <a className="att-ibtn" href={att.url} download={att.name || true} aria-label={lang === 'ar' ? 'تنزيل' : 'Download'}><Icon name="download" size={20} /></a>
        <a className="att-ibtn" href={att.url} target="_blank" rel="noopener noreferrer" aria-label={lang === 'ar' ? 'فتح' : 'Open'}><Icon name="external-link" size={20} /></a>
      </div>
      <div className="att-stage" onClick={att.kind === 'image' ? () => setZoom(z => !z) : undefined} style={{ cursor: att.kind === 'image' ? (zoom ? 'zoom-out' : 'zoom-in') : 'default' }}>
        {att.kind === 'image' && (
          <div className="att-scroll" style={{ overflow: zoom ? 'auto' : 'hidden' }}>
            <img src={att.url} alt={label} draggable={false} style={zoom ? { maxWidth: 'none', width: '200%', display: 'block' } : { maxWidth: '100%', maxHeight: '100%', objectFit: 'contain', display: 'block', margin: 'auto' }} />
          </div>
        )}
        {att.kind === 'video' && <video src={att.url} controls autoPlay playsInline style={{ maxWidth: '100%', maxHeight: '100%', outline: 'none' }} />}
        {att.kind === 'pdf' && (pdfOk ? (
          <iframe title={label} src={att.url + '#toolbar=0&view=FitH'} className="att-pdf" onError={() => setPdfOk(false)} />
        ) : <AttFallback att={att} lang={lang} />)}
        {isLink && <AttFallback att={att} lang={lang} />}
        {many && (
          <>
            <button className="att-nav att-nav-prev" onClick={e => { e.stopPropagation(); step(-1); }} aria-label={lang === 'ar' ? 'السابق' : 'Previous'}><Icon name="chevron-left" size={24} /></button>
            <button className="att-nav att-nav-next" onClick={e => { e.stopPropagation(); step(1); }} aria-label={lang === 'ar' ? 'التالي' : 'Next'}><Icon name="chevron-right" size={24} /></button>
          </>
        )}
      </div>
      {many && (
        <div className="att-strip">
          {list.map((a, n) => (
            <button key={n} className={cx('att-chip', n === i && 'on')} onClick={() => step(n - i)} aria-current={n === i}>
              {a.kind === 'image' ? <img src={a.url} alt="" />
                : a.kind === 'video' ? <video src={a.url} muted preload="metadata" />
                : <Icon name={ATT_ICON[a.kind]} size={18} />}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
function AttFallback({ att, lang }) {
  return (
    <div style={{ textAlign: 'center', color: '#fff', padding: 24, maxWidth: 360 }}>
      <div style={{ width: 72, height: 72, borderRadius: 'var(--radius-lg)', background: 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px' }}><Icon name={ATT_ICON[att.kind]} size={34} /></div>
      <div style={{ fontWeight: 600, marginBottom: 6 }} dir="ltr">{att.name || att.url}</div>
      <p style={{ margin: '0 0 18px', color: 'rgba(255,255,255,0.7)', fontSize: 'var(--pt-sm)' }}>{lang === 'ar' ? 'لا يمكن عرض هذا الملف هنا. افتحه في تطبيق آخر.' : "This file can't be shown here. Open it in another app."}</p>
      <a className="b-btn b-btn-md b-btn-primary" href={att.url} target="_blank" rel="noopener noreferrer"><Icon name="external-link" size={16} />{lang === 'ar' ? 'فتح' : 'Open'}</a>
    </div>
  );
}

/* Attach picker — hidden input + button(s); returns Attachment via onPick */
function AttachmentInput({ inputRef, onPick, accept = ATT_ACCEPT, multiple = true }) {
  return <input ref={inputRef} type="file" accept={accept} multiple={multiple} style={{ display: 'none' }}
    onChange={e => { const fs = [...e.target.files]; if (fs.length) onPick(multiple ? fs.map(attFromFile) : attFromFile(fs[0])); e.target.value = ''; }} />;
}

Object.assign(window, { AttachmentThumb, AttachmentGallery, AttachmentViewer, AttachmentInput, attFromFile, attKindOf, attFmtSize, ATT_ACCEPT, ATT_ICON, ATT_LABEL });
