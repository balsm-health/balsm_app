/* numpad.jsx — Balsm in-app numeric keypad for vitals entry.
   Digits stay LTR in RTL. Hardware digits/Backspace also work while
   the pad has focus. Flows show it when the 'numpad' tweak = 'custom'. */

function NumPad({ onPress, decimal = false, style }) {
  const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', decimal ? '.' : null, '0', 'del'];
  const keyDown = (e) => {
    if (/^\d$/.test(e.key)) onPress(e.key);
    else if (e.key === 'Backspace') onPress('del');
    else if (decimal && e.key === '.') onPress('.');
  };
  return (
    <div className="numpad" role="group" aria-label="Number pad" style={style} onKeyDown={keyDown}>
      {keys.map((k, i) => k === null
        ? <div key={'sp' + i} aria-hidden="true"></div>
        : (
          <button key={k} type="button" className={cx('numpad-key', k === 'del' && 'is-del')}
            aria-label={k === 'del' ? 'Delete' : k} onClick={() => onPress(k)}>
            {k === 'del' ? <Icon name="delete" size={22} stroke={1.8} /> : k}
          </button>
        ))}
    </div>
  );
}

window.NumPad = NumPad;
