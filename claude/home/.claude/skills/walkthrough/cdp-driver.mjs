#!/usr/bin/env node
// Long-lived Chrome DevTools driver. Node >= 22, no dependencies.
// node cdp-driver.mjs --chrome-port 9333 --port 9400 --profile <dir> [--headless] [url]
// Attaches to Chrome on 127.0.0.1:<chrome-port> if one is listening, else launches it.
// Serves a JSON HTTP API on 127.0.0.1:<port>. One browser socket, one CDP session per tab,
// so virtual authenticators and other session state survive between curl calls.
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { writeFileSync, readFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

const argv = process.argv.slice(2);
const opt = (n) => { const i = argv.indexOf(`--${n}`); return i < 0 ? undefined : argv[i + 1]; };
const chromePort = Number(opt('chrome-port'));
const port = Number(opt('port'));
const profile = opt('profile');
const headless = argv.includes('--headless');
const startUrl = argv.filter((a, i) => !a.startsWith('--') && !['--chrome-port', '--port', '--profile'].includes(argv[i - 1])).pop();
if (!chromePort || !port || !profile) {
  console.error('usage: cdp-driver.mjs --chrome-port N --port N --profile DIR [--headless] [url]');
  process.exit(2);
}
const HOST = '127.0.0.1';
const CHROME = process.env.CHROME_BIN || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function versionInfo() {
  try { return await (await fetch(`http://${HOST}:${chromePort}/json/version`)).json(); } catch { return null; }
}

let chromeProc = null;
let info = await versionInfo();
if (!info) {
  mkdirSync(profile, { recursive: true, mode: 0o700 });
  const args = [`--remote-debugging-port=${chromePort}`, `--remote-debugging-address=${HOST}`,
    `--user-data-dir=${profile}`, '--no-first-run', '--no-default-browser-check',
    ...(headless ? ['--headless=new'] : []), startUrl || 'about:blank'];
  chromeProc = spawn(CHROME, args, { stdio: 'ignore' });
  for (let i = 0; i < 100 && !(info = await versionInfo()); i++) await sleep(150);
  if (!info) { console.error('Chrome did not open its debugging port'); process.exit(1); }
}

const ws = new WebSocket(info.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('browser websocket failed')); });
let nextId = 1;
const pending = new Map();
const sessions = new Map();   // targetId -> sessionId
const logs = new Map();       // targetId -> [{kind, ...}]
const bySession = new Map();  // sessionId -> targetId
const contexts = new Map();   // name -> browserContextId

ws.onmessage = (m) => {
  const msg = JSON.parse(m.data);
  if (msg.id && pending.has(msg.id)) {
    const { res, rej } = pending.get(msg.id); pending.delete(msg.id);
    msg.error ? rej(new Error(`${msg.error.message} (${msg.error.code})`)) : res(msg.result);
    return;
  }
  const tab = bySession.get(msg.sessionId);
  if (!tab) return;
  const l = logs.get(tab);
  const p = msg.params || {};
  if (msg.method === 'Network.responseReceived' && p.response.status >= 400)
    l.push({ kind: 'http', status: p.response.status, url: p.response.url });
  else if (msg.method === 'Runtime.exceptionThrown')
    l.push({ kind: 'exception', text: p.exceptionDetails.exception?.description || p.exceptionDetails.text });
  else if (msg.method === 'Runtime.consoleAPICalled' && p.type === 'error')
    l.push({ kind: 'console.error', text: p.args.map((a) => a.value ?? a.description).join(' ') });
  else if (msg.method === 'Log.entryAdded' && p.entry.level === 'error')
    l.push({ kind: 'log.error', text: p.entry.text, url: p.entry.url });
};
const send = (method, params = {}, sessionId) => new Promise((res, rej) => {
  const id = nextId++;
  pending.set(id, { res, rej });
  ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
});

async function session(tab) {
  if (sessions.has(tab)) return sessions.get(tab);
  const { sessionId } = await send('Target.attachToTarget', { targetId: tab, flatten: true });
  sessions.set(tab, sessionId); bySession.set(sessionId, tab); logs.set(tab, []);
  for (const d of ['Page', 'Runtime', 'Network', 'Log']) await send(`${d}.enable`, {}, sessionId);
  return sessionId;
}
const cdp = async (tab, method, params) => send(method, params, await session(tab));
async function evaluate(tab, expression) {
  const r = await cdp(tab, 'Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true, userGesture: true });
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
  return r.result.value;
}
async function waitLoaded(tab) {
  for (let i = 0; i < 80; i++) {
    try { if ((await evaluate(tab, 'document.readyState')) === 'complete') return; } catch {}
    await sleep(150);
  }
}
const visibleFirst = (sel) => `(() => { const els = [...document.querySelectorAll(${JSON.stringify(sel)})]; const el = els.find((e) => e.offsetParent !== null || e.getClientRects().length) || null; return el; })()`;

const routes = {
  'GET /tabs': async () => {
    const { targetInfos } = await send('Target.getTargets');
    return targetInfos.filter((t) => t.type === 'page').map((t) => ({ tab: t.targetId, url: t.url, title: t.title, context: t.browserContextId }));
  },
  'POST /open': async ({ url = 'about:blank', context }) => {
    const p = { url, newWindow: true };
    if (context) {
      if (!contexts.has(context)) contexts.set(context, (await send('Target.createBrowserContext', { disposeOnDetach: false })).browserContextId);
      p.browserContextId = contexts.get(context);
    }
    const { targetId } = await send('Target.createTarget', p);
    await session(targetId); await waitLoaded(targetId);
    return { tab: targetId };
  },
  'POST /nav': async ({ tab, url }) => {
    const r = await cdp(tab, 'Page.navigate', { url });
    if (r.errorText) throw new Error(r.errorText);
    await sleep(100); await waitLoaded(tab);
    return { ok: true, url: await evaluate(tab, 'location.href') };
  },
  'POST /eval': async ({ tab, expr }) => ({ result: await evaluate(tab, expr) }),
  // DOM click on the first visible match. Dispatched mouse events often miss React; this does not.
  'POST /click': async ({ tab, selector }) => {
    const hit = await evaluate(tab, `(() => { const el = ${visibleFirst(selector)}; if (!el) return null; el.click(); return (el.innerText || el.value || el.tagName).slice(0, 80); })()`);
    if (hit === null) throw new Error(`no visible match for ${selector}`);
    return { clicked: hit };
  },
  // React-safe fill: prototype value setter plus input/change events. valueFile keeps secrets out of argv and output.
  'POST /fill': async ({ tab, selector, value, valueFile }) => {
    const v = valueFile ? readFileSync(valueFile, 'utf8').replace(/\r?\n$/, '') : value;
    const ok = await evaluate(tab, `(() => { const el = ${visibleFirst(selector)}; if (!el) return false;
      const proto = el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : el instanceof HTMLSelectElement ? HTMLSelectElement.prototype : HTMLInputElement.prototype;
      Object.getOwnPropertyDescriptor(proto, 'value').set.call(el, ${JSON.stringify(v)});
      el.dispatchEvent(new Event('input', { bubbles: true })); el.dispatchEvent(new Event('change', { bubbles: true })); return true; })()`);
    if (!ok) throw new Error(`no visible match for ${selector}`);
    return { ok: true };
  },
  'POST /screenshot': async ({ tab, path }) => {
    const { data } = await cdp(tab, 'Page.captureScreenshot', { format: 'png' });
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, Buffer.from(data, 'base64'));
    return { path };
  },
  'POST /cdp': async ({ tab, method, params }) => (tab ? cdp(tab, method, params) : send(method, params)),
  // Network >= 400, Runtime.exceptionThrown, console.error since last read (clear defaults true).
  'POST /log': async ({ tab, clear = true }) => { const l = logs.get(tab) || []; const out = [...l]; if (clear) l.length = 0; return out; },
  'POST /close': async ({ tab }) => { await send('Target.closeTarget', { targetId: tab }); return { ok: true }; },
  'POST /quit': async () => { setTimeout(shutdown, 50); return { ok: true }; },
};

async function shutdown() {
  try { await send('Browser.close'); } catch {}
  try { chromeProc?.kill(); } catch {}
  process.exit(0);
}
ws.onclose = () => process.exit(0);

createServer(async (req, res) => {
  const chunks = []; for await (const c of req) chunks.push(c);
  const reply = (code, body) => { res.writeHead(code, { 'content-type': 'application/json' }); res.end(JSON.stringify(body)); };
  const route = routes[`${req.method} ${req.url.split('?')[0]}`];
  if (!route) return reply(404, { error: 'unknown route', routes: Object.keys(routes) });
  try { reply(200, await route(chunks.length ? JSON.parse(Buffer.concat(chunks).toString()) : {})); }
  catch (e) { reply(500, { error: String(e.message || e) }); }
}).listen(port, HOST, () => console.log(`cdp-driver ready http://${HOST}:${port} chrome ${HOST}:${chromePort}`));
process.on('SIGTERM', shutdown); process.on('SIGINT', shutdown);
