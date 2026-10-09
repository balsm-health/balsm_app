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
// A new brand needs no change here: add its file.
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
    const brand = BRAND.test(q.get('brand') || '') ? q.get('brand') : 'balsm';
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
        // a file. No script-src at all: whatever reaches the markup, nothing
        // on this page can execute. The sanitizer below is the second layer.
        'Content-Security-Policy':
          "default-src 'none'; style-src 'unsafe-inline'; img-src https: data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
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

/** Releases for `platform` newer than `from` (all of them without `from`), newest first. */
export function releasesFor(manifest, { from, platform }) {
  const versions = manifest && typeof manifest.versions === 'object' && manifest.versions ? manifest.versions : {};
  const out = [];
  for (const [version, release] of Object.entries(versions)) {
    if (!release || typeof release !== 'object' || !parseVersion(version)) continue;
    if (from && compareVersions(from, version) >= 0) continue;
    const platforms = release.platforms;
    if (platform && Array.isArray(platforms) && platforms.length && !platforms.includes(platform)) continue;
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
    body = releases.map(({ version, release }) => renderRelease(version, release, lang, t)).join('\n');
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

function renderRelease(version, release, lang, t) {
  const date = formatDate(release.date);
  const notes = noteFor(release.notes, lang);
  let content = '';
  if (Array.isArray(notes)) {
    const rows = notes
      .filter((it) => it && typeof it === 'object' && typeof it.title === 'string' && it.title.trim())
      .map(
        (it) =>
          `<li><strong class="row-title">${esc(it.title.trim())}</strong>${
            typeof it.body === 'string' && it.body.trim() ? `<div class="row-body">${sanitize(it.body)}</div>` : ''
          }</li>`,
      );
    if (rows.length) content = `<ul class="rows">${rows.join('')}</ul>`;
  } else if (typeof notes === 'string') {
    content = `<div class="html">${sanitize(notes)}</div>`;
  }
  return `<section>
<div class="release-head">
<h2 dir="ltr">v${esc(version)}</h2>
${release.force === true ? `<span class="badge">${esc(t.required)}</span>` : ''}
${date ? `<time dir="ltr">${esc(date)}</time>` : ''}
</div>
${content}
</section>`;
}

/** Notes in `lang`, else English, else whatever language is there. */
function noteFor(notes, lang) {
  if (!notes || typeof notes !== 'object' || Array.isArray(notes)) return null;
  for (const candidate of [notes[lang], notes.en, ...Object.values(notes)]) {
    if (typeof candidate === 'string' && candidate.trim()) return candidate;
    if (Array.isArray(candidate) && candidate.length) return candidate;
  }
  return null;
}

function formatDate(raw) {
  const m = typeof raw === 'string' && /^(\d{4})-(\d{2})-(\d{2})/.exec(raw);
  return m ? `${m[3]}/${m[2]}/${m[1]}` : '';
}

// ── HTML safety ─────────────────────────────────────────────────────────────

/** Escapes text, leaving entities that are already well formed. */
export function esc(text) {
  return String(text)
    .replace(/&(?!(?:[a-zA-Z][a-zA-Z0-9]{1,31}|#[0-9]{1,7}|#x[0-9a-fA-F]{1,6});)/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

const ALLOWED = new Set([
  'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'br', 'hr', 'blockquote',
  'b', 'strong', 'i', 'em', 'u', 'code', 'a', 'img',
  'table', 'thead', 'tbody', 'tr', 'th', 'td',
]);
const VOID = new Set(['br', 'hr', 'img']);
// Removed together with everything inside them.
const DROPPED = new Set([
  'script', 'style', 'head', 'title', 'iframe', 'object', 'embed', 'form', 'select',
  'textarea', 'template', 'noscript', 'svg', 'math', 'video', 'audio',
]);

/**
 * Rebuilds release-note HTML from an allow-list: only the tags above survive,
 * with no attributes except an https `href` on links and an https `src` (and
 * `alt`) on images. Everything else is dropped or escaped — the output never
 * contains markup this function did not write itself.
 */
export function sanitize(html) {
  const token = /<!--[\s\S]*?-->|<(\/?)([a-zA-Z][a-zA-Z0-9]*)\b([^>]*)>|[^<]+|</g;
  const open = [];
  let out = '';
  let dropping = null;
  let depth = 0;
  let m;
  while ((m = token.exec(String(html))) !== null) {
    const [raw, closing, rawName, attrs] = m;
    const name = rawName ? rawName.toLowerCase() : null;

    if (dropping) {
      if (name === dropping) {
        if (closing) depth--;
        else if (!/\/\s*$/.test(attrs)) depth++;
        if (depth === 0) dropping = null;
      }
      continue;
    }
    if (raw.startsWith('<!--')) continue;
    if (!name) {
      out += esc(raw);
      continue;
    }
    if (DROPPED.has(name)) {
      if (!closing && !/\/\s*$/.test(attrs)) {
        dropping = name;
        depth = 1;
      }
      continue;
    }
    if (!ALLOWED.has(name)) continue; // unknown tag: keep its text, lose the tag

    if (closing) {
      const at = open.lastIndexOf(name);
      if (at === -1) continue;
      while (open.length > at) out += `</${open.pop()}>`;
      continue;
    }
    if (name === 'a') {
      const href = attr(attrs, 'href');
      // Only https leaves the page; any other scheme loses the link, not the text.
      if (!/^https:\/\//i.test(href)) continue;
      out += `<a href="${esc(href)}" rel="noopener noreferrer" target="_blank">`;
      open.push(name);
    } else if (name === 'img') {
      const src = attr(attrs, 'src');
      if (!/^https:\/\//i.test(src)) continue;
      out += `<img src="${esc(src)}" alt="${esc(attr(attrs, 'alt'))}" loading="lazy">`;
    } else {
      out += `<${name}>`;
      if (!VOID.has(name)) open.push(name);
    }
  }
  while (open.length) out += `</${open.pop()}>`;
  return out;
}

function attr(attrs, name) {
  const m = new RegExp(`(?:^|\\s)${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s"'>]+))`, 'i').exec(attrs || '');
  return m ? (m[1] ?? m[2] ?? m[3] ?? '').trim() : '';
}

const CSS = `
:root{--ink:#14202B;--fg2:#3D4B5C;--fg3:#6B7A8C;--line:#E6EAEF;--wash:#F6F8FA;--accent:#724DD0;--accent-50:#F1ECFB;--amber:#8A6A10;--amber-50:#FBF3DC}
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
.html>:first-child,.row-body>:first-child{margin-top:0}
.html>:last-child,.row-body>:last-child{margin-bottom:0}
a{color:var(--accent)}
img{max-width:100%;height:auto;border-radius:12px}
code{padding:1px 5px;border-radius:6px;background:var(--wash);font:14px "IBM Plex Mono",ui-monospace,Menlo,monospace}
blockquote{margin:12px 0;padding:8px 14px;border-inline-start:3px solid var(--accent-50);color:var(--fg3)}
table{width:100%;border-collapse:collapse;font-size:14px}
th,td{padding:8px 10px;border:1px solid var(--line);text-align:start}
th{background:var(--wash);color:var(--ink)}
hr{border:0;border-top:1px solid var(--line);margin:16px 0}
.empty{margin-top:28px;padding:20px;border-radius:12px;background:var(--wash);color:var(--fg3);text-align:center}
`;
