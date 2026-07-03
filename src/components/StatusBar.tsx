import { api } from "../lib/ipc";
import type { DictationState } from "../lib/types";

export function StatusBar({ dictation }: { dictation: DictationState }) {
  const dotClass = dictation.isRecording
    ? "recording"
    : dictation.isTranscribing
      ? "transcribing"
      : dictation.modelReady
        ? "ready"
        : "";

  return (
    <div className="statusbar">
      <span className={`status-dot ${dotClass}`} />
      <span>{dictation.status}</span>
      <div style={{ flex: 1 }} />
      {dictation.currentModel && <span className="mono">ggml-{dictation.currentModel}</span>}
      <button
        className="btn btn-ghost btn-compact"
        onClick={() => api.toggleDictation()}
        disabled={!dictation.modelReady}
      >
        {dictation.isRecording ? "Stop" : "Record"}
      </button>
    </div>
  );
}
