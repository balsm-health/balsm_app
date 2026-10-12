/* base.jsx — shared primitives for the Balsm patient app
   Loaded first. Exposes Icon, AppCtx/useApp, cx to window. */
const { useState, useEffect, useRef, useCallback, useMemo } = React;

/* App-wide context: language, direction, translator, navigation, patient state */
const AppCtx = React.createContext(null);
const useApp = () => React.useContext(AppCtx);

function cx(...parts) { return parts.filter(Boolean).join(' '); }

/* Lucide icon. Re-creates whenever name/size/stroke change. */
function Icon({ name, size = 20, stroke = 1.9, className = '', style }) {
  const ref = useRef(null);
  useEffect(() => {
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
  return <span ref={ref} className={className} style={{ display: 'inline-flex', width: size, height: size, ...style }} />;
}

Object.assign(window, { AppCtx, useApp, cx, Icon });
