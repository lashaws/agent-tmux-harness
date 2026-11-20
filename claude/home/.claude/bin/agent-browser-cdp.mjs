#!/usr/bin/env node
// Page commands for the agent browser, over raw Chrome DevTools Protocol.
// Our own code, no dependencies: Node's built-in fetch and WebSocket only.
// Called by ~/.claude/bin/agent-browser, which checks the window is ours first.
//
// Hard rule enforced here: never type into a password or one-time-code field, and never print
// their values. Those steps are Lashaw's.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const PORT = process.env.AGENT_BROWSER_PORT || '9222';
const BASE = `http://127.0.0.1:${PORT}`;
const STATE = path.join(os.homedir(), 'Library/Application Support/agent-browser/current-tab');
const die = (msg, code = 1) => { console.error(msg); process.exit(code); };
const sleep = ms => new Promise(r => setTimeout(r, ms));

// ---- arguments: <cmd> [args...] [--tab <sel>] [--submit] [--append] [--full]
const argv = process.argv.slice(2);
let tabSel;
const ti = argv.indexOf('--tab');
if (ti >= 0) { tabSel = argv[ti + 1]; argv.splice(ti, 2); }
const FLAGS = ['--submit', '--append', '--full'];
const flags = new Set(argv.filter(a => FLAGS.includes(a)));
const [cmd, ...rest] = argv.filter(a => !FLAGS.includes(a));

// ---- tabs
async function pages() {
  let r;
  try { r = await fetch(`${BASE}/json/list`); } catch { die('agent browser is not running: ~/.claude/bin/agent-browser start', 2); }
  return (await r.json()).filter(t => t.type === 'page');
}
const readState = () => { try { return fs.readFileSync(STATE, 'utf8').trim(); } catch { return ''; } };
const writeState = id => { try { fs.writeFileSync(STATE, id); } catch { /* best effort */ } };
async function pickTab(sel = tabSel) {
  const ps = await pages();
  if (!ps.length) die('no open tabs');
  if (sel !== undefined) {
    const t = /^\d+$/.test(sel) ? ps[+sel] : ps.find(p => new RegExp(sel, 'i').test(`${p.url} ${p.title}`));
    if (!t) die(`no tab matches ${sel}`);
    writeState(t.id);
    return t;
  }
  return ps.find(p => p.id === readState()) || ps[0];
}

// ---- CDP session
async function connect(tab) {
  const ws = new WebSocket(tab.webSocketDebuggerUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('could not attach to the tab')); });
  let n = 0;
  const waiting = new Map();
  ws.onmessage = e => {
    const m = JSON.parse(e.data);
    if (m.id && waiting.has(m.id)) {
      const { res, rej } = waiting.get(m.id);
      waiting.delete(m.id);
      m.error ? rej(new Error(m.error.message)) : res(m.result);
    }
  };
  const send = (method, params = {}) => new Promise((res, rej) => {
    const id = ++n;
    waiting.set(id, { res, rej });
    ws.send(JSON.stringify({ id, method, params }));
  });
  return { send, close: () => ws.close() };
}
async function evaluate(s, expr) {
  const r = await s.send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
  return r.result.value;
}
const call = (s, fn, ...args) => evaluate(s, `(${fn.toString()})(...${JSON.stringify(args)})`);
async function waitLoad(s, ms = 30000) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    try { if (await evaluate(s, 'document.readyState') === 'complete') return true; } catch { /* navigating */ }
    await sleep(250);
  }
  return false;
}
const where = s => call(s, () => `${location.href} | ${document.title}`);

// ---- functions that run inside the page
function pageSnapshot(MAX) {
  const SEL = 'a[href],button,input,select,textarea,summary,[role=button],[role=link],[role=checkbox],' +
    '[role=radio],[role=tab],[role=menuitem],[role=option],[role=switch],[role=combobox],' +
    '[contenteditable=""],[contenteditable=true]';
  const map = window.__ab = new Map();
  let next = 1, len = 0;
  const out = [];
  const push = s => { if (len < MAX) { out.push(s); len += s.length + 1; } };
  const clean = t => (t || '').replace(/\s+/g, ' ').trim();
  const visible = el => {
    const r = el.getBoundingClientRect();
    const st = getComputedStyle(el);
    if (st.display === 'contents') return true;
    return (r.width > 0 || r.height > 0) && st.visibility !== 'hidden' && st.display !== 'none' && +st.opacity !== 0;
  };
  const secret = el => el.tagName === 'INPUT' && (el.type === 'password' || /one-time-code/.test(el.autocomplete || ''));
  const label = el => clean(el.getAttribute('aria-label') || el.labels?.[0]?.innerText ||
    el.getAttribute('placeholder') || el.getAttribute('title') ||
    (['submit', 'button'].includes(el.type) && el.value) || el.innerText || el.getAttribute('alt') || el.name).slice(0, 80);
  const describe = (el, id) => {
    const tag = el.tagName.toLowerCase();
    const role = el.getAttribute('role') || (tag === 'a' ? 'link' : tag === 'input' ? (el.type || 'text') : tag);
    let s = `[${id} ${role} "${label(el)}"`;
    if (tag === 'input' || tag === 'textarea') {
      if (secret(el)) s += ' value=<hidden: Lashaw types this>';
      else if (['checkbox', 'radio'].includes(el.type)) s += el.checked ? ' checked' : ' unchecked';
      else if (el.value && !['submit', 'button'].includes(el.type)) s += ` value="${el.value.slice(0, 60)}"`;
    }
    if (tag === 'select') s += ` value="${el.selectedOptions[0]?.text || ''}"`;
    if (el.getAttribute('aria-expanded')) s += ` expanded=${el.getAttribute('aria-expanded')}`;
    if (el.disabled || el.getAttribute('aria-disabled') === 'true') s += ' disabled';
    if (tag === 'a') s += ` -> ${el.getAttribute('href').slice(0, 80)}`;
    return s + ']';
  };
  const SKIP = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE', 'SVG', 'HEAD', 'META', 'LINK']);
  const walk = node => {
    if (len >= MAX) return;
    if (node.nodeType === 3) { const t = clean(node.textContent); if (t) push(t); return; }
    if (node.nodeType !== 1) return;
    const el = node, tag = el.tagName.toUpperCase();
    if (SKIP.has(tag) || !visible(el)) return;
    if (tag === 'IFRAME') { push(`[iframe ${el.src.slice(0, 100)}: not read; open its URL in a tab]`); return; }
    if (el.matches(SEL)) { const id = next++; map.set(id, el); push(describe(el, id)); return; }
    if (/^H[1-6]$/.test(tag)) { push(`${'#'.repeat(+tag[1])} ${clean(el.innerText)}`); return; }
    if (tag === 'SLOT') { const a = el.assignedNodes(); (a.length ? a : [...el.childNodes]).forEach(walk); return; }
    if (el.shadowRoot) { el.shadowRoot.childNodes.forEach(walk); return; }
    el.childNodes.forEach(walk);
  };
  walk(document.body);
  return { title: document.title, url: location.href, text: out.join('\n'), truncated: len >= MAX, count: next - 1 };
}
function pageLocate(id) {
  const el = window.__ab?.get(id);
  if (!el || !el.isConnected) return { missing: true };
  el.scrollIntoView({ block: 'center', inline: 'center' });
  const r = el.getBoundingClientRect();
  const x = r.x + r.width / 2, y = r.y + r.height / 2;
  const hit = document.elementFromPoint(x, y);
  return {
    x, y, tag: el.tagName, covered: !!hit && !el.contains(hit) && !hit.contains(el),
    secret: el.tagName === 'INPUT' && (el.type === 'password' || /one-time-code/.test(el.autocomplete || '')),
  };
}
function pageSelectAll(id) {
  const el = window.__ab.get(id);
  el.focus();
  if (typeof el.select === 'function') el.select(); else document.execCommand('selectAll');
}
function pageChoose(id, want) {
  const el = window.__ab?.get(id);
  if (!el || el.tagName !== 'SELECT') return { error: 'not a <select>; click it and pick from the snapshot instead' };
  const opt = [...el.options].find(o => o.value === want || o.text.trim() === want) ||
    [...el.options].find(o => o.text.toLowerCase().includes(want.toLowerCase()));
  if (!opt) return { error: `no option matches; options: ${[...el.options].map(o => o.text.trim()).join(' | ').slice(0, 300)}` };
  // the prototype setter, so React-controlled selects register the change
  Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'value').set.call(el, opt.value);
  el.dispatchEvent(new Event('input', { bubbles: true }));
  el.dispatchEvent(new Event('change', { bubbles: true }));
  return { chose: opt.text.trim() };
}

// ---- input
const KEYS = { Enter: [13, '\r'], Tab: [9], Escape: [27], Backspace: [8], Delete: [46], ArrowUp: [38],
  ArrowDown: [40], ArrowLeft: [37], ArrowRight: [39], Space: [32, ' '], PageUp: [33], PageDown: [34], Home: [36], End: [35] };
async function press(s, key) {
  const k = KEYS[key];
  if (!k) die(`unknown key ${key}; one of: ${Object.keys(KEYS).join(' ')}`);
  const base = { key: key === 'Space' ? ' ' : key, code: key, windowsVirtualKeyCode: k[0], nativeVirtualKeyCode: k[0] };
  await s.send('Input.dispatchKeyEvent', { type: k[1] ? 'keyDown' : 'rawKeyDown', ...base, ...(k[1] ? { text: k[1] } : {}) });
  await s.send('Input.dispatchKeyEvent', { type: 'keyUp', ...base });
}
async function locate(s, id) {
  const loc = await call(s, pageLocate, +id);
  if (loc.missing) die(`no element ${id} on this page now; run snapshot again`);
  return loc;
}
async function clickAt(s, { x, y }) {
  await s.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
  await s.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
  await s.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
}
async function settle(s) { await sleep(400); await waitLoad(s, 15000); }

// ---- commands
const USAGE = `agent-browser page commands (add --tab <index|url-or-title regex> to pick a tab):
  tabs                      list tabs (* = current)
  use <sel>                 make a tab current
  new [url]                 open a new tab and make it current
  close                     close the current tab
  goto <url>                navigate and wait for load
  snapshot [--full]         page text with numbered controls: [id role "name" ...]
  click <id>                click control <id> from the last snapshot
  type <id> <text> [--append] [--submit]   (refuses password and one-time-code fields)
  select <id> <option>      pick an option in a <select>
  press <key>               ${Object.keys(KEYS).join(' ')}
  scroll <down|up>
  wait-text <text> [secs]   wait until the page shows text (default 60 s)
  screenshot [path]         PNG of the viewport; prints the path
  eval <js>                 run JavaScript in the page; prints the JSON result`;

async function main() {
  if (!cmd || cmd === 'help') { console.log(USAGE); return; }
  if (cmd === 'tabs') {
    const ps = await pages(), cur = (await pickTab()).id;
    ps.forEach((p, i) => console.log(`${p.id === cur ? '*' : ' '} ${i}  ${p.url.slice(0, 120)} | ${p.title.slice(0, 60)}`));
    return;
  }
  if (cmd === 'use') { const t = await pickTab(rest[0] ?? die('usage: use <index|regex>')); console.log(`current: ${t.url} | ${t.title}`); return; }
  if (cmd === 'new') {
    const t = await (await fetch(`${BASE}/json/new?about:blank`, { method: 'PUT' })).json();
    writeState(t.id);
    if (rest[0]) { const s = await connect(t); await s.send('Page.navigate', { url: rest[0] }); await waitLoad(s); console.log(`ok: ${await where(s)}`); s.close(); }
    else console.log('ok: new tab');
    return;
  }
  if (cmd === 'close') { const t = await pickTab(); await fetch(`${BASE}/json/close/${t.id}`); console.log(`closed: ${t.url}`); return; }

  const s = await connect(await pickTab());
  try {
    switch (cmd) {
      case 'goto': {
        const r = await s.send('Page.navigate', { url: rest[0] ?? die('usage: goto <url>') });
        if (r.errorText) die(`navigation failed: ${r.errorText}`);
        await waitLoad(s);
        console.log(`ok: ${await where(s)}`);
        break;
      }
      case 'snapshot': {
        const max = flags.has('--full') ? 60000 : 12000;
        const r = await call(s, pageSnapshot, max);
        console.log(`page: ${r.title}\nurl: ${r.url}\ncontrols: ${r.count}\n---\n${r.text}`);
        if (r.truncated) console.log(`--- (cut at ${max} chars; snapshot --full for more)`);
        break;
      }
      case 'click': {
        const loc = await locate(s, rest[0] ?? die('usage: click <id>'));
        if (loc.covered) {
          await call(s, id => window.__ab.get(id).click(), +rest[0]);
          console.log('note: the control was covered by another element; clicked it directly');
        } else await clickAt(s, loc);
        await settle(s);
        console.log(`ok: ${await where(s)}`);
        break;
      }
      case 'type': {
        const [id, ...words] = rest;
        if (!id || !words.length) die('usage: type <id> <text> [--append] [--submit]');
        const loc = await locate(s, id);
        if (loc.secret) die('refused: that is a password or one-time-code field. Hand this step to Lashaw.', 3);
        await clickAt(s, loc);
        if (!flags.has('--append')) await call(s, pageSelectAll, +id);
        await s.send('Input.insertText', { text: words.join(' ') });
        if (flags.has('--submit')) { await press(s, 'Enter'); await settle(s); }
        console.log(`ok: ${await where(s)}`);
        break;
      }
      case 'select': {
        const [id, ...want] = rest;
        const r = await call(s, pageChoose, +id, want.join(' '));
        if (r.error) die(r.error);
        console.log(`ok: chose "${r.chose}"`);
        break;
      }
      case 'press': await press(s, rest[0] ?? die('usage: press <key>')); await settle(s); console.log(`ok: ${await where(s)}`); break;
      case 'scroll': await evaluate(s, `window.scrollBy(0, ${rest[0] === 'up' ? -1 : 1} * innerHeight * 0.8)`); console.log('ok'); break;
      case 'wait-text': {
        const text = rest[0] ?? die('usage: wait-text <text> [secs]');
        const end = Date.now() + 1000 * (+rest[1] || 60);
        while (Date.now() < end) {
          try { if (await evaluate(s, `document.body.innerText.includes(${JSON.stringify(text)})`)) { console.log(`found: ${await where(s)}`); return; } } catch { /* navigating */ }
          await sleep(500);
        }
        die(`timed out waiting for text: ${text}`);
        break;
      }
      case 'screenshot': {
        const file = rest[0] || path.join(process.env.TMPDIR || os.tmpdir(), `agent-browser-${Date.now()}.png`);
        const r = await s.send('Page.captureScreenshot', { format: 'png' });
        fs.writeFileSync(file, Buffer.from(r.data, 'base64'));
        console.log(file);
        break;
      }
      case 'eval': {
        const v = await evaluate(s, rest.join(' ') || die('usage: eval <js>'));
        console.log(JSON.stringify(v, null, 1)?.slice(0, 20000));
        break;
      }
      default: die(`unknown command ${cmd}\n\n${USAGE}`);
    }
  } finally { s.close(); }
}
main().catch(e => die(`error: ${e.message}`));
