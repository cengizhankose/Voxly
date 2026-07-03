// Shared React hooks for global dictation state and settings.

import { useEffect, useState } from "react";
import { api, events } from "./ipc";
import type { DictationState, Settings } from "./types";

const EMPTY_STATE: DictationState = {
  isRecording: false,
  isTranscribing: false,
  status: "Loading...",
  lastTranscript: "",
  currentModel: "",
  modelReady: false,
  micGranted: false,
  accessibilityGranted: false,
  lastExternalApp: null,
};

/** Live dictation state, seeded from `get_state` and kept fresh via events. */
export function useDictationState(): DictationState {
  const [state, setState] = useState<DictationState>(EMPTY_STATE);

  useEffect(() => {
    let unlisten: (() => void) | undefined;
    api.getState().then(setState).catch(() => {});
    events.onDictationState(setState).then((u) => (unlisten = u));
    return () => unlisten?.();
  }, []);

  return state;
}

/** Settings with a persisting setter that round-trips through the backend. */
export function useSettings(): [Settings | null, (next: Settings) => Promise<void>] {
  const [settings, setSettings] = useState<Settings | null>(null);

  useEffect(() => {
    api.getSettings().then(setSettings).catch(() => {});
  }, []);

  const update = async (next: Settings) => {
    setSettings(next);
    await api.updateSettings(next);
  };

  return [settings, update];
}
