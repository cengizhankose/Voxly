// Typed wrappers over the Tauri command + event bridge. All UI talks to the
// Rust backend exclusively through this module.

import { invoke } from "@tauri-apps/api/core";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";
import type {
  DictationState,
  DownloadProgress,
  DownloadResult,
  InputDevice,
  ModelInfo,
  ModelSize,
  PermissionState,
  Settings,
  TranscriptionRecord,
} from "./types";

// ---- Commands ----
export const api = {
  getState: () => invoke<DictationState>("get_state"),
  getSettings: () => invoke<Settings>("get_settings"),
  updateSettings: (settings: Settings) => invoke<void>("update_settings", { settings }),
  toggleDictation: () => invoke<void>("toggle_dictation"),

  listInputDevices: () => invoke<InputDevice[]>("list_input_devices"),

  listModels: () => invoke<ModelInfo[]>("list_models"),
  downloadModel: (size: ModelSize) => invoke<void>("download_model", { size }),
  cancelDownload: () => invoke<void>("cancel_download"),
  deleteModel: (size: ModelSize) => invoke<boolean>("delete_model", { size }),
  activateModel: (size: ModelSize) => invoke<boolean>("activate_model", { size }),

  getHistory: () => invoke<TranscriptionRecord[]>("get_history"),
  deleteHistoryItem: (id: string) => invoke<void>("delete_history_item", { id }),
  clearHistory: () => invoke<void>("clear_history"),
  pasteFromHistory: (text: string) => invoke<boolean>("paste_from_history", { text }),

  checkPermissions: () => invoke<PermissionState>("check_permissions"),
  requestAccessibility: () => invoke<boolean>("request_accessibility"),
  requestMicrophone: () => invoke<boolean>("request_microphone"),
  resetAccessibility: () => invoke<void>("reset_accessibility_and_relaunch"),

  revealModelsFolder: () => invoke<void>("reveal_models_folder"),
  completeOnboarding: () => invoke<void>("complete_onboarding"),
};

// ---- Events ----
export const events = {
  onDictationState: (cb: (s: DictationState) => void): Promise<UnlistenFn> =>
    listen<DictationState>("dictation-state", (e) => cb(e.payload)),
  onDownloadProgress: (cb: (p: DownloadProgress) => void): Promise<UnlistenFn> =>
    listen<DownloadProgress>("model-download-progress", (e) => cb(e.payload)),
  onDownloadDone: (cb: (r: DownloadResult) => void): Promise<UnlistenFn> =>
    listen<DownloadResult>("model-download-done", (e) => cb(e.payload)),
};
