# Voxly — Tauri edition

A rewrite of the native Swift/SwiftUI Voxly into **Tauri v2** (Rust backend +
React/TypeScript webview). Local speech-to-text dictation for macOS via
whisper.cpp with Metal GPU acceleration. Feature parity with the native app:
global hotkey, 16 kHz capture, synthesized ⌘V paste, model management,
history, settings, onboarding.

## Prerequisites

```bash
# Toolchain
brew install cmake            # whisper.cpp build
# Rust (stable) — https://rustup.rs
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# Node + pnpm
corepack enable && corepack prepare pnpm@latest --activate
```

## Bootstrap & run

```bash
pnpm install            # frontend deps
pnpm tauri dev          # dev build: vite + debug Rust, hot reload
```

On first run the app has **no whisper model** — open **Models** and download
one (base is the default). Models are stored in
`~/Library/Application Support/Voxly/models/`.

## Build

```bash
pnpm tauri build        # release .app + .dmg under src-tauri/target/release/bundle/
```

## Architecture

```
src-tauri/src/
  lib.rs          Tauri builder: plugins, tray, hotkey, window, setup
  state.rs        AppState + the record → transcribe → paste → history pipeline
  audio.rs        cpal capture → mono → 16 kHz f32 (dedicated stream thread)
  whisper.rs      whisper-rs (Metal) inference + transcript cleanup
  paste.rs        core-graphics CGEvent ⌘V (HID tap) + clipboard save/restore
  permissions.rs  Accessibility (AXIsProcessTrusted) + microphone checks
  downloader.rs   streaming model download with progress events
  storage.rs      settings + history (JSON in Application Support)
  models.rs       model catalog / paths / on-disk locator
  commands.rs     #[tauri::command] IPC handlers
src/
  lib/ipc.ts      typed command + event bridge (the ONLY backend contract)
  lib/types.ts    TS mirror of the Rust serde types
  styles/         "Signal" design tokens (ported from the SwiftUI Theme)
  components/     app shell (Sidebar, StatusBar)
  pages/          Onboarding, History, Models, Settings, About
```

The app is **not sandboxed** (synthesized paste + Accessibility require it) but
uses **hardened runtime** (required for notarization). The entitlements grant
microphone, WebKit JIT (`allow-jit` + `allow-unsigned-executable-memory` — a
notarized WebKit build crashes on launch without them), and apple-events.

## Distribution (GitHub Releases)

`.github/workflows/release.yml` builds, signs, notarizes, and drafts a GitHub
Release on `v*` tags. Configure these repository secrets:

| Secret | What |
|--------|------|
| `APPLE_CERTIFICATE` | base64 of the Developer ID Application `.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | password for the `.p12` |
| `APPLE_SIGNING_IDENTITY` | e.g. `Developer ID Application: Name (TEAMID)` |
| `APPLE_ID` / `APPLE_PASSWORD` | Apple ID + app-specific password (notarization) |
| `APPLE_TEAM_ID` | 10-char team id |
| `TAURI_SIGNING_PRIVATE_KEY` (+ `_PASSWORD`) | optional, for auto-update |

Requires an **Apple Developer Program** membership ($99/yr) for the Developer ID
certificate. Without it you can still ship an ad-hoc build, but users must strip
quarantine (`xattr -dr com.apple.quarantine Voxly.app`) or right-click → Open.

## Known gaps vs the native app

- Clipboard save/restore uses `arboard` (text/image only); the native
  `NSPasteboard` saved every type. Multi-type fidelity is a future improvement.
- Mic device persistence is by cpal device **name**, not the CoreAudio UID.
- 16 kHz resampling is linear interpolation (a sinc/polyphase pass is a TODO).
