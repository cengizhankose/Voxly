//! Whisper model catalog, filesystem paths, and on-disk locator.

use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ModelSize {
    Tiny,
    Base,
    Small,
    Medium,
    Large,
}

impl ModelSize {
    pub const ALL: [ModelSize; 5] = [
        ModelSize::Tiny,
        ModelSize::Base,
        ModelSize::Small,
        ModelSize::Medium,
        ModelSize::Large,
    ];

    pub fn raw(&self) -> &'static str {
        match self {
            ModelSize::Tiny => "tiny",
            ModelSize::Base => "base",
            ModelSize::Small => "small",
            ModelSize::Medium => "medium",
            ModelSize::Large => "large",
        }
    }

    pub fn from_raw(s: &str) -> Option<ModelSize> {
        ModelSize::ALL.into_iter().find(|m| m.raw() == s)
    }

    pub fn filename(&self) -> String {
        format!("ggml-{}.bin", self.raw())
    }

    pub fn display_name(&self) -> &'static str {
        match self {
            ModelSize::Tiny => "Tiny (~75 MB)",
            ModelSize::Base => "Base (~142 MB)",
            ModelSize::Small => "Small (~466 MB)",
            ModelSize::Medium => "Medium (~1.5 GB)",
            ModelSize::Large => "Large (~2.9 GB)",
        }
    }

    /// Approximate on-disk size in bytes (used for the free-space precheck).
    pub fn approximate_bytes(&self) -> u64 {
        match self {
            ModelSize::Tiny => 78_000_000,
            ModelSize::Base => 148_000_000,
            ModelSize::Small => 488_000_000,
            ModelSize::Medium => 1_530_000_000,
            ModelSize::Large => 3_090_000_000,
        }
    }

    /// Hugging Face download URL for the ggml model.
    pub fn remote_url(&self) -> String {
        format!(
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-{}.bin",
            self.raw()
        )
    }
}

/// Application-support directory layout.
pub struct AppPaths;

impl AppPaths {
    /// `~/Library/Application Support/Voxly`
    pub fn support_dir() -> PathBuf {
        let base = dirs::data_dir().unwrap_or_else(|| PathBuf::from("."));
        base.join("Voxly")
    }

    /// `~/Library/Application Support/Voxly/models`
    pub fn models_dir() -> PathBuf {
        Self::support_dir().join("models")
    }

    pub fn ensure_dirs() {
        let _ = std::fs::create_dir_all(Self::models_dir());
    }

    pub fn settings_file() -> PathBuf {
        Self::support_dir().join("settings.json")
    }

    pub fn history_file() -> PathBuf {
        Self::support_dir().join("history.json")
    }
}

/// Resolve where a given model file lives, if anywhere.
pub struct ModelLocator;

impl ModelLocator {
    /// Look up the model file on disk. Checks the user models directory first,
    /// then the app-bundled resource (base only). Returns the path if present.
    pub fn path_for(size: ModelSize, resource_dir: Option<&Path>) -> Option<PathBuf> {
        let user_copy = AppPaths::models_dir().join(size.filename());
        if user_copy.exists() {
            return Some(user_copy);
        }
        // Bundled resource fallback (typically only base ships in the .app).
        if let Some(res) = resource_dir {
            let bundled = res.join(size.filename());
            if bundled.exists() {
                return Some(bundled);
            }
        }
        None
    }

    /// True when a user-installed (deletable) copy exists.
    pub fn user_installed(size: ModelSize) -> bool {
        AppPaths::models_dir().join(size.filename()).exists()
    }
}
