//! whisper.cpp inference via the `whisper-rs` bindings (Metal GPU on Apple
//! Silicon). The context is `!Sync`-guarded behind a Mutex; a fresh state is
//! created per transcription. Threads = physical cores - 2 (min 1), matching
//! the native app.

use parking_lot::Mutex;
use regex::Regex;
use std::sync::LazyLock;
use whisper_rs::{FullParams, SamplingStrategy, WhisperContext, WhisperContextParameters};

static PLACEHOLDER: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"[\[\(]\s*[A-Za-z _\-]+\s*[\]\)]").unwrap());

pub struct WhisperEngine {
    ctx: Mutex<Option<WhisperContext>>,
    model_name: Mutex<String>,
}

impl WhisperEngine {
    pub fn new() -> WhisperEngine {
        WhisperEngine {
            ctx: Mutex::new(None),
            model_name: Mutex::new(String::new()),
        }
    }

    pub fn is_loaded(&self) -> bool {
        self.ctx.lock().is_some()
    }

    pub fn current_model_name(&self) -> String {
        self.model_name.lock().clone()
    }

    /// Load (or replace) the model from a ggml file path. Returns success.
    pub fn load_model(&self, path: &str, name: &str) -> bool {
        let params = WhisperContextParameters::default();
        match WhisperContext::new_with_params(path, params) {
            Ok(ctx) => {
                *self.ctx.lock() = Some(ctx);
                *self.model_name.lock() = name.to_string();
                true
            }
            Err(e) => {
                log::error!("whisper load failed: {e}");
                false
            }
        }
    }

    #[allow(dead_code)]
    pub fn unload(&self) {
        *self.ctx.lock() = None;
    }

    /// Transcribe 16 kHz mono f32 samples. `language` = None for auto-detect.
    pub fn transcribe(&self, samples: &[f32], language: Option<&str>) -> Result<String, String> {
        let guard = self.ctx.lock();
        let ctx = guard.as_ref().ok_or_else(|| "model not loaded".to_string())?;

        let mut state = ctx.create_state().map_err(|e| e.to_string())?;

        let threads = std::thread::available_parallelism()
            .map(|n| n.get() as i32 - 2)
            .unwrap_or(1)
            .max(1);

        let mut params = FullParams::new(SamplingStrategy::Greedy { best_of: 1 });
        params.set_n_threads(threads);
        params.set_translate(false);
        params.set_language(Some(language.unwrap_or("auto")));
        params.set_no_context(true);
        params.set_single_segment(false);
        params.set_print_special(false);
        params.set_print_progress(false);
        params.set_print_realtime(false);
        params.set_print_timestamps(false);

        state.full(params, samples).map_err(|e| e.to_string())?;

        let n = state.full_n_segments().map_err(|e| e.to_string())?;
        let mut out = String::new();
        for i in 0..n {
            if let Ok(seg) = state.full_get_segment_text(i) {
                out.push_str(&seg);
            }
        }
        Ok(out)
    }
}

/// Strip whisper non-speech placeholder tokens like `[BLANK_AUDIO]`, `(Music)`,
/// `(silence)` while preserving real parenthetical text, then trim.
pub fn clean_transcript(s: &str) -> String {
    PLACEHOLDER.replace_all(s, "").trim().to_string()
}
