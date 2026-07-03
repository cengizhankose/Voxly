//! Text delivery: clipboard write, synthesized Cmd+V into the target app, and
//! clipboard restore. Uses raw core-graphics CGEvent posted to the HID event
//! tap (NOT `enigo`, which crashes inside Tauri — see rewrite plan §5.1). The
//! pre-post delay and 300 ms restore delay are load-bearing timing.

use crate::storage::PasteMode;
use std::time::Duration;

const KVK_ANSI_V: core_graphics::event::CGKeyCode = 9;

#[derive(Debug, Clone, Default, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TargetApp {
    pub bundle_id: Option<String>,
    pub name: Option<String>,
    pub pid: i32,
}

/// Snapshot the frontmost application (to paste back into after Voxly may have
/// taken focus). Best-effort; returns None off macOS or on failure.
pub fn frontmost_app() -> Option<TargetApp> {
    #[cfg(target_os = "macos")]
    unsafe {
        use objc2_app_kit::NSWorkspace;
        let workspace = NSWorkspace::sharedWorkspace();
        let app = workspace.frontmostApplication()?;
        let bundle_id = app.bundleIdentifier().map(|s| s.to_string());
        let name = app.localizedName().map(|s| s.to_string());
        let pid = app.processIdentifier();
        Some(TargetApp {
            bundle_id,
            name,
            pid,
        })
    }
    #[cfg(not(target_os = "macos"))]
    {
        None
    }
}

#[cfg(target_os = "macos")]
fn our_pid() -> i32 {
    std::process::id() as i32
}

#[cfg(target_os = "macos")]
unsafe fn activate_pid(pid: i32) -> bool {
    use objc2_app_kit::{NSApplicationActivationOptions, NSRunningApplication};
    if let Some(app) = NSRunningApplication::runningApplicationWithProcessIdentifier(pid) {
        app.activateWithOptions(NSApplicationActivationOptions::ActivateIgnoringOtherApps)
    } else {
        false
    }
}

fn read_clipboard_text() -> Option<String> {
    arboard::Clipboard::new().ok()?.get_text().ok()
}

fn write_clipboard_text(text: &str) {
    if let Ok(mut cb) = arboard::Clipboard::new() {
        let _ = cb.set_text(text.to_string());
    }
}

/// Copy text to the clipboard only (no paste).
pub fn copy_to_clipboard(text: &str) {
    write_clipboard_text(text);
}

/// Synthesize Cmd+V via CGEvent posted to the HID tap.
fn synthesize_paste() -> Result<(), String> {
    use core_graphics::event::{CGEvent, CGEventFlags, CGEventTapLocation};
    use core_graphics::event_source::{CGEventSource, CGEventSourceStateID};

    let source = CGEventSource::new(CGEventSourceStateID::HIDSystemState)
        .map_err(|_| "failed to create event source".to_string())?;

    let key_down = CGEvent::new_keyboard_event(source.clone(), KVK_ANSI_V, true)
        .map_err(|_| "failed to create key-down event".to_string())?;
    key_down.set_flags(CGEventFlags::CGEventFlagCommand);
    key_down.post(CGEventTapLocation::HID);

    let key_up = CGEvent::new_keyboard_event(source, KVK_ANSI_V, false)
        .map_err(|_| "failed to create key-up event".to_string())?;
    key_up.set_flags(CGEventFlags::CGEventFlagCommand);
    key_up.post(CGEventTapLocation::HID);

    Ok(())
}

/// Deliver a transcript according to the paste mode. `accessibility_granted`
/// forces clipboard-only when false. `target` is the app to paste back into.
pub fn deliver(
    text: &str,
    mode: PasteMode,
    accessibility_granted: bool,
    target: Option<&TargetApp>,
) -> Result<(), String> {
    let effective = if accessibility_granted {
        mode
    } else {
        PasteMode::Clipboard
    };

    match effective {
        PasteMode::Clipboard => {
            write_clipboard_text(text);
            Ok(())
        }
        PasteMode::Paste => insert_text(text, target, false),
        PasteMode::Both => insert_text(text, target, true),
    }
}

/// Paste `text` into the target app, restoring the previous clipboard unless
/// `keep_clipboard` is set. Saves the current clipboard, writes the transcript,
/// optionally reactivates the target, synthesizes Cmd+V, then restores.
pub fn insert_text(
    text: &str,
    target: Option<&TargetApp>,
    keep_clipboard: bool,
) -> Result<(), String> {
    let saved = read_clipboard_text();
    write_clipboard_text(text);

    // Reactivate the target app if Voxly stole focus.
    let mut pre_delay = Duration::from_millis(50);
    #[cfg(target_os = "macos")]
    unsafe {
        if let Some(t) = target {
            if t.pid != 0 && t.pid != our_pid() {
                if activate_pid(t.pid) {
                    pre_delay = Duration::from_millis(150);
                }
            }
        }
    }
    #[cfg(not(target_os = "macos"))]
    let _ = target;

    std::thread::sleep(pre_delay);
    synthesize_paste()?;

    if !keep_clipboard {
        if let Some(prev) = saved {
            std::thread::spawn(move || {
                std::thread::sleep(Duration::from_millis(300));
                write_clipboard_text(&prev);
            });
        }
    }
    Ok(())
}
