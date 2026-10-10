// app.balsm.health — the patient web app, plus app updates.
//
// Everything is a static asset except two routes:
//
//   /version/<brand>.json   The release manifest every installed app polls
//                           (packages/core/lib/src/update/), one per brand —
//                           balsm, balsm_pro, … — served from GitHub so a
//                           release is a commit to app/web/version/<brand>.json
//                           rather than a web build and deploy.
//
//   /whats-new              The same manifest as a page: the "Full release
//                           notes" link in the app's update sheet, and usable
//                           from the website. ?brand=&from=&platform=&lang=
//                           lists the releases newer than `from`.
//
// One deployment per brand, each on its own host (app.balsm.health,
// pro.balsm.health, …) from this same file — see wrangler.jsonc and
// wrangler.balsm_pro.jsonc. DEFAULT_BRAND says whose notes /whats-new shows
// when the link names none. A new brand needs no change here: add its
// manifest and its wrangler config.
//
// The apps only ever know this domain. GitHub is an implementation detail
// behind it: VERSION_SOURCE_BASE can be re-pointed, or emptied, without
// touching a single installed build.
//
// Never fail closed on the manifest. If GitHub is down, slow, or returns
// something that is not a JSON object, answer with the copy bundled at the
// last deploy. A manifest outage must not look like a forced update, and it
// must not take a known forced update away either — the app keeps its own
// last good copy.

// A brand id, and nothing that could walk the source path.
const BRAND = /^[a-z0-9_]{1,40}$/;
const MANIFEST = /^\/version\/([a-z0-9_]{1,40})\.json$/;
const NOTES_PATH = '/whats-new';
const MAX_AGE = 300;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const manifest = MANIFEST.exec(url.pathname);
    const notes = url.pathname === NOTES_PATH;
    if (!manifest && !notes) return env.ASSETS.fetch(request);
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method Not Allowed', { status: 405, headers: { Allow: 'GET, HEAD' } });
    }
    const head = request.method === 'HEAD';

    if (manifest) {
      const body = await loadManifest(manifest[1], request, env);
      // No such brand: a plain 404. The app treats that as "nothing to do".
      if (body === null) return new Response('Not Found', { status: 404 });
      return new Response(head ? null : body, {
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Cache-Control': `public, max-age=${MAX_AGE}`,
          'X-Content-Type-Options': 'nosniff',
        },
      });
    }

    const q = url.searchParams;
    // Each brand's host answers for its own brand unless asked for another.
    const fallback = BRAND.test(env.DEFAULT_BRAND || '') ? env.DEFAULT_BRAND : 'balsm';
    const brand = BRAND.test(q.get('brand') || '') ? q.get('brand') : fallback;
    const lang = q.get('lang') === 'ar' ? 'ar' : 'en';
    const body = await loadManifest(brand, request, env);
    const page = renderNotes({
      manifest: body === null ? null : JSON.parse(body),
      brand,
      lang,
      from: parseVersion(q.get('from') || '') ? q.get('from') : null,
      platform: ['ios', 'android', 'macos'].includes(q.get('platform')) ? q.get('platform') : null,
    });
    return new Response(head ? null : page, {
      status: body === null ? 404 : 200,
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': `public, max-age=${MAX_AGE}`,
        'X-Content-Type-Options': 'nosniff',
        'Referrer-Policy': 'no-referrer',
        // This page shares an origin with the web app, and its body comes from
        // a file. Notes are plain text and every value is escaped on the way
        // in; on top of that there is no script-src at all, so nothing on this
        // page can execute whatever reaches the markup.
        'Content-Security-Policy':
          "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
      },
    });
  },
};

// ── Manifest ────────────────────────────────────────────────────────────────

async function loadManifest(brand, request, env) {
  const file = `${brand}.json`;
  const base = (env.VERSION_SOURCE_BASE || '').replace(/\/+$/, '');
  return (await fromSource(base && `${base}/${file}`)) ?? (await fromBundle(request, `/version/${file}`, env));
}

/** The manifest on GitHub, or null if it is unreachable or not a JSON object. */
async function fromSource(source) {
  if (!source) return null;
  try {
    const res = await fetch(source, {
      cf: { cacheTtl: MAX_AGE, cacheEverything: true },
      signal: AbortSignal.timeout(4000),
    });
    if (!res.ok) return null;
    return validated(await res.text());
  } catch {
    return null;
  }
}

/** The copy shipped with this deploy (app/web/version/<brand>.json). */
async function fromBundle(request, path, env) {
  try {
    const res = await env.ASSETS.fetch(new Request(new URL(path, request.url)));
    if (!res.ok) return null;
    return validated(await res.text());
  } catch {
    return null;
  }
}

/** The text back if it parses as a JSON object, else null. */
function validated(text) {
  try {
    const parsed = JSON.parse(text);
    return parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed) ? text : null;
  } catch {
    return null;
  }
}

// ── Versions (same rules as app_update.dart) ────────────────────────────────

/** `1.4.0+7` → [1, 4, 0]; null when it is not a version. */
export function parseVersion(v) {
  const core = String(v).trim().split(/[+-]/)[0];
  if (!core) return null;
  const parts = [];
  for (const p of core.split('.')) {
    if (!/^\d{1,9}$/.test(p)) return null;
    parts.push(Number(p));
  }
  while (parts.length < 3) parts.push(0);
  return parts;
}

/** Negative when a is older than b; null when either is unreadable. */
export function compareVersions(a, b) {
  const x = parseVersion(a);
  const y = parseVersion(b);
  if (!x || !y) return null;
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    const d = (x[i] || 0) - (y[i] || 0);
    if (d !== 0) return d;
  }
  return 0;
}

/** Releases for `platform` newer than `from` (all of them without `from`), newest first; withdrawn ones left out. */
export function releasesFor(manifest, { from, platform }) {
  const versions = manifest && typeof manifest.versions === 'object' && manifest.versions ? manifest.versions : {};
  const out = [];
  for (const [version, release] of Object.entries(versions)) {
    if (!release || typeof release !== 'object' || !parseVersion(version)) continue;
    if (from && compareVersions(from, version) >= 0) continue;
    const platforms = release.platforms;
    if (platform && Array.isArray(platforms) && platforms.length && !platforms.includes(platform)) continue;
    // Pulled from the store: not listed. With no platform asked for, a release
    // withdrawn on only some of its platforms is still shown.
    const withdrawn = release.withdrawn;
    if (withdrawn === true || (platform && Array.isArray(withdrawn) && withdrawn.includes(platform))) continue;
    out.push({ version, release });
  }
  return out.sort((a, b) => compareVersions(b.version, a.version));
}

// ── Page ────────────────────────────────────────────────────────────────────

const BRAND_NAMES = {
  balsm: { en: 'Balsm', ar: 'بلسم' },
  balsm_pro: { en: 'Balsm Pro', ar: 'بلسم برو' },
};

const COPY = {
  en: {
    title: (app) => `What’s new in ${app}`,
    since: (v) => `Everything since version ${v}.`,
    upToDate: 'You are on the latest version.',
    none: 'No release notes yet.',
    unknown: 'Release notes are not available.',
    required: 'Required',
  },
  ar: {
    title: (app) => `ما الجديد في ${app}`,
    since: (v) => `كل ما تغيّر منذ الإصدار ${v}.`,
    upToDate: 'أنت على أحدث إصدار.',
    none: 'لا توجد ملاحظات إصدار بعد.',
    unknown: 'ملاحظات الإصدار غير متاحة.',
    required: 'مطلوب',
  },
};

export function renderNotes({ manifest, brand, lang, from, platform }) {
  const t = COPY[lang];
  const app = (BRAND_NAMES[brand] || {})[lang] || brand;
  const releases = manifest ? releasesFor(manifest, { from, platform }) : [];

  let body;
  if (!manifest) {
    body = `<p class="empty">${esc(t.unknown)}</p>`;
  } else if (!releases.length) {
    body = `<p class="empty">${esc(from ? t.upToDate : t.none)}</p>`;
  } else {
    body = releases.map(({ version, release }) => renderRelease(version, release, lang, t, platform)).join('\n');
  }

  return `<!doctype html>
<html lang="${lang}" dir="${lang === 'ar' ? 'rtl' : 'ltr'}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${esc(t.title(app))}</title>
<style>${CSS}</style>
</head>
<body>
<main>
<header>
<h1>${esc(t.title(app))}</h1>
${from && releases.length ? `<p class="sub">${esc(t.since(from))}</p>` : ''}
</header>
${body}
</main>
</body>
</html>`;
}

function renderRelease(version, release, lang, t, platform) {
  const date = formatDate(release.date);
  const rows = noteFor(release.notes, lang).map(
    (it) =>
      `<li><strong class="row-title">${esc(it.title)}</strong>${
        it.body ? `<div class="row-body">${esc(it.body).replace(/\r?\n/g, '<br>')}</div>` : ''
      }</li>`,
  );
  return `<section>
<div class="release-head">
<h2 dir="ltr">v${esc(version)}</h2>
${requiredBadge(release, platform, t)}
${date ? `<time dir="ltr">${esc(date)}</time>` : ''}
</div>
${rows.length ? `<ul class="rows">${rows.join('')}</ul>` : ''}
</section>`;
}

const PLATFORM_NAMES = { ios: 'iOS', android: 'Android', macos: 'macOS' };

/**
 * `force` is `true` (every platform the release is on) or a list of platforms
 * (`["ios"]`). For one platform's page the badge is a plain "Required" when it
 * applies there; for the page with no platform it names the ones it covers.
 */
export function requiredBadge(release, platform, t) {
  const force = release.force;
  const on = Array.isArray(release.platforms) && release.platforms.length ? release.platforms : null;
  const listed = Array.isArray(force) ? force.filter((p) => PLATFORM_NAMES[p] && (!on || on.includes(p))) : null;
  let label = '';
  if (force === true || (listed && platform && listed.includes(platform))) {
    label = t.required;
  } else if (listed && !platform && listed.length) {
    label = `${t.required} · ${listed.map((p) => PLATFORM_NAMES[p]).join(', ')}`;
  }
  return label ? `<span class="badge">${esc(label)}</span>` : '';
}

/**
 * A release's notes in `lang`, else English, else whatever language is there,
 * as [{title, body}]. Same shape rules as app_update.dart: a language's value
 * is a list whose entries are {title, body} or a bare string.
 */
export function noteFor(notes, lang) {
  if (!notes || typeof notes !== 'object' || Array.isArray(notes)) return [];
  for (const candidate of [notes[lang], notes.en, ...Object.values(notes)]) {
    if (!Array.isArray(candidate)) continue;
    const items = [];
    for (const it of candidate) {
      if (typeof it === 'string' && it.trim()) {
        items.push({ title: it.trim(), body: '' });
      } else if (it && typeof it === 'object' && typeof it.title === 'string' && it.title.trim()) {
        items.push({ title: it.title.trim(), body: typeof it.body === 'string' ? it.body.trim() : '' });
      }
    }
    if (items.length) return items;
  }
  return [];
}

/**
 * A release's `date` as the page prints it. A day (`2026-10-09`) prints as
 * `09/10/2026`. A date and time prints with the time in UTC — a server cannot
 * know the reader's zone, so it says which one it used. A time written without
 * a zone is taken as UTC, as the app does.
 */
export function formatDate(raw) {
  if (typeof raw !== 'string') return '';
  const text = raw.trim();
  const day = /^(\d{4})-(\d{2})-(\d{2})/.exec(text);
  if (!day) return '';
  if (!/\d[T ]\d{1,2}:\d{2}/.test(text)) return `${day[3]}/${day[2]}/${day[1]}`;
  const zoned = /(Z|[+-]\d{2}:?\d{2})$/i.test(text) ? text : `${text}Z`;
  const at = new Date(zoned.replace(' ', 'T'));
  if (Number.isNaN(at.getTime())) return `${day[3]}/${day[2]}/${day[1]}`;
  const two = (n) => String(n).padStart(2, '0');
  return `${two(at.getUTCDate())}/${two(at.getUTCMonth() + 1)}/${at.getUTCFullYear()} ${two(at.getUTCHours())}:${two(at.getUTCMinutes())} UTC`;
}

// ── Escaping ────────────────────────────────────────────────────────────────

/** Makes any text safe to place in markup or in a quoted attribute. */
export function esc(text) {
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

const CSS = `
:root{--ink:#14202B;--fg2:#3D4B5C;--fg3:#6B7A8C;--line:#E6EAEF;--wash:#F6F8FA;--amber:#8A6A10;--amber-50:#FBF3DC}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{margin:0;background:#fff;color:var(--fg2);font:16px/1.55 "IBM Plex Sans","IBM Plex Sans Arabic",system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:640px;margin:0 auto;padding:28px 20px 56px}
h1{margin:0;color:var(--ink);font-size:26px;line-height:1.2;letter-spacing:-.01em}
.sub{margin:6px 0 0;color:var(--fg3);font-size:14px}
section{margin-top:28px;padding-top:20px;border-top:1px solid var(--line)}
.release-head{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;margin-bottom:10px}
h2{margin:0;color:var(--ink);font:600 18px/1.3 "IBM Plex Mono",ui-monospace,Menlo,monospace}
time{margin-inline-start:auto;color:var(--fg3);font-size:13px}
.badge{padding:2px 8px;border-radius:999px;background:var(--amber-50);color:var(--amber);font-size:12px;font-weight:700}
.rows{list-style:none;margin:0;padding:0}
.rows>li{padding:12px 0;border-top:1px solid var(--line)}
.rows>li:first-child{border-top:0;padding-top:4px}
.row-title{display:block;color:var(--ink);font-weight:600}
.row-body{margin-top:2px;font-size:14px}
.empty{margin-top:28px;padding:20px;border-radius:12px;background:var(--wash);color:var(--fg3);text-align:center}
`;
