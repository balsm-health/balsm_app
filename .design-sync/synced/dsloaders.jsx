/* dsloaders.jsx — Balsm DS loading / progress React components.
   Loaded after base.jsx (needs window.React) and ds-loaders.css.
   Exposes the component set on window for the rest of the app.       */

/* ── Linear progress ─────────────────────────────────────────── */
function DSProgress({ value, variant = 'primary', size = 'md', label, showValue = false,
  indeterminate, striped = false, state, className = '', style }) {
  const stateStriped = state === 'syncing';
  const isIndet = indeterminate != null ? indeterminate : (value == null);
  const pct = isIndet ? null : Math.max(0, Math.min(100, value));
  const cls = ['b-progress', `b-progress--${variant}`, size !== 'md' && `b-progress--${size}`,
    isIndet && 'b-progress--indeterminate', (striped || stateStriped) && 'b-progress--striped',
    state === 'paused' && 'b-progress--paused', state === 'queued' && 'b-progress--queued', className]
    .filter(Boolean).join(' ');
  return (
    <div className={cls} style={style} role="progressbar" aria-valuenow={isIndet ? undefined : pct}>
      {(label || showValue) && (
        <div className="b-progress__head">
          {label && <span className="b-progress__label">{label}</span>}
          {showValue && !isIndet && <span className="b-progress__value">{Math.round(pct)}%</span>}
        </div>
      )}
      <div className="b-progress__track">
        <span className="b-progress__fill" style={isIndet ? undefined : { width: `${pct}%` }} />
      </div>
    </div>
  );
}

/* ── Five-petal brand spinner ────────────────────────────────── */
function DSPetalSpinner({ size = 'md', label, className = '', style }) {
  const sizeCls = typeof size === 'string' ? `b-petal-spinner--${size}` : '';
  const sizeStyle = typeof size === 'number' ? { width: size, height: size } : undefined;
  const node = (
    <span className={['b-petal-spinner', sizeCls, className].filter(Boolean).join(' ')}
      style={{ ...sizeStyle, ...style }} role="status" aria-label={label || 'Loading'}>
      <span className="b-petal-spinner__petal" /><span className="b-petal-spinner__petal" />
      <span className="b-petal-spinner__petal" /><span className="b-petal-spinner__petal" />
      <span className="b-petal-spinner__petal" />
    </span>
  );
  if (!label) return node;
  return <span className="b-spin-wrap">{node}<span className="b-spin-wrap__label">{label}</span></span>;
}

/* ── Inline ring spinner ─────────────────────────────────────── */
function DSSpinner({ size = 28, thickness, variant = 'primary', className = '', style }) {
  const w = thickness != null ? thickness : Math.max(2, Math.round(size / 9));
  const cls = ['b-ring-spinner', variant !== 'primary' && `b-ring-spinner--${variant}`, className].filter(Boolean).join(' ');
  return <span className={cls} style={{ width: size, height: size, '--ring-w': `${w}px`, ...style }} role="status" aria-label="Loading" />;
}

/* ── Skeleton shimmer ────────────────────────────────────────── */
function DSSkeleton({ variant = 'rect', width, height, lines = 1, lastWidth = '62%', radius, className = '', style }) {
  const dim = (v) => (typeof v === 'number' ? `${v}px` : v);
  if (variant === 'text' && lines > 1) {
    return (
      <span className="b-skeleton-lines" style={{ width: dim(width), ...style }}>
        {Array.from({ length: lines }).map((_, i) => (
          <span key={i} className="b-skeleton b-skeleton--text" style={{ width: i === lines - 1 ? lastWidth : '100%' }} />
        ))}
      </span>
    );
  }
  const cls = ['b-skeleton', variant !== 'rect' && `b-skeleton--${variant}`, className].filter(Boolean).join(' ');
  const st = { ...style };
  if (width != null) st.width = dim(width);
  if (height != null) st.height = dim(height);
  if (radius != null) st.borderRadius = dim(radius);
  if (variant === 'circle' && height == null && width != null) st.height = dim(width);
  return <span className={cls} style={st} />;
}

/* ── Progress button (loading / determinate / indeterminate) ──── */
function DSProgressButton({ progress, loading = false, indeterminate = false, variant = 'primary',
  block = false, children, disabled, className = '', style, ...rest }) {
  const pct = progress == null ? null : Math.max(0, Math.min(100, progress));
  // built on the design system's .b-btn classes (components.css)
  const V = { primary: 'b-btn-primary', secondary: 'b-btn-secondary', ghost: 'b-btn-ghost', danger: 'b-btn-danger', soft: 'b-btn-soft' };
  const cls = ['b-btn', 'b-btn-lg', V[variant] || 'b-btn-primary', block && 'b-btn--full', 'b-progress-btn',
    indeterminate && 'b-progress-btn--indeterminate',
    variant !== 'primary' && `b-progress-btn--${variant}`,
    (disabled || loading) && 'is-disabled', className].filter(Boolean).join(' ');
  return (
    <button type="button" className={cls} disabled={disabled || loading} aria-busy={loading || indeterminate || undefined} style={style} {...rest}>
      <span className="b-progress-btn__fill" style={indeterminate ? undefined : { width: `${pct || 0}%` }} aria-hidden="true" />
      <span className="b-progress-btn__label">
        {loading && <span className="b-ring-spinner" style={{ width: 18, height: 18, '--ring-w': '2px', background: variant === 'primary' ? 'conic-gradient(from 90deg, transparent, #fff)' : undefined }} aria-hidden="true" />}
        {children}
      </span>
    </button>
  );
}

/* ── Top loading bar (auto-trickle or controlled) ────────────── */
function DSTopLoadingBar({ value = null, loading, variant = 'primary', height = 3, indeterminate = false, className = '', style }) {
  const managed = value == null && typeof loading === 'boolean';
  const [auto, setAuto] = React.useState(0);
  const [visible, setVisible] = React.useState(false);
  React.useEffect(() => {
    if (!managed) return;
    let timer;
    if (loading) {
      setVisible(true);
      setAuto((a) => (a > 0 ? a : 8));
      timer = setInterval(() => setAuto((a) => (a >= 90 ? a : Math.min(90, a + (90 - a) * 0.06 + 0.4))), 280);
      return () => clearInterval(timer);
    }
    if (visible) {
      setAuto(100);
      const t = setTimeout(() => { setVisible(false); setAuto(0); }, 420);
      return () => clearTimeout(t);
    }
  }, [loading, managed]);
  const pct = managed ? auto : (value || 0);
  const done = managed ? !loading : pct >= 100;
  if (managed && !visible && !loading) return null;
  const cls = ['b-toploader', variant !== 'primary' && `b-toploader--${variant}`,
    indeterminate && 'b-toploader--indeterminate', done && !indeterminate && 'b-toploader--done', className].filter(Boolean).join(' ');
  return (
    <div className={cls} style={{ height, ...style }} role="progressbar">
      <div className="b-toploader__bar" style={indeterminate ? undefined : { width: `${pct}%` }} />
    </div>
  );
}

/* ── Loading overlay (brand / cream / scrim) ─────────────────── */
function DSLoadingOverlay({ open = true, variant = 'cream', message, submessage, progress,
  indeterminate = false, spinner = 'petal', backgroundImage, className = '', style }) {
  if (!open) return null;
  const cls = ['b-overlay', `b-overlay--${variant}`, className].filter(Boolean).join(' ');
  const st = { ...style };
  if (backgroundImage) st['--overlay-bg'] = `url(${backgroundImage})`;
  const showBar = progress != null || indeterminate;
  return (
    <div className={cls} style={st} role="status" aria-live="polite">
      <div className="b-overlay__inner">
        {spinner === 'ring' ? <DSSpinner size={40} thickness={4} /> : <DSPetalSpinner size="lg" />}
        {message && <div className="b-overlay__msg">{message}</div>}
        {submessage && <div className="b-overlay__sub">{submessage}</div>}
        {showBar && (
          <div className="b-overlay__progress">
            <DSProgress value={progress} indeterminate={indeterminate} />
          </div>
        )}
      </div>
    </div>
  );
}

/* ── Segmented / multi-part meter ────────────────────────────── */
function DSMeter({ title, total, segments = [], size = 'md', legend = true, className = '', style }) {
  const cls = ['b-meter', size !== 'md' && `b-meter--${size}`, className].filter(Boolean).join(' ');
  return (
    <div className={cls} style={style}>
      {(title || total != null) && (
        <div className="b-meter__head">
          {title && <span className="b-meter__title">{title}</span>}
          {total != null && <span className="b-meter__total">{total}</span>}
        </div>
      )}
      <div className="b-meter__track">
        {segments.map((s, i) => (
          <span key={i} className={`b-meter__seg b-meter__seg--${s.color || 'blue'}`} style={{ width: `${s.value}%` }} />
        ))}
      </div>
      {legend && (
        <div className="b-meter__legend">
          {segments.map((s, i) => (
            <span key={i} className="b-meter__item">
              <span className="b-meter__swatch" style={{ background: `var(--petal-${s.color}, var(--balsm-ink-300))` }} />
              {s.label} {s.shown != null && <span className="b-meter__val">{s.shown}</span>}
            </span>
          ))}
        </div>
      )}
    </div>
  );
}

Object.assign(window, {
  DSProgress, DSPetalSpinner, DSSpinner, DSSkeleton, DSProgressButton,
  DSTopLoadingBar, DSLoadingOverlay, DSMeter,
});
