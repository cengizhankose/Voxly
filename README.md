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

## License

MIT
