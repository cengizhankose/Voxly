//! Voxly — local speech-to-text dictation for macOS, Tauri edition.

mod audio;
mod commands;
mod downloader;
mod models;
mod paste;
mod permissions;
mod state;
mod storage;
mod whisper;

use state::{AppState, SharedState};
use std::time::Duration;
use tauri::{
    menu::{Menu, MenuItem, PredefinedMenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Manager, WindowEvent,
};
use tauri_plugin_autostart::ManagerExt;
use tauri_plugin_global_shortcut::{GlobalShortcutExt, ShortcutState};

const BUNDLE_ID: &str = "com.voxly.app";

/// (Re)register the single global toggle shortcut.
pub fn register_hotkey(app: &AppHandle, accel: &str) -> Result<(), String> {
    let gs = app.global_shortcut();
    let _ = gs.unregister_all();
    gs.register(accel).map_err(|e| e.to_string())
}

/// Enable/disable launch-at-login via the autostart plugin.
pub fn set_launch_at_login(app: &AppHandle, enabled: bool) -> Result<(), String> {
    let m = app.autolaunch();
    if enabled {
        m.enable().map_err(|e| e.to_string())
    } else {
        m.disable().map_err(|e| e.to_string())
    }
}

fn show_main_window(app: &AppHandle) {
    if let Some(win) = app.get_webview_window("main") {
        let _ = win.show();
        let _ = win.unminimize();
        let _ = win.set_focus();
    }
}

fn build_tray(app: &tauri::App) -> tauri::Result<()> {
    let toggle = MenuItem::with_id(app, "toggle", "Toggle Dictation", true, None::<&str>)?;
    let open = MenuItem::with_id(app, "open", "Open Voxly", true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", "Quit Voxly", true, None::<&str>)?;
    let menu = Menu::with_items(
        app,
        &[&toggle, &open, &PredefinedMenuItem::separator(app)?, &quit],
    )?;

    let mut builder = TrayIconBuilder::new()
        .menu(&menu)
        .show_menu_on_left_click(false)
        .tooltip("Voxly")
        .on_menu_event(|app, event| match event.id.as_ref() {
            "toggle" => state::state(app).toggle(app),
            "open" => show_main_window(app),
            "quit" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                ..
            } = event
            {
                show_main_window(tray.app_handle());
            }
        });

    if let Some(icon) = app.default_window_icon() {
        builder = builder.icon(icon.clone());
    }
    builder.build(app)?;
    Ok(())
}

/// Poll the frontmost app so paste-from-history can target the last external
/// app (mirrors NSWorkspace.didActivateApplicationNotification).
fn spawn_frontmost_poller(st: SharedState) {
    std::thread::spawn(move || loop {
        std::thread::sleep(Duration::from_millis(1200));
        if let Some(app) = paste::frontmost_app() {
            if app.bundle_id.as_deref() != Some(BUNDLE_ID) {
                st.note_external_app(Some(app));
            }
        }
    });
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_store::Builder::new().build())
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            None,
        ))
        .plugin(
            tauri_plugin_global_shortcut::Builder::new()
                .with_handler(|app, _shortcut, event| {
                    if event.state() == ShortcutState::Pressed {
                        state::state(app).toggle(app);
                    }
                })
                .build(),
        )
        .setup(|app| {
            let handle = app.handle().clone();
            let st = AppState::new();

            if let Ok(res) = app.path().resource_dir() {
                *st.resource_dir.lock() = Some(res);
            }
            app.manage(st.clone());
            st.refresh_permissions();

            // Load the model off the main thread (whisper init can take a while).
            {
                let st2 = st.clone();
                let h2 = handle.clone();
                std::thread::spawn(move || {
                    st2.load_initial_model();
                    st2.emit_state(&h2);
                });
            }

            let (hotkey, launch_at_login, show_window) = {
                let s = st.settings.lock();
                (
                    s.hotkey.clone(),
                    s.launch_at_login,
                    s.show_window_on_launch || !s.has_completed_onboarding,
                )
            };
            let _ = register_hotkey(&handle, &hotkey);
            let _ = set_launch_at_login(&handle, launch_at_login);

            build_tray(app)?;

            if let Some(win) = app.get_webview_window("main") {
                if show_window {
                    let _ = win.show();
                    let _ = win.set_focus();
                } else {
                    let _ = win.hide();
                }
            }

            spawn_frontmost_poller(st.clone());
            Ok(())
        })
        .on_window_event(|window, event| {
            // Closing the main window hides it instead of quitting (menu-bar app).
            if let WindowEvent::CloseRequested { api, .. } = event {
                if window.label() == "main" {
                    api.prevent_close();
                    let _ = window.hide();
                }
            }
        })
        .invoke_handler(tauri::generate_handler![
            commands::get_state,
            commands::get_settings,
            commands::update_settings,
            commands::toggle_dictation,
            commands::list_input_devices,
            commands::list_models,
            commands::download_model,
            commands::cancel_download,
            commands::delete_model,
            commands::activate_model,
            commands::get_history,
            commands::delete_history_item,
            commands::clear_history,
            commands::paste_from_history,
            commands::check_permissions,
            commands::request_accessibility,
            commands::request_microphone,
            commands::reveal_models_folder,
            commands::complete_onboarding,
            commands::relaunch_app,
            commands::reset_accessibility_and_relaunch,
        ])
        .run(tauri::generate_context!())
        .expect("error while running Voxly");
}
