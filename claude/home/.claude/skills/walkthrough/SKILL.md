---
name: walkthrough
description: Open a headed Chrome over CDP that Lashaw signs into, then drive and check everything else yourself. Use when a step needs a human (sign-in, MFA, a web console or SaaS app, a desktop app), when Lashaw says "walk me through", "spin up a browser", "complete this autonomously", or when a live check needs a signed-in browser session. Lashaw does only the sign-in; you do the rest.
---

# Walkthrough: one sign-in, then you drive

Lashaw does ONLY the sign-in. You click, fill, read, screenshot and verify. For a desktop or SaaS tool,
get the one sign-in, then drive it through its CLI or API instead of its screens.

## 1. Start the driver (long-lived, in the background)

State (CDP sessions, virtual authenticators, contexts) lives in one Node process, so drive it with curl.
Scripts that exit lose that state.

1. Check the ports are free: `lsof -nP -iTCP:9333 -iTCP:9400 -sTCP:LISTEN`. Another session may hold one;
   pick others. Always use the literal `127.0.0.1`, never `localhost` (it can reach a different listener).
2. Pick the profile:
   - Low-risk site (test, staging, a personal SaaS): persistent `<config dir>/browser/<site>-profile`,
     mode 700 (`<config dir>` is `$CLAUDE_CONFIG_DIR` or `~/.claude`), so sign-ins carry over.
   - Production or admin session: a throwaway profile in the scratchpad. Sign out and delete it when done (see 5).
3. Start it with `run_in_background`:
   ```
   node ~/.claude/skills/walkthrough/cdp-driver.mjs --chrome-port 9333 --port 9400 --profile <dir> [--headless] [url]
   ```
   Node >= 22, no dependencies. It attaches if Chrome already listens on the chrome port, else launches it.
   Set `CHROME_BIN` for a non-default Chrome path. Omit `--headless` when Lashaw must sign in.
4. Ask for the sign-in in your reply, one line: which window, what to sign in with. Prefilling the email
   is fine. On macOS, `~/.claude/bin/focus-guard` keeps the window behind whatever Lashaw is using,
   so name it ("click the Chrome window"), or run `focus-guard pause 600` first. Wait for the page to show signed in (check with `/eval`); never ask "did you sign in?". If you poll for the sign-in with a background command, end it with `# waits on Lashaw` so the status line shows 👤.

## 2. Drive it with curl

Every command is pinned by tab id: new tabs become index 0 in `/json`, so "the first tab" is the wrong one.
```
curl -s 127.0.0.1:9400/tabs
curl -s -XPOST 127.0.0.1:9400/open -d '{"url":"https://example.com","context":"second-user"}'   # -> {"tab":"<id>"}
curl -s -XPOST 127.0.0.1:9400/nav -d '{"tab":"<id>","url":"..."}'
curl -s -XPOST 127.0.0.1:9400/eval -d '{"tab":"<id>","expr":"document.title"}'
curl -s -XPOST 127.0.0.1:9400/click -d '{"tab":"<id>","selector":"#b"}'
curl -s -XPOST 127.0.0.1:9400/fill -d '{"tab":"<id>","selector":"#email","value":"a@b.c"}'
curl -s -XPOST 127.0.0.1:9400/screenshot -d '{"tab":"<id>","path":"<scratchpad>/s.png"}'
curl -s -XPOST 127.0.0.1:9400/log -d '{"tab":"<id>"}'      # http >= 400, exceptions, console.error since last read
curl -s -XPOST 127.0.0.1:9400/cdp -d '{"tab":"<id>","method":"Page.bringToFront","params":{}}'
curl -s -XPOST 127.0.0.1:9400/close -d '{"tab":"<id>"}'; curl -s -XPOST 127.0.0.1:9400/quit -d '{}'
```
Errors return HTTP 500 with `{"error":...}`. Read the screenshot (Read tool on the PNG) to confirm what you did.

## 3. Hard-won details

- **Second user, signed out:** `/open` with a `context` name creates an in-memory browser context (own
  cookies, new window). It vanishes with Chrome.
- **React inputs:** setting `.value` is ignored. `/fill` uses the prototype value setter plus `input` and
  `change` events. Fields may be `id=`, not `name=`.
- **Clicks:** `/click` does a DOM `el.click()` on the first *visible* match (`offsetParent !== null`); a
  responsive page often renders both a table and a hidden card list, so labels appear twice.
- **Radix menus and selects** open on `pointerdown`: `el.click()` does nothing. Dispatch
  `new PointerEvent('pointerdown',{button:0,pointerType:'mouse',bubbles:true})` via `/eval`, then `pointerup` plus `click()`
  on the option. For real positions, `Input.dispatchMouseEvent` mouseMoved/Pressed/Released at the element
  centre via `/cdp`.
- **When a click seems to do nothing:** dispatched mouse events sometimes never reach React (touch events can
  hang). Before concluding the app is broken, wrap the element's `__reactProps$...` `onClick` to log, then click.
  A stale earlier navigation or state seeded before an async fetch lands often looks like a dropped query string.
- **Background windows** ignore dispatched events on dialogs: `button.click()` via `/eval` works for plain
  buttons. Send `Emulation.setFocusEmulationEnabled` when focus matters; `Page.bringToFront` is undone by
  focus-guard unless Lashaw is already in that window.
- **Virtual authenticator (passkeys):** hold ONE session (this driver does); it dies with its session. Then
  `WebAuthn.addVirtualAuthenticator` via `/cdp`.
- **Probe after a change with a page load**, not only `fetch`: server layouts often run only on page loads.
- **Capture on every action:** `/log` after each step; an HTTP 4xx/5xx or a thrown exception is a finding.

## 4. Secrets

- Never read or type a password or TOTP code. Lashaw types them.
- Any credential you must handle (a throwaway user's) goes into a 0600 file and is never echoed; fill from
  it with `/fill` `valueFile`. Print a length or fingerprint at most.
- Never print an invite or reset message preview; it can contain the temporary password.

## 5. Finish

- Production or admin: sign out through the app's logout URL, confirm an authenticated endpoint now returns 401,
  `/quit`, then delete the profile folder. Never leave a prod admin session on disk.
- Persistent low-risk profile: `/quit` and leave it.
- Run `lsof -nP -iTCP:<port> -sTCP:LISTEN` to confirm nothing of yours still listens.
