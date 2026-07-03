//! Persisted settings and transcription history (plain JSON files owned by the
//! Rust backend, mirrored to the frontend over IPC).

use crate::models::{AppPaths, ModelSize};
use serde::{Deserialize, Serialize};

pub const SYSTEM_DEFAULT_MIC: &str = "__system_default__";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum PasteMode {
    Paste,
    Clipboard,
    Both,
}

impl Default for PasteMode {
    fn default() -> Self {
        PasteMode::Paste
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Settings {
    pub selected_model_size: ModelSize,
    pub selected_input_device_uid: String,
    pub paste_mode: PasteMode,
    pub language_override: String,
    pub launch_at_login: bool,
    pub show_window_on_launch: bool,
    pub history_retention_days: i64,
    pub has_completed_onboarding: bool,
    pub hotkey: String,
}

impl Default for Settings {
    fn default() -> Self {
        Settings {
            selected_model_size: ModelSize::Base,
            selected_input_device_uid: SYSTEM_DEFAULT_MIC.to_string(),
            paste_mode: PasteMode::Paste,
            language_override: "auto".to_string(),
            launch_at_login: false,
            show_window_on_launch: true,
            history_retention_days: 0,
            has_completed_onboarding: false,
            hotkey: "Alt+D".to_string(),
        }
    }
}

impl Settings {
    pub fn load() -> Settings {
        let path = AppPaths::settings_file();
        std::fs::read_to_string(&path)
            .ok()
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_default()
    }

    pub fn save(&self) {
        AppPaths::ensure_dirs();
        if let Ok(json) = serde_json::to_string_pretty(self) {
            let _ = std::fs::write(AppPaths::settings_file(), json);
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TranscriptionRecord {
    pub id: String,
    pub text: String,
    pub created_at: String,
    pub duration_seconds: f64,
    pub language: Option<String>,
    pub target_app_bundle_id: Option<String>,
    pub target_app_name: Option<String>,
    pub model_name: String,
}

#[derive(Default)]
pub struct History {
    pub records: Vec<TranscriptionRecord>,
}

impl History {
    pub fn load() -> History {
        let path = AppPaths::history_file();
        let records = std::fs::read_to_string(&path)
            .ok()
            .and_then(|s| serde_json::from_str::<Vec<TranscriptionRecord>>(&s).ok())
            .unwrap_or_default();
        History { records }
    }

    pub fn save(&self) {
        AppPaths::ensure_dirs();
        if let Ok(json) = serde_json::to_string_pretty(&self.records) {
            let _ = std::fs::write(AppPaths::history_file(), json);
        }
    }

    pub fn prune(&mut self, retention_days: i64) {
        if retention_days <= 0 {
            return;
        }
        let cutoff = chrono::Utc::now() - chrono::Duration::days(retention_days);
        self.records.retain(|r| {
            chrono::DateTime::parse_from_rfc3339(&r.created_at)
                .map(|dt| dt.with_timezone(&chrono::Utc) >= cutoff)
                .unwrap_or(true)
        });
    }
}
