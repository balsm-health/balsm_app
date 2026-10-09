// Run: node --test deploy/web/worker.test.mjs
//
// The Worker serves the update manifests and the release-notes page. The page
// shares an origin with the web app and prints text from a file, so the
// sanitizer and the headers are checked here rather than trusted.
import assert from 'node:assert/strict';
import test from 'node:test';

import worker, { compareVersions, releasesFor, sanitize } from './worker.js';

const ok = (name, cond, detail = '') => test(name, () => assert.ok(cond, String(detail)));

// sanitizer
const s = (h) => sanitize(h);
ok('script dropped with content', s('<p>a</p><script>alert(1)</script><p>b</p>') === '<p>a</p><p>b</p>', s('<p>a</p><script>alert(1)</script><p>b</p>'));
ok('nested script', !/alert/.test(s('<script><script>x</script>alert(2)</script>ok')), s('<script><script>x</script>alert(2)</script>ok'));
ok('event handlers gone', s('<p onclick="x()" style="a">hi</p>') === '<p>hi</p>');
ok('img onerror', s('<img src="https://x.y/a.png" onerror="x()" alt="A&B">') === '<img src="https://x.y/a.png" alt="A&amp;B" loading="lazy">', s('<img src="https://x.y/a.png" onerror="x()" alt="A&B">'));
ok('img non-https dropped', s('<img src="javascript:x">t') === 't');
ok('js link loses link keeps text', s('<a href="javascript:alert(1)">bad</a>') === 'bad', s('<a href="javascript:alert(1)">bad</a>'));
ok('entity-obfuscated scheme', s('<a href="&#106;avascript:alert(1)">x</a>') === 'x');
ok('https link', s('<a href="https://balsm.health/x?a=1&b=2" onclick=y>go</a>') === '<a href="https://balsm.health/x?a=1&amp;b=2" rel="noopener noreferrer" target="_blank">go</a>', s('<a href="https://balsm.health/x?a=1&b=2" onclick=y>go</a>'));
ok('attr breakout', !/<svg|onload/.test(s('<a href="https://x.y/\"><svg onload=alert(1)>">t</a>')), s('<a href="https://x.y/\"><svg onload=alert(1)>">t</a>'));
ok('unknown tag keeps text', s('<marquee>hi <b>there</b></marquee>') === 'hi <b>there</b>');
ok('unclosed tags closed', s('<ul><li>a<li>b') === '<ul><li>a<li>b</li></li></ul>', s('<ul><li>a<li>b'));
ok('stray close ignored', s('</div></p>x') === 'x');
ok('lone < escaped', s('1 < 2 & 3 &amp; 4') === '1 &lt; 2 &amp; 3 &amp; 4', s('1 < 2 & 3 &amp; 4'));
ok('comment removed', s('a<!-- <script>x</script> -->b') === 'ab');
ok('table kept', s('<table><tr><td>1</td></tr></table>') === '<table><tr><td>1</td></tr></table>');
ok('iframe dropped', s('<iframe src="https://evil"></iframe>z') === 'z');
ok('uppercase SCRIPT', s('<SCRIPT>alert(1)</SCRIPT>k') === 'k');

// version logic
ok('compare numeric', compareVersions('1.10.0', '1.9.3') > 0 && compareVersions('1.2', '1.2.0') === 0 && compareVersions('x', '1') === null);
const manifest = { versions: {
  '1.2.0': { platforms: ['ios', 'android'], notes: { en: '<p>one-two</p>' } },
  '1.3.0': { force: true, platforms: ['ios'], date: '2026-09-01', notes: { en: '<p>one-three <img src="https://cdn.balsm.health/a.png" alt="shot"></p><script>alert(1)</script>' } },
  '1.4.0': { platforms: ['ios', 'android'], date: '2026-10-09', notes: { en: [{ icon: 'bell-ring', title: 'Smarter <reminders>', body: 'Even <b>offline</b>. <a href="https://balsm.health">More</a>' }, { title: '' }], ar: [{ title: 'تذكيرات أذكى', body: 'حتى <b>دون إنترنت</b>.' }] } },
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
ok('no script in page', !/<script/i.test(t) && !t.includes('alert(1)'));
ok('image and link survive', t.includes('<img src="https://cdn.balsm.health/a.png" alt="shot" loading="lazy">') && t.includes('rel="noopener noreferrer"'));
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
