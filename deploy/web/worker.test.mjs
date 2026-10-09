// Run: node --test deploy/web/worker.test.mjs
//
// The Worker serves the update manifests and the release-notes page. The page
// shares an origin with the web app and prints text from a file, so the
// escaping and the headers are checked here rather than trusted.
import assert from 'node:assert/strict';
import test from 'node:test';

import worker, { compareVersions, esc, noteFor, releasesFor } from './worker.js';

const ok = (name, cond, detail = '') => test(name, () => assert.ok(cond, String(detail)));

// escaping — notes are plain text, so everything is escaped, nothing is parsed
ok('escapes markup', esc('<script>alert(1)</script>') === '&lt;script&gt;alert(1)&lt;/script&gt;');
ok('escapes quotes and ampersands', esc(`a & "b" 'c' &amp;`) === 'a &amp; &quot;b&quot; &#39;c&#39; &amp;amp;');

// note shapes
ok('rows and bare strings', JSON.stringify(noteFor({ en: [{ title: ' A ', body: ' b ' }, ' C ', 7, { body: 'x' }, { title: '' }] }, 'en')) === '[{"title":"A","body":"b"},{"title":"C","body":""}]');
ok('language falls back to english', noteFor({ en: ['E'] }, 'ar')[0].title === 'E');
ok('an html string is not notes', noteFor({ en: '<p>x</p>' }, 'en').length === 0);
ok('no notes', noteFor(undefined, 'en').length === 0 && noteFor([], 'en').length === 0);

// version logic
ok('compare numeric', compareVersions('1.10.0', '1.9.3') > 0 && compareVersions('1.2', '1.2.0') === 0 && compareVersions('x', '1') === null);
const manifest = { versions: {
  '1.2.0': { platforms: ['ios', 'android'], notes: { en: ['one-two'] } },
  '1.3.0': { force: true, platforms: ['ios'], date: '2026-09-01', notes: { en: [{ title: 'one-three', body: '<img src=x onerror=alert(1)><script>alert(1)</script>' }] } },
  '1.4.0': { platforms: ['ios', 'android'], date: '2026-10-09', notes: { en: [{ title: 'Smarter <reminders>', body: 'Even <b>offline</b>.\nSecond line & more' }, { title: '' }], ar: [{ title: 'تذكيرات أذكى', body: 'حتى دون إنترنت.' }] } },
  'bad': { notes: { en: 'x' } },
} };
ok('releases newer than from', releasesFor(manifest, { from: '1.2.0', platform: 'ios' }).map(r => r.version).join() === '1.4.0,1.3.0');
ok('platform filter', releasesFor(manifest, { from: '1.2.0', platform: 'android' }).map(r => r.version).join() === '1.4.0');
ok('no from = all', releasesFor(manifest, {}).map(r => r.version).join() === '1.4.0,1.3.0,1.2.0');

// routes
const env = { VERSION_SOURCE_BASE: 'https://raw.example/version', ASSETS: { fetch: async (r) => new Response('asset:' + new URL(r.url).pathname, { status: new URL(r.url).pathname.startsWith('/version/') ? 404 : 200 }) } };
globalThis.fetch = async (u) => String(u).endsWith('/balsm.json') ? new Response(JSON.stringify(manifest)) : new Response('nf', { status: 404 });
const get = async (path) => { const r = await worker.fetch(new Request('https://app.balsm.health' + path), env); return { r, t: await r.text() }; };

let { r, t } = await get('/whats-new?brand=balsm&from=1.2.0&platform=ios&lang=en');
ok('page 200 html', r.status === 200 && r.headers.get('content-type').startsWith('text/html'));
ok('csp has no script-src and default none', /default-src 'none'/.test(r.headers.get('content-security-policy')) && !/script-src/.test(r.headers.get('content-security-policy')));
ok('page lists 1.4.0 then 1.3.0, not 1.2.0', t.indexOf('v1.4.0') > 0 && t.indexOf('v1.4.0') < t.indexOf('v1.3.0') && !t.includes('v1.2.0'));
ok('title escaped', t.includes('Smarter &lt;reminders&gt;') && !t.includes('<reminders>'));
ok('markup in notes is shown as text, never as markup', !/<script/i.test(t) && !/<img/i.test(t) && !/<b>/.test(t) && t.includes('Even &lt;b&gt;offline&lt;/b&gt;.') && t.includes('&lt;img src=x onerror=alert(1)&gt;'));
ok('line breaks and ampersands in a body', t.includes('&lt;/b&gt;.<br>Second line &amp; more'));
ok('required badge + date', t.includes('>Required<') && t.includes('09/10/2026'));
ok('since line', t.includes('Everything since version 1.2.0.'));

({ r, t } = await get('/whats-new?brand=balsm&lang=ar&from=1.3.0'));
ok('arabic rtl + brand name', t.includes('dir="rtl"') && t.includes('ما الجديد في بلسم') && t.includes('تذكيرات أذكى'));
({ r, t } = await get('/whats-new?brand=balsm&from=9.9.9'));
ok('up to date', r.status === 200 && t.includes('You are on the latest version.'));
({ r, t } = await get('/whats-new?brand=balsm_pro'));
ok('unknown brand 404 page', r.status === 404 && t.includes('Release notes are not available.') && t.includes('Balsm Pro'));
({ r, t } = await get('/whats-new?brand=%3Cscript%3E&from=%3Cb%3E&lang=xx&platform=%22%3E'));
ok('hostile params ignored', r.status === 200 && !t.includes('since version') && !t.includes('%3C') && !/<script/i.test(t) && t.includes('lang="en"'));
({ r, t } = await get('/version/balsm.json'));
ok('manifest route still json', r.status === 200 && JSON.parse(t).versions['1.4.0']);
({ r, t } = await get('/index.html'));
ok('other paths are assets', t === 'asset:/index.html');
