# Voxly

A macOS menu bar dictation app powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp) for local, private speech-to-text.

Press **Option+D** to toggle recording. Transcribed text is automatically pasted into the active application.

## Features

- **Local processing** — all transcription runs on-device via whisper.cpp, no cloud API
- **Menu bar app** — lives in the macOS menu bar, no dock icon
- **Global hotkey** — Option+D to start/stop dictation (customizable)
- **Auto-paste** — transcribed text is inserted into the focused app via clipboard
- **Metal acceleration** — uses Apple GPU on Apple Silicon

## Requirements

- macOS 13.0+
- Xcode 15+
- [Homebrew](https://brew.sh) with `cmake` and `xcodegen`

## Setup

```bash
# Install build tools
brew install cmake xcodegen

# Build whisper.cpp XCFramework
./Scripts/build-whisper-xcframework.sh

# Download whisper base model (~142MB)
./Scripts/download-model.sh

# Generate Xcode project and build
xcodegen generate
xcodebuild -scheme Voxly -configuration Release build
```

## Permissions

- **Microphone** — prompted on first launch
- **Accessibility** — required for auto-paste (System Settings → Privacy → Accessibility)

## Architecture

| File | Purpose |
|------|---------|
| `VoxlyApp.swift` | App entry point with MenuBarExtra |
| `AppState.swift` | Central state management and hotkey registration |
| `AudioRecorder.swift` | AVAudioEngine → 16kHz mono Float32 PCM capture |
| `WhisperEngine.swift` | Actor wrapping whisper.cpp C API |
| `TextInserter.swift` | NSPasteboard + CGEvent Cmd+V injection |
| `PermissionsManager.swift` | Microphone and Accessibility permission handling |
| `MenuBarView.swift` | SwiftUI menu bar popover UI |

## Running — step by step

### 0. Prerequisites

- macOS 13+, Apple Silicon (build script is arm64-only)
- Xcode 15+ with command line tools selected (`xcode-select -p` should print Xcode path)
- Homebrew

```bash
brew install cmake xcodegen
```

### 1. Build whisper.cpp XCFramework (~3–5 min)

Clones `whisper.cpp v1.8.1`, builds a static library with Metal, packages an XCFramework.

```bash
./Scripts/build-whisper-xcframework.sh
```

Produces `Frameworks/whisper.xcframework/` and any `Resources/*.metallib`. Script no-ops if the framework exists — `rm -rf Frameworks/whisper.xcframework` to rebuild (e.g. to bump `WHISPER_TAG`).

### 2. Download whisper model (~142MB)

```bash
./Scripts/download-model.sh
```

Writes `Resources/ggml-base.bin`. No-ops if present.

### 3. Generate Xcode project

```bash
xcodegen generate
```

Produces `Voxly.xcodeproj` from `project.yml`. Re-run after editing `project.yml` or adding/removing Swift files in `Sources/Voxly/`.

### 4. Fix slice-path mismatch (likely needed on first build)

The build script produces a `macos-arm64/Headers` slice; `project.yml` references `macos-arm64_x86_64/Headers`. If the build fails with `whisper.h not found`:

```bash
ls Frameworks/whisper.xcframework/   # check actual slice name
```

Edit `project.yml` `HEADER_SEARCH_PATHS` to match the actual slice, then re-run `xcodegen generate`.

### 5. Build

```bash
xcodebuild -scheme Voxly -configuration Debug build
```

Locate the built `.app`:

```bash
xcodebuild -scheme Voxly -configuration Debug -showBuildSettings | grep -E "BUILT_PRODUCTS_DIR|FULL_PRODUCT_NAME"
```

### 6. Run

```bash
open "$(xcodebuild -scheme Voxly -configuration Debug -showBuildSettings | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2}')/Voxly.app"
```

Or open `Voxly.xcodeproj` in Xcode and press ⌘R.

The app appears in the menu bar (mic glyph) with no dock icon (`LSUIElement=true`).

### 7. Grant permissions

- **Microphone** — prompted on first record. If denied: System Settings → Privacy & Security → Microphone → enable Voxly.
- **Accessibility** — required for auto-paste. Click "Grant" in the menu bar popover, or System Settings → Privacy & Security → Accessibility → add Voxly. Without it the transcript is only copied to the clipboard.

### 8. Use

- Press **Option+D** → mic icon turns red, status reads "Recording…"
- Speak
- Press **Option+D** again → status reads "Transcribing…" → text auto-pastes into the focused app
- Rebind the hotkey via the menu bar popover (Recorder field)

### Troubleshooting

| Symptom | Fix |
|---------|-----|
| `whisper.h not found` | Step 4 — slice path mismatch |
| `Model not found` status | Re-run `./Scripts/download-model.sh`, then rebuild so the resource is bundled |
| Transcript only on clipboard, no paste | Grant Accessibility, restart the app |
| Hotkey ignored | Another app owns Option+D — rebind in the popover |
| Linker errors on `std::` symbols | Verify `OTHER_LDFLAGS: -lc++` in `project.yml` survived `xcodegen generate` |
| Rebuild whisper for new tag | Edit `WHISPER_TAG` in the script, `rm -rf Frameworks/whisper.xcframework`, re-run the script |

## License

MIT
