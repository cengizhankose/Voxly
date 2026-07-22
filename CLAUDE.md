# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Voxly is a macOS menu bar dictation app. Swift/SwiftUI front end, whisper.cpp (C) for on-device speech-to-text, called from Swift via an Obj-C bridging header against a vendored XCFramework. Option+D toggles recording; transcribed text is auto-pasted into the active app via synthesized Cmd+V.

## Three-step bootstrap (none of this lives in git)

The Xcode project, the whisper XCFramework, and the model are all gitignored. A fresh checkout will not build until you run, in order:

```bash
brew install cmake xcodegen
./Scripts/build-whisper-xcframework.sh   # clones whisper.cpp v1.8.1, builds static lib, creates Frameworks/whisper.xcframework
./Scripts/download-model.sh              # downloads ggml-base.bin (~142MB) to Resources/
xcodegen generate                        # regenerates Voxly.xcodeproj from project.yml
```

Build / run:

```bash
xcodebuild -scheme Voxly -configuration Release build
xcodebuild -scheme Voxly -configuration Debug build
# app lands in DerivedData; locate with:
xcodebuild -scheme Voxly -configuration Debug -showBuildSettings | grep BUILT_PRODUCTS_DIR
```

Re-run `xcodegen generate` after editing `project.yml` or adding/removing files under `Sources/Voxly/`. The whisper build script is a no-op if `Frameworks/whisper.xcframework` exists — `rm -rf` it to rebuild. If CMake fails with `make: /Applications/Xcode: No such file or directory`, the Xcode path contains a space; rerun with `CMAKE_GENERATOR=Ninja` (needs `brew install ninja`).

There is no test target, no linter, and no formatter configured.

## Architecture

Sources are grouped under `Sources/Voxly/`:

- `VoxlyApp.swift` — three scenes: `Window("Voxly", id: "main")` (history/models/settings/about), `Settings`, and a `MenuBarExtra` (`.window` style). `LSUIElement=true`: no Dock icon, no Cmd+Tab entry. The main window is closed at launch by `App/AppDelegate.swift` unless the "Show main window when launched" setting is on (`.defaultLaunchBehavior(.suppressed)` would be cleaner but needs macOS 15; target is 13). Onboarding runs as a sheet over the main window on first launch.
- `AppState.swift` — `@MainActor` root object; owns permissions state and composes the collaborators below. Child `objectWillChange` events are re-forwarded so views observing only `appState` stay reactive.
- `Controllers/DictationController.swift` — the record → transcribe → deliver pipeline and its state (`isRecording`, `isTranscribing`, `statusMessage`). Rejects near-silent audio (RMS < 0.004) before it reaches whisper — silence makes whisper hallucinate (typically Turkish subtitle credits from its training data), so this gate is load-bearing. Strips whisper's non-speech annotations (`[Music]`, `(silence)`, `*Sings*`). Empty results trigger a sound + transient `mic.slash` menu bar icon.
- `AudioRecorder.swift` — `AVAudioEngine` input tap → `AVAudioConverter` → 16 kHz mono Float32 PCM under an `NSLock`. whisper.cpp requires exactly this format.
- `WhisperEngine.swift` — Swift `actor` wrapping `whisper_context*`; never store the `OpaquePointer` outside the actor.
- `TextInserter.swift` — saves clipboard, writes transcript, synthesizes Cmd+V via `CGEvent`, restores clipboard 300ms later. The 50ms `usleep` before posting is load-bearing.
- `PermissionsManager.swift` — mic (`AVCaptureDevice`) + Accessibility (`AXIsProcessTrusted…`), plus `tccutil reset` recovery for stale grants.
- `Stores/` — `SettingsStore` (UserDefaults-backed: paste mode, language override, input device, model size, `showWindowOnLaunch`…), `HistoryStore` (history.json in App Support), `ModelDownloader`.
- `Models/` — `ModelSize`/`ModelCatalog`/`ModelLocator` (model files: bundled `ggml-base.bin`, user-installed under `~/Library/Application Support/Voxly/models/ggml-<size>.bin`), `AppPaths`, `TranscriptionRecord`, `PasteMode`.
- `Views/` — `Main/` (NavigationSplitView shell), `Settings/`, `Onboarding/`, `DesignSystem/` (`Theme`, shared components), plus `MenuBarView.swift` (popover).

## Hotkey — critical pitfall

Registered via the `KeyboardShortcuts` SPM package; name `toggleDictation` (default ⌥D) defined in `VoxlyApp.swift`. **Never place a `KeyboardShortcuts.Recorder` inside the MenuBarExtra popover**: focusing a recorder sets the library-internal `isPaused = true`, and the popover is a non-activating panel that never resigns key on dismiss — the pause sticks and the global hotkey stays dead until relaunch, with no error anywhere. Recorders are only safe in real windows (Settings pane, Onboarding). The popover shows the shortcut read-only.

## Signing & TCC — critical pitfall

`project.yml` signs ad-hoc (`CODE_SIGN_IDENTITY: "-"`) **plus** `OTHER_CODE_SIGN_FLAGS` stamping an identifier-only designated requirement (`identifier "com.voxly.app"`). Without this, every rebuild changes the CDHash and macOS silently voids the Accessibility grant — paste degrades to clipboard-only with no error. Keep the flag; use a real signing identity for distribution. Sandboxing must stay off: `CGEvent.post` and the Accessibility API are incompatible with the App Sandbox. `OTHER_LDFLAGS: -lc++` is required for whisper.cpp's C++ symbols.

Quit is forced via `applicationShouldTerminate → .terminateNow` in the AppDelegate — SwiftUI's adaptor delegate has been observed swallowing `NSApp.terminate` from the popover. The accessibility-reset flow uses `exit(0)` for the same reason.

## Logging discipline

`Logger(subsystem: "com.voxly.app", …)` throughout. macOS persists **notice and above**; `info` is memory-only and invisible after the fact. Pipeline breadcrumbs (hotkey registered/fired, recording start/stop, sample counts, RMS, transcription lengths) are deliberately `notice` — keep them that way; they are the only way to debug "pressed the hotkey, nothing happened" reports:

```bash
log show --predicate 'subsystem == "com.voxly.app"' --last 10m
```

## whisper.cpp integration

Bridge: `Voxly-Bridging-Header.h` includes `whisper.h`; `project.yml` wires `SWIFT_OBJC_BRIDGING_HEADER` and `HEADER_SEARCH_PATHS` at `Frameworks/whisper.xcframework/macos-arm64/Headers` (the build script produces an arm64-only slice — keep the path in sync if the script changes). Metal kernels are embedded in the static lib; no separate `.metallib` is required at runtime. Threads = `activeProcessorCount - 2` (min 1). Language comes from the Settings "Recognition" picker ("auto" → whisper auto-detect; auto-detect is only trustworthy because of the RMS silence gate).

## Conventions

- All UI state flows through `@MainActor` classes with `@Published` properties; background work hops via `Task` and writes back on the main actor. Do not mutate `@Published` off-main.
- New Swift files go under the matching `Sources/Voxly/` subdirectory and are picked up on the next `xcodegen generate`.
