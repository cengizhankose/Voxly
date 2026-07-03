//! Central application state and the end-to-end dictation pipeline.

use crate::audio::AudioRecorder;
use crate::models::{ModelLocator, ModelSize};
use crate::paste::{self, TargetApp};
use crate::permissions;
use crate::storage::{History, Settings, TranscriptionRecord};
use crate::whisper::{self, WhisperEngine};
use parking_lot::Mutex;
use serde::Serialize;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Instant;
use tauri::{AppHandle, Emitter, Manager};

/// UI-facing snapshot emitted on every state change over the `dictation-state`
/// event and returned by the `get_state` command.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DictationState {
    pub is_recording: bool,
    pub is_transcribing: bool,
    pub status: String,
    pub last_transcript: String,
    pub current_model: String,
    pub model_ready: bool,
    pub mic_granted: bool,
    pub accessibility_granted: bool,
    pub last_external_app: Option<String>,
}

pub struct AppState {
    pub audio: AudioRecorder,
    pub whisper: WhisperEngine,
    pub settings: Mutex<Settings>,
    pub history: Mutex<History>,

    is_recording: AtomicBool,
    is_transcribing: AtomicBool,
    status: Mutex<String>,
    last_transcript: Mutex<String>,

    target_app: Mutex<Option<TargetApp>>,
    last_external_app: Mutex<Option<TargetApp>>,
    recording_started_at: Mutex<Option<Instant>>,

    pub download_cancel: Mutex<Option<Arc<AtomicBool>>>,
    pub resource_dir: Mutex<Option<PathBuf>>,

    mic_granted: AtomicBool,
    accessibility_granted: AtomicBool,
}

impl AppState {
    pub fn new() -> Arc<AppState> {
        let settings = Settings::load();
        let mut history = History::load();
        history.prune(settings.history_retention_days);
        history.save();

        let audio = AudioRecorder::new();
        audio.set_preferred_device(Some(settings.selected_input_device_uid.clone()));

        Arc::new(AppState {
            audio,
            whisper: WhisperEngine::new(),
            settings: Mutex::new(settings),
            history: Mutex::new(history),
            is_recording: AtomicBool::new(false),
            is_transcribing: AtomicBool::new(false),
            status: Mutex::new("Loading model...".to_string()),
            last_transcript: Mutex::new(String::new()),
            target_app: Mutex::new(None),
            last_external_app: Mutex::new(None),
            recording_started_at: Mutex::new(None),
            download_cancel: Mutex::new(None),
            resource_dir: Mutex::new(None),
            mic_granted: AtomicBool::new(false),
            accessibility_granted: AtomicBool::new(false),
        })
    }

    // MARK: permissions

    pub fn refresh_permissions(&self) {
        self.mic_granted
            .store(permissions::microphone_granted(), Ordering::SeqCst);
        self.accessibility_granted
            .store(permissions::accessibility_granted(), Ordering::SeqCst);
    }

    pub fn set_status(&self, s: impl Into<String>) {
        *self.status.lock() = s.into();
    }

    // MARK: model loading

    pub fn load_initial_model(&self) {
        let size = self.settings.lock().selected_model_size;
        let res = self.resource_dir.lock().clone();
        let path = ModelLocator::path_for(size, res.as_deref())
            .or_else(|| ModelLocator::path_for(ModelSize::Base, res.as_deref()));
        match path {
            Some(p) => {
                let name = size.raw().to_string();
                let ok = self.whisper.load_model(&p.to_string_lossy(), &name);
                self.set_status(if ok { "Ready" } else { "Failed to load model" });
            }
            None => self.set_status("No model found. Download one in Models."),
        }
    }

    /// Switch to a different model, reloading the whisper context.
    pub fn activate_model(&self, size: ModelSize) -> bool {
        if self.is_recording.load(Ordering::SeqCst) || self.is_transcribing.load(Ordering::SeqCst) {
            return false;
        }
        let res = self.resource_dir.lock().clone();
        let Some(path) = ModelLocator::path_for(size, res.as_deref()) else {
            self.set_status("Model file not found");
            return false;
        };
        self.set_status("Applying model change...");
        let ok = self
            .whisper
            .load_model(&path.to_string_lossy(), size.raw());
        if ok {
            self.settings.lock().selected_model_size = size;
            self.settings.lock().save();
            self.set_status("Ready");
        } else {
            self.set_status("Failed to load model");
        }
        ok
    }

    // MARK: dictation

    pub fn snapshot(&self) -> DictationState {
        DictationState {
            is_recording: self.is_recording.load(Ordering::SeqCst),
            is_transcribing: self.is_transcribing.load(Ordering::SeqCst),
            status: self.status.lock().clone(),
            last_transcript: self.last_transcript.lock().clone(),
            current_model: self.whisper.current_model_name(),
            model_ready: self.whisper.is_loaded(),
            mic_granted: self.mic_granted.load(Ordering::SeqCst),
            accessibility_granted: self.accessibility_granted.load(Ordering::SeqCst),
            last_external_app: self
                .last_external_app
                .lock()
                .as_ref()
                .and_then(|a| a.name.clone()),
        }
    }

    pub fn emit_state(&self, app: &AppHandle) {
        let _ = app.emit("dictation-state", self.snapshot());
    }

    pub fn note_external_app(&self, app: Option<TargetApp>) {
        if let Some(a) = app {
            *self.last_external_app.lock() = Some(a);
        }
    }

    pub fn toggle(self: &Arc<Self>, app: &AppHandle) {
        if self.is_recording.load(Ordering::SeqCst) {
            self.stop_and_transcribe(app);
        } else {
            self.start(app);
        }
    }

    fn start(self: &Arc<Self>, app: &AppHandle) {
        self.refresh_permissions();
        if !self.mic_granted.load(Ordering::SeqCst) {
            self.set_status("Microphone access denied");
            self.emit_state(app);
            return;
        }
        if !self.whisper.is_loaded() {
            self.set_status("Model not ready");
            self.emit_state(app);
            return;
        }

        *self.target_app.lock() = paste::frontmost_app();
        *self.recording_started_at.lock() = Some(Instant::now());

        match self.audio.start() {
            Ok(()) => {
                self.is_recording.store(true, Ordering::SeqCst);
                self.set_status("Recording...");
            }
            Err(e) => {
                self.set_status(format!("Failed to start recording: {e}"));
            }
        }
        self.emit_state(app);
    }

    fn stop_and_transcribe(self: &Arc<Self>, app: &AppHandle) {
        self.audio.stop();
        self.is_recording.store(false, Ordering::SeqCst);
        self.is_transcribing.store(true, Ordering::SeqCst);
        self.set_status("Transcribing...");
        self.emit_state(app);

        let started = self.recording_started_at.lock().take();
        let duration = started.map(|s| s.elapsed().as_secs_f64()).unwrap_or(0.0);
        let target = self.target_app.lock().clone();

        let this = self.clone();
        let app = app.clone();
        std::thread::spawn(move || {
            let samples = this.audio.take_16k_mono();
            if samples.is_empty() {
                this.set_status("No audio captured");
                this.is_transcribing.store(false, Ordering::SeqCst);
                this.emit_state(&app);
                return;
            }

            let (lang_setting, mode) = {
                let s = this.settings.lock();
                (s.language_override.clone(), s.paste_mode)
            };
            let lang: Option<&str> = if lang_setting == "auto" || lang_setting.is_empty() {
                None
            } else {
                Some(&lang_setting)
            };

            let raw = this
                .whisper
                .transcribe(&samples, lang)
                .unwrap_or_default();
            let text = whisper::clean_transcript(&raw);

            if text.is_empty() {
                this.set_status("No speech detected");
                this.is_transcribing.store(false, Ordering::SeqCst);
                this.emit_state(&app);
                return;
            }

            *this.last_transcript.lock() = text.clone();

            let acc = this.accessibility_granted.load(Ordering::SeqCst);
            match paste::deliver(&text, mode, acc, target.as_ref()) {
                Ok(()) => this.set_status(if acc {
                    "Done"
                } else {
                    "Text copied (enable Accessibility for auto-paste)"
                }),
                Err(e) => this.set_status(format!("Paste failed: {e}")),
            }

            // Record history.
            let model_name = this.whisper.current_model_name();
            let record = TranscriptionRecord {
                id: uuid::Uuid::new_v4().to_string(),
                text,
                created_at: chrono::Utc::now().to_rfc3339(),
                duration_seconds: duration,
                language: lang.map(|s| s.to_string()),
                target_app_bundle_id: target.as_ref().and_then(|t| t.bundle_id.clone()),
                target_app_name: target.as_ref().and_then(|t| t.name.clone()),
                model_name,
            };
            {
                let mut h = this.history.lock();
                h.records.insert(0, record);
                let retention = this.settings.lock().history_retention_days;
                h.prune(retention);
                h.save();
            }

            this.is_transcribing.store(false, Ordering::SeqCst);
            this.emit_state(&app);
        });
    }

    /// Paste arbitrary text (e.g. from history) into the last external app.
    pub fn paste_from_history(&self, text: &str) -> bool {
        self.refresh_permissions();
        let acc = self.accessibility_granted.load(Ordering::SeqCst);
        let target = self.last_external_app.lock().clone();
        if !acc {
            paste::copy_to_clipboard(text);
            return false;
        }
        paste::insert_text(text, target.as_ref(), false).is_ok()
    }
}

pub type SharedState = Arc<AppState>;

/// Convenience accessor for command handlers.
pub fn state(app: &AppHandle) -> SharedState {
    app.state::<SharedState>().inner().clone()
}
