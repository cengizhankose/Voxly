// TypeScript mirror of the Rust IPC types (serde camelCase).

export type ModelSize = "tiny" | "base" | "small" | "medium" | "large";
export type PasteMode = "paste" | "clipboard" | "both";

export const SYSTEM_DEFAULT_MIC = "__system_default__";

export interface DictationState {
  isRecording: boolean;
  isTranscribing: boolean;
  status: string;
  lastTranscript: string;
  currentModel: string;
  modelReady: boolean;
  micGranted: boolean;
  accessibilityGranted: boolean;
  lastExternalApp: string | null;
}

export interface Settings {
  selectedModelSize: ModelSize;
  selectedInputDeviceUid: string;
  pasteMode: PasteMode;
  languageOverride: string;
  launchAtLogin: boolean;
  showWindowOnLaunch: boolean;
  historyRetentionDays: number;
  hasCompletedOnboarding: boolean;
  hotkey: string;
}

export interface ModelInfo {
  size: ModelSize;
  displayName: string;
  available: boolean;
  active: boolean;
  userInstalled: boolean;
}

export interface InputDevice {
  id: string;
  name: string;
}

export interface TranscriptionRecord {
  id: string;
  text: string;
  createdAt: string;
  durationSeconds: number;
  language: string | null;
  targetAppBundleId: string | null;
  targetAppName: string | null;
  modelName: string;
}

export interface PermissionState {
  micGranted: boolean;
  accessibilityGranted: boolean;
}

export interface DownloadProgress {
  size: ModelSize;
  progress: number;
  bytesWritten: number;
  totalBytes: number;
}

export interface DownloadResult {
  size: ModelSize;
  ok: boolean;
  error: string | null;
}

export const LANGUAGES: { code: string; label: string }[] = [
  { code: "auto", label: "Auto-detect" },
  { code: "en", label: "English" },
  { code: "es", label: "Spanish" },
  { code: "fr", label: "French" },
  { code: "de", label: "German" },
  { code: "tr", label: "Turkish" },
  { code: "ja", label: "Japanese" },
  { code: "zh", label: "Chinese" },
];

export const RETENTION_OPTIONS: { days: number; label: string }[] = [
  { days: 0, label: "Forever" },
  { days: 7, label: "7 days" },
  { days: 30, label: "30 days" },
  { days: 90, label: "90 days" },
];
