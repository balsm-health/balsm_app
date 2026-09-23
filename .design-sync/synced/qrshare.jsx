/* qrshare.jsx — shareable patient QR (handle deep-link) with Balsm flower mark
   centered inside it. Loaded after dialcodes.jsx, before home.jsx.
   Exposes QRCanvas and QRShareSheet on window. */

/* Rounded-module QR painter. Leaves a clear square in the center for the logo. */
function QRCanvas({ value, size = 240, fg = '#1A1A17', bg = '#ffffff', clearCenter = 0.26 }) {
  const ref = useRef(null);
  useEffect(() => {
    const cv = ref.current;
    if (!cv || !window.qrcode) return;
    const dpr = Math.min(3, window.devicePixelRatio || 1);
    const qr = window.qrcode(0, 'H');
    qr.addData(value || ' ');
    qr.make();
    const n = qr.getModuleCount();
    cv.width = size * dpr; cv.height = size * dpr;
    cv.style.width = size + 'px'; cv.style.height = size + 'px';
    const ctx = cv.getContext('2d');
    ctx.scale(dpr, dpr);
    ctx.clearRect(0, 0, size, size);

    const quiet = 0;
    const cell = (size - quiet * 2) / n;
    const clearN = Math.round(n * clearCenter);
    const c0 = Math.floor((n - clearN) / 2), c1 = c0 + clearN;

    const dot = (cx, cy, r) => { ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.fill(); };
    const finder = (ox, oy) => {
      ctx.fillStyle = fg;
      roundRect(ctx, ox, oy, cell * 7, cell * 7, cell * 2.2); ctx.fill();
      ctx.fillStyle = bg;
      roundRect(ctx, ox + cell, oy + cell, cell * 5, cell * 5, cell * 1.6); ctx.fill();
      ctx.fillStyle = fg;
      roundRect(ctx, ox + cell * 2, oy + cell * 2, cell * 3, cell * 3, cell * 1.1); ctx.fill();
    };

    ctx.fillStyle = fg;
    for (let r = 0; r < n; r++) {
      for (let cms = 0; cms < n; cms++) {
        if (!qr.isDark(r, cms)) continue;
        // skip the three finder zones (drawn separately) + clear center
        const inFinder = (r < 7 && cms < 7) || (r < 7 && cms >= n - 7) || (r >= n - 7 && cms < 7);
        if (inFinder) continue;
        if (r >= c0 && r < c1 && cms >= c0 && cms < c1) continue;
        const x = quiet + cms * cell + cell / 2;
        const y = quiet + r * cell + cell / 2;
        dot(x, y, cell * 0.42);
      }
    }
    finder(quiet, quiet);
    finder(quiet + (n - 7) * cell, quiet);
    finder(quiet, quiet + (n - 7) * cell);
  }, [value, size, fg, bg, clearCenter]);

  return <canvas ref={ref} style={{ display: 'block' }} />;
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

function QRShareSheet({ onClose, handle, name }) {
  const { lang } = useApp();
  const url = `https://balsm.health/@${handle || ''}`;
  const [copied, setCopied] = useState(false);
  const cardRef = useRef(null);

  const share = async () => {
    const shareData = {
      title: 'Balsm',
      text: lang === 'ar' ? `تواصل معي على بَلسَم: @${handle}` : `Connect with me on Balsm: @${handle}`,
      url,
    };
    if (navigator.share) { try { await navigator.share(shareData); return; } catch {} }
    navigator.clipboard?.writeText(url);
    setCopied(true); setTimeout(() => setCopied(false), 2200);
  };

  const download = async () => {
    if (!window.html2canvas || !cardRef.current) return;
    try {
      const canvas = await window.html2canvas(cardRef.current, { scale: 3, backgroundColor: null, logging: false });
      const a = Object.assign(document.createElement('a'), {
        href: canvas.toDataURL('image/png'), download: `balsm-${handle || 'qr'}.png`,
      });
      a.click();
    } catch {}
  };

  return (
    <>
      <style>{`@keyframes qrUp{from{transform:translateY(110%)}to{transform:none}}`}</style>
      <div className="app-scrim" onClick={onClose} style={{ position: 'absolute', inset: 0, zIndex: 60, background: 'rgba(20,32,43,0.42)' }} />
      <div className="app-sheet" style={{
        position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 61,
        background: '#FAFAF7', borderRadius: '20px 20px 0 0',
        display: 'flex', flexDirection: 'column', maxHeight: '92%',
        animation: 'qrUp 0.3s cubic-bezier(0.16,1,0.3,1) both',
      }}>
        <div style={{ padding: '10px 20px 0', flexShrink: 0 }}>
          <div className="sheet-grab" style={{ margin: '0 auto 12px' }} />
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: 8 }}>
            <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-lg)', color: 'var(--fg1)' }}>
              {lang === 'ar' ? 'رمز المشاركة' : 'My QR code'}
            </div>
            <button className="round-btn ghost" onClick={onClose}><Icon name="x" size={17} /></button>
          </div>
        </div>

        <div style={{ flex: 1, overflowY: 'auto', padding: '6px 20px calc(env(safe-area-inset-bottom, 0px) + 22px)' }}>
          <p className="body" style={{ margin: '0 0 18px', color: 'var(--fg3)', fontSize: 'var(--pt-sm)' }}>
            {lang === 'ar'
              ? 'امسح هذا الرمز لمشاركة ملفك الصحي بأمان مع طبيبك أو عائلتك — أو ليضيفك أحد أفراد أسرتك إلى حسابه.'
              : 'Scan this code to securely share your health profile with a doctor — or to let a family member add you to their account.'}
          </p>

          {/* QR card */}
          <div ref={cardRef} style={{
            background: '#fff', borderRadius: 'var(--radius-xl, 24px)',
            border: '1px solid var(--balsm-ink-100)', padding: '26px 24px 22px',
            display: 'flex', flexDirection: 'column', alignItems: 'center',
            boxShadow: '0 6px 24px rgba(20,32,43,0.07)',
          }}>
            <div style={{ position: 'relative', width: 240, height: 240 }}>
              <QRCanvas value={url} size={240} fg="#14202B" clearCenter={0.37} />
              {/* Center flower mark (wordmark cropped) with white halo */}
              <div style={{
                position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%,-50%)',
                width: 86, height: 60, borderRadius: 16, background: '#fff',
                display: 'flex', alignItems: 'flex-start', justifyContent: 'center',
                overflow: 'hidden', boxShadow: '0 0 0 6px #fff',
              }}>
                <img src={window.__resources ? window.__resources['icon'] : 'assets/icon.svg?v=5'} alt="Balsm" style={{ width: 86, height: 86, objectFit: 'contain', marginTop: 1, flexShrink: 0 }} />
              </div>
            </div>
            <div style={{ marginTop: 18, textAlign: 'center' }}>
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-lg)', color: 'var(--fg1)' }}>
                {name || ''}
              </div>
              <div dir="ltr" style={{ fontFamily: 'var(--font-mono)', fontSize: 'var(--pt-sm)', color: 'var(--app-accent)', marginTop: 3 }}>
                @{handle || ''}
              </div>
            </div>
          </div>

          {/* Link row */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 16, padding: '12px 14px', background: '#fff', border: '1px solid var(--balsm-ink-100)', borderRadius: 'var(--radius-lg)' }}>
            <Icon name="link" size={16} style={{ color: 'var(--fg3)', flexShrink: 0 }} />
            <span dir="ltr" style={{ flex: 1, minWidth: 0, fontFamily: 'var(--font-mono)', fontSize: 'var(--pt-sm)', color: 'var(--fg2)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              balsm.health/@{handle || ''}
            </span>
            <button onClick={() => { navigator.clipboard?.writeText(url); setCopied(true); setTimeout(() => setCopied(false), 2200); }}
              className="b-btn b-btn-md b-btn-ghost" style={{ flexShrink: 0, height: 30, padding: '0 8px', fontSize: 'var(--pt-xs)', color: 'var(--app-accent)', fontWeight: 700, gap: 5 }}>
              <Icon name={copied ? 'check' : 'copy'} size={14} />{copied ? (lang === 'ar' ? 'تم' : 'Copied') : (lang === 'ar' ? 'نسخ' : 'Copy')}
            </button>
          </div>

          {/* Actions */}
          <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
            <button className="b-btn b-btn-lg b-btn-secondary" style={{ flex: 1, gap: 8 }} onClick={download}>
              <Icon name="download" size={17} />{lang === 'ar' ? 'حفظ' : 'Save'}
            </button>
            <button className="b-btn b-btn-lg b-btn-primary" style={{ flex: 1, gap: 8 }} onClick={share}>
              <Icon name="share-2" size={17} />{lang === 'ar' ? 'مشاركة' : 'Share'}
            </button>
          </div>
        </div>
      </div>
    </>
  );
}

Object.assign(window, { QRCanvas, QRShareSheet });
