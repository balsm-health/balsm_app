/* dialcodes.jsx — full international dialing-code dataset + searchable picker sheet.
   Loaded before auth.jsx. Exposes DIAL_CODES and DialCodePicker on window. */

const DIAL_CODES = [
  { code: 'EG', dial: '+20',   flag: '🇪🇬', name: { en: 'Egypt',                ar: 'مصر' } },
  { code: 'SA', dial: '+966',  flag: '🇸🇦', name: { en: 'Saudi Arabia',         ar: 'السعودية' } },
  { code: 'AE', dial: '+971',  flag: '🇦🇪', name: { en: 'United Arab Emirates', ar: 'الإمارات' } },
  { code: 'JO', dial: '+962',  flag: '🇯🇴', name: { en: 'Jordan',               ar: 'الأردن' } },
  { code: 'KW', dial: '+965',  flag: '🇰🇼', name: { en: 'Kuwait',               ar: 'الكويت' } },
  { code: 'QA', dial: '+974',  flag: '🇶🇦', name: { en: 'Qatar',                ar: 'قطر' } },
  { code: 'BH', dial: '+973',  flag: '🇧🇭', name: { en: 'Bahrain',              ar: 'البحرين' } },
  { code: 'OM', dial: '+968',  flag: '🇴🇲', name: { en: 'Oman',                 ar: 'عُمان' } },
  { code: 'LB', dial: '+961',  flag: '🇱🇧', name: { en: 'Lebanon',              ar: 'لبنان' } },
  { code: 'IQ', dial: '+964',  flag: '🇮🇶', name: { en: 'Iraq',                 ar: 'العراق' } },
  { code: 'SY', dial: '+963',  flag: '🇸🇾', name: { en: 'Syria',                ar: 'سوريا' } },
  { code: 'YE', dial: '+967',  flag: '🇾🇪', name: { en: 'Yemen',                ar: 'اليمن' } },
  { code: 'PS', dial: '+970',  flag: '🇵🇸', name: { en: 'Palestine',            ar: 'فلسطين' } },
  { code: 'MA', dial: '+212',  flag: '🇲🇦', name: { en: 'Morocco',              ar: 'المغرب' } },
  { code: 'DZ', dial: '+213',  flag: '🇩🇿', name: { en: 'Algeria',              ar: 'الجزائر' } },
  { code: 'TN', dial: '+216',  flag: '🇹🇳', name: { en: 'Tunisia',              ar: 'تونس' } },
  { code: 'LY', dial: '+218',  flag: '🇱🇾', name: { en: 'Libya',                ar: 'ليبيا' } },
  { code: 'SD', dial: '+249',  flag: '🇸🇩', name: { en: 'Sudan',                ar: 'السودان' } },
  { code: 'MR', dial: '+222',  flag: '🇲🇷', name: { en: 'Mauritania',           ar: 'موريتانيا' } },
  { code: 'SO', dial: '+252',  flag: '🇸🇴', name: { en: 'Somalia',              ar: 'الصومال' } },
  { code: 'DJ', dial: '+253',  flag: '🇩🇯', name: { en: 'Djibouti',             ar: 'جيبوتي' } },
  { code: 'KM', dial: '+269',  flag: '🇰🇲', name: { en: 'Comoros',              ar: 'جزر القمر' } },
  { code: 'TR', dial: '+90',   flag: '🇹🇷', name: { en: 'Turkey',               ar: 'تركيا' } },
  { code: 'IR', dial: '+98',   flag: '🇮🇷', name: { en: 'Iran',                 ar: 'إيران' } },
  { code: 'IL', dial: '+972',  flag: '🇮🇱', name: { en: 'Israel',               ar: 'إسرائيل' } },

  { code: 'US', dial: '+1',    flag: '🇺🇸', name: { en: 'United States',        ar: 'الولايات المتحدة' } },
  { code: 'CA', dial: '+1',    flag: '🇨🇦', name: { en: 'Canada',               ar: 'كندا' } },
  { code: 'GB', dial: '+44',   flag: '🇬🇧', name: { en: 'United Kingdom',       ar: 'المملكة المتحدة' } },
  { code: 'IE', dial: '+353',  flag: '🇮🇪', name: { en: 'Ireland',              ar: 'أيرلندا' } },
  { code: 'FR', dial: '+33',   flag: '🇫🇷', name: { en: 'France',               ar: 'فرنسا' } },
  { code: 'DE', dial: '+49',   flag: '🇩🇪', name: { en: 'Germany',              ar: 'ألمانيا' } },
  { code: 'IT', dial: '+39',   flag: '🇮🇹', name: { en: 'Italy',                ar: 'إيطاليا' } },
  { code: 'ES', dial: '+34',   flag: '🇪🇸', name: { en: 'Spain',                ar: 'إسبانيا' } },
  { code: 'PT', dial: '+351',  flag: '🇵🇹', name: { en: 'Portugal',             ar: 'البرتغال' } },
  { code: 'NL', dial: '+31',   flag: '🇳🇱', name: { en: 'Netherlands',          ar: 'هولندا' } },
  { code: 'BE', dial: '+32',   flag: '🇧🇪', name: { en: 'Belgium',              ar: 'بلجيكا' } },
  { code: 'CH', dial: '+41',   flag: '🇨🇭', name: { en: 'Switzerland',          ar: 'سويسرا' } },
  { code: 'AT', dial: '+43',   flag: '🇦🇹', name: { en: 'Austria',              ar: 'النمسا' } },
  { code: 'SE', dial: '+46',   flag: '🇸🇪', name: { en: 'Sweden',               ar: 'السويد' } },
  { code: 'NO', dial: '+47',   flag: '🇳🇴', name: { en: 'Norway',               ar: 'النرويج' } },
  { code: 'DK', dial: '+45',   flag: '🇩🇰', name: { en: 'Denmark',              ar: 'الدنمارك' } },
  { code: 'FI', dial: '+358',  flag: '🇫🇮', name: { en: 'Finland',              ar: 'فنلندا' } },
  { code: 'PL', dial: '+48',   flag: '🇵🇱', name: { en: 'Poland',               ar: 'بولندا' } },
  { code: 'CZ', dial: '+420',  flag: '🇨🇿', name: { en: 'Czechia',              ar: 'التشيك' } },
  { code: 'GR', dial: '+30',   flag: '🇬🇷', name: { en: 'Greece',               ar: 'اليونان' } },
  { code: 'RO', dial: '+40',   flag: '🇷🇴', name: { en: 'Romania',              ar: 'رومانيا' } },
  { code: 'HU', dial: '+36',   flag: '🇭🇺', name: { en: 'Hungary',              ar: 'المجر' } },
  { code: 'UA', dial: '+380',  flag: '🇺🇦', name: { en: 'Ukraine',              ar: 'أوكرانيا' } },
  { code: 'RU', dial: '+7',    flag: '🇷🇺', name: { en: 'Russia',               ar: 'روسيا' } },

  { code: 'IN', dial: '+91',   flag: '🇮🇳', name: { en: 'India',                ar: 'الهند' } },
  { code: 'PK', dial: '+92',   flag: '🇵🇰', name: { en: 'Pakistan',             ar: 'باكستان' } },
  { code: 'BD', dial: '+880',  flag: '🇧🇩', name: { en: 'Bangladesh',           ar: 'بنغلاديش' } },
  { code: 'LK', dial: '+94',   flag: '🇱🇰', name: { en: 'Sri Lanka',            ar: 'سريلانكا' } },
  { code: 'NP', dial: '+977',  flag: '🇳🇵', name: { en: 'Nepal',                ar: 'نيبال' } },
  { code: 'AF', dial: '+93',   flag: '🇦🇫', name: { en: 'Afghanistan',          ar: 'أفغانستان' } },
  { code: 'CN', dial: '+86',   flag: '🇨🇳', name: { en: 'China',                ar: 'الصين' } },
  { code: 'JP', dial: '+81',   flag: '🇯🇵', name: { en: 'Japan',                ar: 'اليابان' } },
  { code: 'KR', dial: '+82',   flag: '🇰🇷', name: { en: 'South Korea',          ar: 'كوريا الجنوبية' } },
  { code: 'ID', dial: '+62',   flag: '🇮🇩', name: { en: 'Indonesia',            ar: 'إندونيسيا' } },
  { code: 'MY', dial: '+60',   flag: '🇲🇾', name: { en: 'Malaysia',             ar: 'ماليزيا' } },
  { code: 'SG', dial: '+65',   flag: '🇸🇬', name: { en: 'Singapore',            ar: 'سنغافورة' } },
  { code: 'TH', dial: '+66',   flag: '🇹🇭', name: { en: 'Thailand',             ar: 'تايلاند' } },
  { code: 'VN', dial: '+84',   flag: '🇻🇳', name: { en: 'Vietnam',              ar: 'فيتنام' } },
  { code: 'PH', dial: '+63',   flag: '🇵🇭', name: { en: 'Philippines',          ar: 'الفلبين' } },
  { code: 'HK', dial: '+852',  flag: '🇭🇰', name: { en: 'Hong Kong',            ar: 'هونغ كونغ' } },
  { code: 'AU', dial: '+61',   flag: '🇦🇺', name: { en: 'Australia',            ar: 'أستراليا' } },
  { code: 'NZ', dial: '+64',   flag: '🇳🇿', name: { en: 'New Zealand',          ar: 'نيوزيلندا' } },

  { code: 'NG', dial: '+234',  flag: '🇳🇬', name: { en: 'Nigeria',              ar: 'نيجيريا' } },
  { code: 'KE', dial: '+254',  flag: '🇰🇪', name: { en: 'Kenya',                ar: 'كينيا' } },
  { code: 'ET', dial: '+251',  flag: '🇪🇹', name: { en: 'Ethiopia',             ar: 'إثيوبيا' } },
  { code: 'GH', dial: '+233',  flag: '🇬🇭', name: { en: 'Ghana',                ar: 'غانا' } },
  { code: 'ZA', dial: '+27',   flag: '🇿🇦', name: { en: 'South Africa',         ar: 'جنوب أفريقيا' } },
  { code: 'TZ', dial: '+255',  flag: '🇹🇿', name: { en: 'Tanzania',             ar: 'تنزانيا' } },
  { code: 'UG', dial: '+256',  flag: '🇺🇬', name: { en: 'Uganda',               ar: 'أوغندا' } },
  { code: 'SN', dial: '+221',  flag: '🇸🇳', name: { en: 'Senegal',              ar: 'السنغال' } },

  { code: 'BR', dial: '+55',   flag: '🇧🇷', name: { en: 'Brazil',               ar: 'البرازيل' } },
  { code: 'MX', dial: '+52',   flag: '🇲🇽', name: { en: 'Mexico',               ar: 'المكسيك' } },
  { code: 'AR', dial: '+54',   flag: '🇦🇷', name: { en: 'Argentina',            ar: 'الأرجنتين' } },
  { code: 'CO', dial: '+57',   flag: '🇨🇴', name: { en: 'Colombia',             ar: 'كولومبيا' } },
  { code: 'CL', dial: '+56',   flag: '🇨🇱', name: { en: 'Chile',                ar: 'تشيلي' } },
  { code: 'PE', dial: '+51',   flag: '🇵🇪', name: { en: 'Peru',                 ar: 'بيرو' } },
];

/* normalize Arabic + diacritics for searching */
function dcNorm(s) {
  return (s || '').toString().toLowerCase()
    .replace(/[\u064B-\u065F\u0670]/g, '')
    .replace(/[أإآ]/g, 'ا').replace(/ى/g, 'ي').replace(/ة/g, 'ه');
}

function DialCodePicker({ onClose, onPick, current, lang }) {
  const [q, setQ] = useState('');
  const inputRef = useRef(null);
  useEffect(() => { const id = setTimeout(() => inputRef.current?.focus(), 350); return () => clearTimeout(id); }, []);

  const nq = dcNorm(q.trim());
  const list = !nq ? DIAL_CODES : DIAL_CODES.filter(c =>
    dcNorm(c.name.en).includes(nq) ||
    dcNorm(c.name.ar).includes(nq) ||
    c.dial.replace('+', '').includes(nq.replace('+', '')) ||
    c.code.toLowerCase().includes(nq)
  );

  return (
    <>
      <style>{`@keyframes dcpUp{from{transform:translateY(110%)}to{transform:none}}`}</style>
      <div className="app-scrim" onClick={onClose} style={{ position: 'absolute', inset: 0, zIndex: 60, background: 'rgba(20,32,43,0.36)' }} />
      <div className="app-sheet" style={{
        position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 61,
        background: '#fff', borderRadius: '20px 20px 0 0',
        height: '82%', display: 'flex', flexDirection: 'column',
        animation: 'dcpUp 0.3s cubic-bezier(0.16,1,0.3,1) both',
      }}>
        <div style={{ padding: '10px 20px 0', flexShrink: 0 }}>
          <div className="sheet-grab" style={{ margin: '0 auto 12px' }} />
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: 12 }}>
            <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--pt-lg)', color: 'var(--fg1)' }}>
              {lang === 'ar' ? 'اختر الدولة' : 'Select country'}
            </div>
            <button className="round-btn ghost" onClick={onClose}><Icon name="x" size={17} /></button>
          </div>
          <div style={{ position: 'relative', marginBottom: 10 }}>
            <Icon name="search" size={17} style={{ position: 'absolute', insetInlineStart: 14, top: '50%', transform: 'translateY(-50%)', color: 'var(--fg3)' }} />
            <input ref={inputRef} className="b-input" value={q} onChange={e => setQ(e.target.value)}
              placeholder={lang === 'ar' ? 'ابحث بالاسم أو الرمز' : 'Search name or code'}
              style={{ paddingInlineStart: 42 }} />
          </div>
        </div>
        <div style={{ flex: 1, overflowY: 'auto', padding: '0 20px 34px' }}>
          {list.length === 0 ? (
            <div style={{ textAlign: 'center', color: 'var(--fg3)', padding: '40px 0', fontSize: 'var(--pt-sm)' }}>
              {lang === 'ar' ? 'لا توجد نتائج' : 'No matches'}
            </div>
          ) : list.map((c, i) => {
            const active = current === c.code;
            return (
              <div key={c.code} onClick={() => { onPick(c); onClose(); }} style={{
                display: 'flex', alignItems: 'center', gap: 14, padding: '13px 4px',
                borderBottom: i < list.length - 1 ? '1px solid var(--balsm-ink-50)' : 'none',
                cursor: 'pointer',
              }}>
                <span style={{ fontSize: 24, lineHeight: 1, flexShrink: 0 }}>{c.flag}</span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontWeight: 600, fontSize: 'var(--pt-md)', color: 'var(--fg1)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {c.name[lang] || c.name.en}
                  </div>
                </div>
                <span className="num" style={{ fontSize: 'var(--pt-sm)', fontWeight: 600, color: active ? 'var(--app-accent)' : 'var(--fg3)', flexShrink: 0, direction: 'ltr' }}>{c.dial}</span>
                {active && <Icon name="check" size={18} style={{ color: 'var(--app-accent)', flexShrink: 0 }} />}
              </div>
            );
          })}
        </div>
      </div>
    </>
  );
}

Object.assign(window, { DIAL_CODES, DialCodePicker });
