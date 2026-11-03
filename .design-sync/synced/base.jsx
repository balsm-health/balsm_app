/* base.jsx — shared primitives for the Balsm patient app
   Loaded first. Exposes Icon, AppCtx/useApp, cx to window. */
const { useState, useEffect, useRef, useCallback, useMemo } = React;

/* App-wide context: language, direction, translator, navigation, patient state */
const AppCtx = React.createContext(null);
const useApp = () => React.useContext(AppCtx);

function cx(...parts) { return parts.filter(Boolean).join(' '); }

/* Lucide icon. Re-creates whenever name/size/stroke change. */
const BRAND_ICONS = {
  'brand-icloud': '<svg viewBox="0 0 64 42" width="100%" height="100%"><path d="M17 42C7.6 42 0 35.3 0 27c0-7 5.4-12.9 12.7-14.6C15.4 5.1 22.6 0 31 0c9.2 0 17 6.1 19 14.4C58 15 64 21 64 28.5 64 36 57.8 42 50 42H17z" fill="#2B8CF7"/></svg>',
  'brand-gdrive': '<svg viewBox="0 0 87.3 78" width="100%" height="100%"><path d="m6.6 66.85 3.85 6.65c.8 1.4 1.95 2.5 3.3 3.3l13.75-23.8h-27.5c0 1.55.4 3.1 1.2 4.5z" fill="#0066da"/><path d="m43.65 25-13.75-23.8c-1.35.8-2.5 1.9-3.3 3.3l-25.4 44a9.06 9.06 0 0 0 -1.2 4.5h27.5z" fill="#00ac47"/><path d="m73.55 76.8c1.35-.8 2.5-1.9 3.3-3.3l1.6-2.75 7.65-13.25c.8-1.4 1.2-2.95 1.2-4.5h-27.502l5.852 11.5z" fill="#ea4335"/><path d="m43.65 25 13.75-23.8c-1.35-.8-2.9-1.2-4.5-1.2h-18.5c-1.6 0-3.15.45-4.5 1.2z" fill="#00832d"/><path d="m59.8 53h-32.3l-13.75 23.8c1.35.8 2.9 1.2 4.5 1.2h50.8c1.6 0 3.15-.45 4.5-1.2z" fill="#2684fc"/><path d="m73.4 26.5-12.7-22c-.8-1.4-1.95-2.5-3.3-3.3l-13.75 23.8 16.15 28h27.45c0-1.55-.4-3.1-1.2-4.5z" fill="#ffba00"/></svg>',
};
function Icon({ name, size = 20, stroke = 1.9, className = '', style, muted }) {
  const ref = useRef(null);
  const brand = name && name.startsWith('brand-');
  useEffect(() => {
    if (brand) return;
    if (ref.current && window.lucide) {
      ref.current.innerHTML = '';
      const el = document.createElement('i');
      el.setAttribute('data-lucide', name);
      ref.current.appendChild(el);
      window.lucide.createIcons({
        attrs: { 'stroke-width': stroke, width: size, height: size },
        nameAttr: 'data-lucide',
      });
    }
  }, [name, size, stroke]);
  if (brand) {
    const box = { display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: size, height: size, flexShrink: 0, filter: muted ? 'grayscale(1) opacity(.55)' : 'none', ...style };
    if (name === 'brand-balsm') return <span className={className} style={box}><img src={(window.__resources && window.__resources.icon) || 'assets/icon.svg?v=7'} alt="" style={{ width: '100%', height: '100%', objectFit: 'contain' }} /></span>;
    return <span className={className} style={box} dangerouslySetInnerHTML={{ __html: BRAND_ICONS[name] || '' }} />;
  }
  return <span ref={ref} className={className} style={{ display: 'inline-flex', width: size, height: size, ...style }} />;
}

Object.assign(window, { AppCtx, useApp, cx, Icon });
