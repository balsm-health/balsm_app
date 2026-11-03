/* delete-kit.jsx — shared delete pattern: swipe row, ⋮ menu, multi-select, confirm dialog, done toast */
/* ── Swipe-to-delete row. Drag toward inline-start reveals Delete; a long swipe deletes. ── */
function SwipeRow({ rtl, open, onOpen, onClose, onDelete, deleteLabel, radius, style, children, disabled, onLongPress, contentProps }) {
  const REVEAL = 88;
  const dir = rtl ? 1 : -1;
  const wrap = useRef(null);
  const st = useRef(null);
  const [drag, setDrag] = useState(null);
  const lp = useRef(null), lpFired = useRef(false);
  const clearLp = () => { clearTimeout(lp.current); lp.current = null; };
  useEffect(() => clearLp, []);
  const offset = drag !== null ? drag : (open ? dir * REVEAL : 0);
  const amt = Math.max(0, offset * dir);
  const down = (e) => {
    if (disabled || e.button > 0 || e.target.closest('button')) return;
    lpFired.current = false;
    st.current = { x: e.clientX, y: e.clientY, base: open ? dir * REVEAL : 0, engaged: false, id: e.pointerId };
    if (onLongPress) lp.current = setTimeout(() => { lpFired.current = true; st.current = null; onLongPress(); }, 480);
  };
  const move = (e) => {
    const s = st.current; if (!s) return;
    const scale = wrap.current ? wrap.current.getBoundingClientRect().width / wrap.current.offsetWidth || 1 : 1;
    const dx = (e.clientX - s.x) / scale, dy = (e.clientY - s.y) / scale;
    if (Math.abs(dx) > 8 || Math.abs(dy) > 8) clearLp();
    if (!s.engaged) {
      if (Math.abs(dy) > 10 && Math.abs(dy) > Math.abs(dx)) { st.current = null; return; }
      if (Math.abs(dx) < 8) return;
      s.engaged = true; e.currentTarget.setPointerCapture(s.id);
    }
    const w = wrap.current ? wrap.current.offsetWidth : 320;
    const v = Math.max(0, Math.min(w, (s.base + dx) * dir));
    setDrag(v * dir);
  };
  const up = () => {
    clearLp();
    const s = st.current; st.current = null;
    if (!s || !s.engaged) return;
    const w = wrap.current ? wrap.current.offsetWidth : 320;
    const a = Math.abs(drag || 0);
    setDrag(null);
    if (a > w * 0.5) onDelete();
    else if (a > REVEAL / 2) onOpen();
    else onClose();
  };
  const clickCapture = (e) => {
    if (lpFired.current) { lpFired.current = false; e.stopPropagation(); e.preventDefault(); return; }
    if (open && !e.target.closest('button')) { e.stopPropagation(); onClose(); }
  };
  return (
    <div ref={wrap} style={{ position: 'relative', overflow: 'hidden', borderRadius: radius, ...style }}>
      <button type="button" onClick={onDelete} tabIndex={-1} aria-hidden="true" style={{
        position: 'absolute', top: 0, bottom: 0, insetInlineEnd: 0, width: Math.max(REVEAL, amt),
        border: 'none', background: 'var(--balsm-danger)', color: '#fff', cursor: 'pointer', fontFamily: 'inherit',
        display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4,
        fontSize: 'var(--pt-xs)', fontWeight: 700, opacity: amt > 0 ? 1 : 0,
      }}>
        <Icon name="trash-2" size={20} />{deleteLabel}
      </button>
      <div {...(contentProps || {})} onPointerDown={down} onPointerMove={move} onPointerUp={up} onPointerCancel={up} onClickCapture={clickCapture}
        onContextMenu={e => { if (onLongPress) e.preventDefault(); }}
        style={{ position: 'relative', transform: `translateX(${offset}px)`, transition: drag !== null ? 'none' : 'transform 200ms cubic-bezier(0.16,1,0.3,1)', touchAction: 'pan-y', cursor: contentProps ? 'pointer' : undefined, WebkitUserSelect: 'none', userSelect: 'none' }}>
        {children}
      </div>
    </div>
  );
}


function kitCount(ar, n, fa, fe) {
  if (ar) return n === 1 ? fa.one : n === 2 ? fa.two : n <= 10 ? `${n} ${fa.few}` : `${n} ${fa.many}`;
  return n === 1 ? `1 ${fe.one}` : `${n} ${fe.other}`;
}

/* items: live [{ key, lab }]. onDelete(keys). titleOne(item) / bodyFor(keys) return strings. */
function useDeleteKit({ ar, items, onDelete, nounAr, nounEn, titleOne, bodyFor }) {
  const [openKey, setOpenKey] = useState(null);
  const [menu, setMenu] = useState(null);
  const [confirm, setConfirm] = useState(null);
  const [selecting, setSelecting] = useState(false);
  const [sel, setSel] = useState(() => new Set());
  const [toast, setToast] = useState(null);
  const toastTimer = useRef(null);
  const wrapRef = useRef(null);
  useEffect(() => () => clearTimeout(toastTimer.current), []);
  const count = (n) => kitCount(ar, n, nounAr, nounEn);
  const startSelect = (k) => { setMenu(null); setOpenKey(null); setSelecting(true); setSel(new Set(k ? [k] : [])); };
  const exitSelect = () => { setSelecting(false); setSel(new Set()); };
  const toggle = (k) => setSel(x => { const n = new Set(x); n.has(k) ? n.delete(k) : n.add(k); return n; });
  const allOn = items.length > 0 && items.every(x => sel.has(x.key));
  useEffect(() => {
    if (!menu && !confirm && !selecting) return;
    const k = (e) => {
      if (e.key !== 'Escape') return;
      e.preventDefault();
      if (confirm) { setConfirm(null); setOpenKey(null); } else if (menu) setMenu(null); else exitSelect();
    };
    window.addEventListener('keydown', k); return () => window.removeEventListener('keydown', k);
  }, [menu, confirm, selecting]);

  const askDel = (it) => { setMenu(null); setConfirm({ keys: [it.key], item: it }); };
  const askDelSelected = () => {
    const keys = items.filter(x => sel.has(x.key)).map(x => x.key);
    if (!keys.length) return;
    setConfirm({ keys, item: keys.length === 1 ? items.find(x => x.key === keys[0]) : null });
  };
  const doDelete = () => {
    const c = confirm; if (!c) return;
    setConfirm(null); setOpenKey(null);
    onDelete(c.keys);
    const label = c.item ? c.item.lab : count(c.keys.length);
    setToast({ text: ar ? `تم حذف ${label}` : `${label} deleted`, id: Date.now() });
    clearTimeout(toastTimer.current); toastTimer.current = setTimeout(() => setToast(null), 2500);
    exitSelect();
  };
  const openMenu = (it, e) => {
    e.stopPropagation();
    setOpenKey(null);
    const wEl = wrapRef.current; if (!wEl) return;
    const w = wEl.getBoundingClientRect(), b = e.currentTarget.getBoundingClientRect();
    const sc = w.width / wEl.offsetWidth || 1;
    const below = (b.bottom - w.top) / sc + 4;
    const end = ar ? (b.left - w.left) / sc : (w.right - b.right) / sc;
    setMenu({ it, pos: below + 64 > wEl.offsetHeight - 16 ? { bottom: (w.bottom - b.top) / sc + 4, end } : { top: below, end } });
  };
  const swipe = (it) => ({
    rtl: ar, open: openKey === it.key,
    onOpen: () => setOpenKey(it.key), onClose: () => setOpenKey(k => k === it.key ? null : k),
    onDelete: () => askDel(it), deleteLabel: ar ? 'حذف' : 'Delete',
    disabled: selecting, onLongPress: selecting ? null : () => startSelect(it.key),
    contentProps: selecting ? {
      role: 'checkbox', 'aria-checked': sel.has(it.key), 'aria-label': it.lab, tabIndex: 0,
      onClick: (ev) => { ev.stopPropagation(); toggle(it.key); },
      onKeyDown: (ev) => { if (ev.key === ' ' || ev.key === 'Enter') { ev.preventDefault(); toggle(it.key); } },
    } : null,
  });
  const Check = ({ k }) => {
    const on = sel.has(k);
    return (
      <span aria-hidden="true" style={{
        width: 24, height: 24, borderRadius: 7, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
        border: on ? 'none' : '2px solid var(--balsm-ink-300)', background: on ? 'var(--balsm-primary)' : '#fff', color: '#fff',
        transition: 'background 120ms cubic-bezier(0.16,1,0.3,1)',
      }}>{on && <Icon name="check" size={16} strokeWidth={2.5} />}</span>
    );
  };
  const More = ({ it }) => (
    <button type="button" className="round-btn ghost" onClick={(e) => openMenu(it, e)}
      aria-haspopup="menu" aria-expanded={!!(menu && menu.it.key === it.key)}
      aria-label={ar ? `خيارات ${it.lab}` : `${it.lab} options`} style={{ flexShrink: 0, marginInlineEnd: -10, width: 36 }}>
      <Icon name="ellipsis-vertical" size={18} style={{ color: 'var(--fg3)' }} />
    </button>
  );
  const selectButton = items.length > 0 && (
    <button type="button" className="round-btn" onClick={() => startSelect(null)} aria-label={ar ? 'تحديد' : 'Select'} title={ar ? 'تحديد' : 'Select'} style={{ flexShrink: 0 }}>
      <Icon name="list-checks" size={19} />
    </button>
  );
  const selectAppbar = (
    <div className="appbar">
      <button className="round-btn" onClick={exitSelect} aria-label={ar ? 'إنهاء التحديد' : 'Done selecting'}><Icon name="x" /></button>
      <h1 className="grow" aria-live="polite" style={{ flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', margin: 0, fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-xl)', color: 'var(--fg1)' }}>
        {sel.size > 0 ? (ar ? `${sel.size} محدد` : `${sel.size} selected`) : (ar ? 'حدد العناصر' : 'Select items')}
      </h1>
      <button type="button" className="b-btn b-btn-sm b-btn-ghost" onClick={() => setSel(allOn ? new Set() : new Set(items.map(x => x.key)))} style={{ flexShrink: 0, minHeight: 44 }}>
        {allOn ? (ar ? 'إلغاء الكل' : 'Clear all') : (ar ? 'تحديد الكل' : 'Select all')}
      </button>
    </div>
  );
  const overlays = (
    <>
      {menu && (
        <>
          <div onClick={() => setMenu(null)} style={{ position: 'absolute', inset: 0, zIndex: 40 }} />
          <div role="menu" aria-label={menu.it.lab} style={{
            position: 'absolute', zIndex: 41, insetInlineEnd: menu.pos.end, top: menu.pos.top, bottom: menu.pos.bottom,
            minWidth: 184, padding: 6, background: '#fff', borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-lg)',
            border: '1px solid var(--balsm-ink-100)', animation: 'kitIn 120ms cubic-bezier(0.16,1,0.3,1) both',
          }}>
            <style>{`@keyframes kitIn{from{opacity:0;transform:scale(0.98)}to{opacity:1;transform:none}}@keyframes kitFade{from{opacity:0}to{opacity:1}}`}</style>
            <button type="button" role="menuitem" autoFocus onClick={() => askDel(menu.it)} style={{
              width: '100%', height: 44, display: 'flex', alignItems: 'center', gap: 10, padding: '0 12px', border: 'none', borderRadius: 'var(--radius-md)',
              background: 'transparent', color: 'var(--balsm-danger)', fontWeight: 600, fontSize: 'var(--pt-md)', cursor: 'pointer', fontFamily: 'inherit', textAlign: 'start',
            }}
            onPointerEnter={e => e.currentTarget.style.background = 'var(--balsm-danger-bg)'}
            onPointerLeave={e => e.currentTarget.style.background = 'transparent'}>
              <Icon name="trash-2" size={18} />{ar ? 'حذف' : 'Delete'}
            </button>
          </div>
        </>
      )}
      {selecting && (
        <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, zIndex: 20, background: '#fff', borderTop: '1px solid var(--balsm-ink-100)', padding: '12px 16px 24px', boxShadow: '0 -6px 18px rgba(20,32,43,0.06)' }}>
          <button className={cx('b-btn b-btn-lg b-btn-danger b-btn--full', sel.size === 0 && 'is-disabled')} disabled={sel.size === 0} onClick={askDelSelected}
            style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
            <Icon name="trash-2" size={18} />
            {sel.size === 0 ? (ar ? 'حذف' : 'Delete') : (ar ? `حذف ${count(sel.size)}` : `Delete ${count(sel.size)}`)}
          </button>
        </div>
      )}
      {confirm && (
        <div onClick={() => { setConfirm(null); setOpenKey(null); }} style={{ position: 'absolute', inset: 0, zIndex: 50, background: 'rgba(20,32,43,0.38)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24, animation: 'kitFade 160ms cubic-bezier(0.16,1,0.3,1) both' }}>
          <style>{`@keyframes kitFade{from{opacity:0}to{opacity:1}}`}</style>
          <div role="alertdialog" aria-modal="true" aria-labelledby="kit-del-t" aria-describedby="kit-del-d" onClick={ev => ev.stopPropagation()}
            style={{ width: '100%', maxWidth: 340, background: '#fff', borderRadius: 'var(--radius-xl)', padding: '22px 20px 18px', boxShadow: 'var(--shadow-lg)' }}>
            <div style={{ width: 44, height: 44, borderRadius: 'var(--radius-md)', background: 'var(--balsm-danger-bg)', color: 'var(--balsm-danger)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 14 }}>
              <Icon name="trash-2" size={22} />
            </div>
            <div id="kit-del-t" style={{ fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-lg)', color: 'var(--fg1)', marginBottom: 6, lineHeight: 1.35 }}>
              {confirm.item ? titleOne(confirm.item) : (ar ? `حذف ${count(confirm.keys.length)}؟` : `Delete ${count(confirm.keys.length)}?`)}
            </div>
            <div id="kit-del-d" style={{ fontSize: 'var(--pt-sm)', color: 'var(--fg2)', lineHeight: 1.5, marginBottom: 20 }}>{bodyFor(confirm.keys)}</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              <button className="b-btn b-btn-lg b-btn-danger b-btn--full" onClick={doDelete}>{ar ? 'حذف' : 'Delete'}</button>
              <button className="b-btn b-btn-lg b-btn-secondary b-btn--full" autoFocus onClick={() => { setConfirm(null); setOpenKey(null); }}>{ar ? 'إلغاء' : 'Cancel'}</button>
            </div>
          </div>
        </div>
      )}
      {toast && (
        <div role="status" aria-live="polite" key={toast.id} style={{
          position: 'absolute', bottom: 24, insetInline: 16, zIndex: 30, display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px',
          background: 'var(--balsm-ink-800)', color: '#fff', borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-lg)',
        }}>
          <Icon name="check" size={17} style={{ flexShrink: 0, color: 'var(--petal-mint)' }} />
          <span style={{ flex: 1, minWidth: 0, fontSize: 'var(--pt-sm)', fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{toast.text}</span>
        </div>
      )}
    </>
  );
  return { wrapRef, selecting, sel, swipe, Check, More, askDel, selectButton, selectAppbar, overlays };
}

Object.assign(window, { SwipeRow, useDeleteKit, kitCount });
