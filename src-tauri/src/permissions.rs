//! macOS permission checks: Accessibility (required to synthesize Cmd+V) and
//! microphone. Accessibility uses the ApplicationServices AX* C API directly.

#[cfg(target_os = "macos")]
mod ax {
    use core_foundation::base::TCFType;
    use core_foundation::boolean::CFBoolean;
    use core_foundation::dictionary::{CFDictionary, CFDictionaryRef};
    use core_foundation::string::{CFString, CFStringRef};

    #[link(name = "ApplicationServices", kind = "framework")]
    extern "C" {
        fn AXIsProcessTrusted() -> bool;
        fn AXIsProcessTrustedWithOptions(options: CFDictionaryRef) -> bool;
        static kAXTrustedCheckOptionPrompt: CFStringRef;
    }

    pub fn is_trusted() -> bool {
        unsafe { AXIsProcessTrusted() }
    }

    /// Check trust and, if untrusted, show the system Accessibility prompt.
    pub fn prompt_and_check() -> bool {
        unsafe {
            let key = CFString::wrap_under_get_rule(kAXTrustedCheckOptionPrompt);
            let value = CFBoolean::true_value();
            let dict = CFDictionary::from_CFType_pairs(&[(key.as_CFType(), value.as_CFType())]);
            AXIsProcessTrustedWithOptions(dict.as_concrete_TypeRef())
        }
    }
}

/// Whether the app is trusted for Accessibility (can post synthetic events).
pub fn accessibility_granted() -> bool {
    #[cfg(target_os = "macos")]
    {
        ax::is_trusted()
    }
    #[cfg(not(target_os = "macos"))]
    {
        true
    }
}

/// Trigger the system Accessibility prompt (once per process) and return the
/// current trust state.
pub fn request_accessibility() -> bool {
    #[cfg(target_os = "macos")]
    {
        ax::prompt_and_check()
    }
    #[cfg(not(target_os = "macos"))]
    {
        true
    }
}

/// Deep-link to the Accessibility pane in System Settings.
pub fn open_accessibility_settings() {
    #[cfg(target_os = "macos")]
    {
        let _ = std::process::Command::new("open")
            .arg("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            .spawn();
    }
}

/// Best-effort microphone availability probe. Building an input stream triggers
/// the TCC prompt on first use; a success here means capture is permitted.
pub fn microphone_granted() -> bool {
    use cpal::traits::{DeviceTrait, HostTrait};
    let host = cpal::default_host();
    match host.default_input_device() {
        Some(device) => device.default_input_config().is_ok(),
        None => false,
    }
}
