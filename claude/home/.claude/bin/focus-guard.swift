// focus-guard.swift (built and run by bin/focus-guard): stops apps that coding agents launch or drive (agent Chrome, Playwright, Electron
// dev builds, anything started under a claude/codex/gemini process) from taking keyboard focus.
// When one becomes frontmost without Lashaw clicking or cmd-tabbing to it, the app Lashaw was
// using is made frontmost again. The agent's window stays open behind it.
// Needs no macOS permissions: input timing comes from CGEventSource idle counters.
import AppKit
import CoreGraphics

let home = NSHomeDirectory()
let pauseFile = home + "/.claude/local/focus-guard/paused-until"
let logPath = home + "/Library/Logs/focus-guard.log"
// Written by ~/.claude/hooks/stamp-app-launch.sh when an agent's Bash command
// may open or activate an app (open -a, osascript, electron, ...).
let stampFile = home + "/.claude/local/focus-guard/agent-launch-at"

// Command-line markers of an agent-driven app.
let markers = [
  "--remote-debugging-port", "--enable-automation", "agent-browser/profile", "ms-playwright",
  "puppeteer", "Google Chrome for Testing", "Chromium.app", "/node_modules/electron/dist/",
  home + "/dev/", home + "/work/",
]
// An ancestor process with one of these names means an agent started the app directly.
let agentAncestors: Set<String> = ["claude", "codex", "gemini"]

func log(_ s: String) {
  let line = "\(ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withInternetDateTime])) \(s)\n"
  if let h = FileHandle(forWritingAtPath: logPath) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile() }
  else { FileManager.default.createFile(atPath: logPath, contents: line.data(using: .utf8)) }
}

func procArgs(_ pid: pid_t) -> String {
  var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
  var size = 0
  guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return "" }
  var buf = [UInt8](repeating: 0, count: size)
  guard sysctl(&mib, 3, &buf, &size, nil, 0) == 0, size > 4 else { return "" }
  // argc, exec path, padding, argv... ; join everything after argc, NULs as spaces, stop at env
  let argc = buf.withUnsafeBytes { $0.load(as: Int32.self) }
  var parts: [String] = []; var cur = [UInt8](); var i = 4; var seenArgs = -1
  while i < size, seenArgs < Int(argc) {
    if buf[i] == 0 { if !cur.isEmpty { parts.append(String(decoding: cur, as: UTF8.self)); seenArgs += 1; cur = [] } }
    else { cur.append(buf[i]) }
    i += 1
  }
  return parts.joined(separator: " ")
}

func parentAndName(_ pid: pid_t) -> (pid_t, String)? {
  var info = kinfo_proc(); var size = MemoryLayout<kinfo_proc>.stride
  var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
  guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
  let name = withUnsafePointer(to: info.kp_proc.p_comm) {
    $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) { String(cString: $0) } }
  return (info.kp_eproc.e_ppid, name)
}

func stampAge() -> Double {
  guard let s = try? String(contentsOfFile: stampFile, encoding: .utf8),
        let t = Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) else { return .infinity }
  return Date().timeIntervalSince1970 - t
}

// System apps and prompts (permission dialogs, password sheets) are never pushed back.
func isSystem(_ app: NSRunningApplication) -> Bool {
  let p = app.bundleURL?.path ?? ""
  return p.hasPrefix("/System/") || p.hasPrefix("/Library/") || p.contains("CoreServices")
}

// Dock, Finder and Spotlight launches record a parent app; `open` from a shell records none.
func hasParentApp(_ pid: pid_t) -> Bool {
  let p = Process(); let out = Pipe()
  p.executableURL = URL(fileURLWithPath: "/usr/bin/lsappinfo")
  p.arguments = ["info", "-only", "parentasn", "-app", "pid=\(pid)"]
  p.standardOutput = out; p.standardError = FileHandle.nullDevice
  guard (try? p.run()) != nil else { return true }
  p.waitUntilExit()
  return String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).contains("parentASN=")
}

var verdicts: [pid_t: String?] = [:]  // pid -> reason it is agent-driven, or nil

func agentReason(_ app: NSRunningApplication) -> String? {
  let pid = app.processIdentifier
  if let v = verdicts[pid] { return v }
  var reason: String? = nil
  let args = procArgs(pid) + " " + (app.bundleURL?.path ?? "")
  if let m = markers.first(where: { args.contains($0) }) { reason = "marker \(m)" }
  if reason == nil, !isSystem(app), let launched = app.launchDate,
     Date().timeIntervalSince(launched) < 30, stampAge() < 15 + Date().timeIntervalSince(launched),
     !hasParentApp(pid) { reason = "launched by an agent command" }
  var p = pid; var hops = 0
  while reason == nil, p > 1, hops < 30, let (pp, _) = parentAndName(p) {
    if pp > 1, let (_, n) = parentAndName(pp), agentAncestors.contains(n) { reason = "started by \(n)" }
    p = pp; hops += 1
  }
  verdicts[pid] = reason
  return reason
}

func since(_ t: CGEventType) -> Double { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: t) }

// Lashaw chose this app: a click (window or Dock) or a cmd-tab (a modifier change was the last
// key event) just before it came forward.
func userChose() -> Bool {
  let click = min(since(.leftMouseDown), since(.rightMouseDown), since(.otherMouseDown))
  if click < 1.5 { return true }
  let flags = since(.flagsChanged), key = since(.keyDown)
  return flags < 0.6 && flags <= key
}

func paused() -> Bool {
  guard let s = try? String(contentsOfFile: pauseFile, encoding: .utf8),
        let until = Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
  return Date().timeIntervalSince1970 < until
}

var lastUserApp: NSRunningApplication? = NSWorkspace.shared.frontmostApplication

func restore(_ target: NSRunningApplication, from thief: NSRunningApplication) {
  target.activate(options: [])
  DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
    if NSWorkspace.shared.frontmostApplication?.processIdentifier == thief.processIdentifier,
       let id = target.bundleIdentifier {
      let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/open"); p.arguments = ["-b", id]
      try? p.run()
    }
  }
}

let debug = ProcessInfo.processInfo.environment["FOCUS_GUARD_DEBUG"] != nil
let nc = NSWorkspace.shared.notificationCenter
nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { n in
  guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
  let name = app.localizedName ?? "?"
  if debug { log("activated \(name) pid \(app.processIdentifier)") }
  var reason = agentReason(app)
  // An agent command just ran `open -a`/osascript: an already-running app it brings forward too.
  if reason == nil, stampAge() < 5, !isSystem(app) { reason = "activated by an agent command" }
  guard let reason else { lastUserApp = app; return }
  if userChose() || paused() {
    if debug { log("allowed \(name): userChose=\(userChose()) paused=\(paused()) click=\(since(.leftMouseDown)) flags=\(since(.flagsChanged)) key=\(since(.keyDown))") }
    lastUserApp = app; return
  }
  // lastUserApp is whatever Lashaw was on: any app they chose, agent-launched or not.
  guard let back = lastUserApp, !back.isTerminated, back.processIdentifier != app.processIdentifier else {
    if debug { log("not restoring for \(name): back=\(lastUserApp?.localizedName ?? "nil")") }
    return
  }
  log("blocked \(name) (pid \(app.processIdentifier), \(reason)); returned focus to \(back.localizedName ?? "?")")
  restore(back, from: app)
}
nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { n in
  if let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
    verdicts.removeValue(forKey: app.processIdentifier)
  }
}
log("started (pid \(getpid()))")
NSApplication.shared.setActivationPolicy(.prohibited)
NSApplication.shared.run()
