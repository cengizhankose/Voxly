//! Tauri command handlers exposed to the webview over IPC.

use crate::audio::{AudioRecorder, InputDevice};
use crate::downloader;
use crate::models::{AppPaths, ModelLocator, ModelSize};
use crate::permissions;
use crate::state::{state, DictationState};
use crate::storage::{Settings, TranscriptionRecord};
use serde::Serialize;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use tauri::AppHandle;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ModelInfo {
    pub size: String,
    pub display_name: String,
    pub available: bool,
    pub active: bool,
    pub user_installed: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PermissionState {
    pub mic_granted: bool,
    pub accessibility_granted: bool,
}

#[tauri::command]
pub fn get_state(app: AppHandle) -> DictationState {
    let st = state(&app);
    st.refresh_permissions();
    st.snapshot()
}

#[tauri::command]
pub fn get_settings(app: AppHandle) -> Settings {
    state(&app).settings.lock().clone()
}

#[tauri::command]
pub fn update_settings(app: AppHandle, settings: Settings) {
    let st = state(&app);
    // Apply side-effects on change.
    st.audio
        .set_preferred_device(Some(settings.selected_input_device_uid.clone()));
    {
        let mut h = st.history.lock();
        h.prune(settings.history_retention_days);
        h.save();
    }
    let _ = crate::set_launch_at_login(&app, settings.launch_at_login);
    let _ = crate::register_hotkey(&app, &settings.hotkey);

    settings.save();
    *st.settings.lock() = settings;
    st.emit_state(&app);
}

#[tauri::command]
pub fn toggle_dictation(app: AppHandle) {
    state(&app).toggle(&app);
}

#[tauri::command]
pub fn list_input_devices() -> Vec<InputDevice> {
    AudioRecorder::list_devices()
}

#[tauri::command]
pub fn list_models(app: AppHandle) -> Vec<ModelInfo> {
    let st = state(&app);
    let res = st.resource_dir.lock().clone();
    let active = st.settings.lock().selected_model_size;
    let current = st.whisper.current_model_name();
    ModelSize::ALL
        .into_iter()
        .map(|size| ModelInfo {
            size: size.raw().to_string(),
            display_name: size.display_name().to_string(),
            available: ModelLocator::path_for(size, res.as_deref()).is_some(),
            active: size == active && current == size.raw(),
            user_installed: ModelLocator::user_installed(size),
        })
        .collect()
}

#[tauri::command]
pub fn download_model(app: AppHandle, size: String) -> Result<(), String> {
    let Some(size) = ModelSize::from_raw(&size) else {
        return Err("unknown model".into());
    };
    let st = state(&app);
    if st.download_cancel.lock().is_some() {
        return Err("a download is already in progress".into());
    }
    let cancel = Arc::new(AtomicBool::new(false));
    *st.download_cancel.lock() = Some(cancel.clone());

    let app2 = app.clone();
    tauri::async_runtime::spawn(async move {
        downloader::download(app2.clone(), size, cancel).await;
        state(&app2).download_cancel.lock().take();
    });
    Ok(())
}

#[tauri::command]
pub fn cancel_download(app: AppHandle) {
    if let Some(flag) = state(&app).download_cancel.lock().as_ref() {
        flag.store(true, Ordering::SeqCst);
    }
}

#[tauri::command]
pub fn delete_model(size: String) -> Result<bool, String> {
    let Some(size) = ModelSize::from_raw(&size) else {
        return Err("unknown model".into());
    };
    let path = AppPaths::models_dir().join(size.filename());
    if path.exists() {
        std::fs::remove_file(&path).map_err(|e| e.to_string())?;
        Ok(true)
    } else {
        Ok(false)
    }
}

#[tauri::command]
pub fn activate_model(app: AppHandle, size: String) -> Result<bool, String> {
    let Some(size) = ModelSize::from_raw(&size) else {
        return Err("unknown model".into());
    };
    let st = state(&app);
    let ok = st.activate_model(size);
    st.emit_state(&app);
    Ok(ok)
}

#[tauri::command]
pub fn get_history(app: AppHandle) -> Vec<TranscriptionRecord> {
    state(&app).history.lock().records.clone()
}

#[tauri::command]
pub fn delete_history_item(app: AppHandle, id: String) {
    let st = state(&app);
    let mut h = st.history.lock();
    h.records.retain(|r| r.id != id);
    h.save();
}

#[tauri::command]
pub fn clear_history(app: AppHandle) {
    let st = state(&app);
    let mut h = st.history.lock();
    h.records.clear();
    h.save();
}

#[tauri::command]
pub fn paste_from_history(app: AppHandle, text: String) -> bool {
    state(&app).paste_from_history(&text)
}

#[tauri::command]
pub fn check_permissions(app: AppHandle) -> PermissionState {
    let st = state(&app);
    st.refresh_permissions();
    let snap = st.snapshot();
    PermissionState {
        mic_granted: snap.mic_granted,
        accessibility_granted: snap.accessibility_granted,
    }
}

#[tauri::command]
pub fn request_accessibility() -> bool {
    let granted = permissions::request_accessibility();
    permissions::open_accessibility_settings();
    granted
}

#[tauri::command]
pub fn request_microphone() -> bool {
    permissions::microphone_granted()
}

#[tauri::command]
pub fn reveal_models_folder() {
    AppPaths::ensure_dirs();
    let dir = AppPaths::models_dir();
    let _ = std::process::Command::new("open").arg(dir).spawn();
}

#[tauri::command]
pub fn complete_onboarding(app: AppHandle) {
    let st = state(&app);
    st.settings.lock().has_completed_onboarding = true;
    st.settings.lock().save();
}

/// Wipe Voxly's Accessibility TCC entry and relaunch so a fresh grant binds to
/// the current code signature (ad-hoc CDHash churn workaround).
#[tauri::command]
pub fn reset_accessibility_and_relaunch(app: AppHandle) {
    let _ = std::process::Command::new("tccutil")
        .args(["reset", "Accessibility", "com.voxly.app"])
        .spawn();
    permissions::open_accessibility_settings();

    if let Ok(exe) = std::env::current_exe() {
        // Resolve the .app bundle from the executable path if possible.
        let bundle = exe
            .ancestors()
            .find(|p| p.extension().map(|e| e == "app").unwrap_or(false))
            .map(|p| p.to_path_buf());
        let target = bundle.unwrap_or(exe);
        let path = target.to_string_lossy().to_string();
        let _ = std::process::Command::new("/bin/sh")
            .arg("-c")
            .arg(format!("sleep 1.5; /usr/bin/open \"{path}\""))
            .spawn();
    }

    let handle = app.clone();
    std::thread::spawn(move || {
        std::thread::sleep(std::time::Duration::from_millis(400));
        handle.exit(0);
    });
}
