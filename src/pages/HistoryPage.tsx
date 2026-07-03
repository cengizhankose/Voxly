import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { api } from "../lib/ipc";
import type { DictationState, TranscriptionRecord } from "../lib/types";
import "../styles/history.css";

// ---- Time / duration helpers (no date libs) ----

/** Coarse minute/hour/day buckets — mirrors the native relative string. */
function relativeTime(iso: string, now: number): string {
  const then = new Date(iso).getTime();
  if (Number.isNaN(then)) return "";
  const secs = Math.max(0, (now - then) / 1000);
  if (secs < 60) return "Just now";
  if (secs < 3600) return `${Math.floor(secs / 60)}m ago`;
  if (secs < 86400) return `${Math.floor(secs / 3600)}h ago`;
  if (secs < 86400 * 7) return `${Math.floor(secs / 86400)}d ago`;
  return new Date(then).toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function formatDuration(seconds: number): string {
  const s = Math.round(seconds);
  return s < 60 ? `${s}s` : `${Math.floor(s / 60)}m ${s % 60}s`;
}

function formatFullDate(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  return d.toLocaleString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

// ---- Icons (inline SVG) ----

const iconProps = {
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.8,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
};

function CopyIcon() {
  return (
    <svg className="history-btn-icon" {...iconProps} aria-hidden="true">
      <rect x="9" y="9" width="11" height="11" rx="2" />
      <path d="M5 15V5a2 2 0 0 1 2-2h10" />
    </svg>
  );
}

function PasteIcon() {
  return (
    <svg className="history-btn-icon" {...iconProps} aria-hidden="true">
      <path d="M14 4h4a2 2 0 0 1 2 2v4" />
      <path d="M20 4 12 12" />
      <path d="M14 12v6a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />
    </svg>
  );
}

function TrashIcon() {
  return (
    <svg className="history-btn-icon" {...iconProps} aria-hidden="true">
      <path d="M4 7h16" />
      <path d="M10 11v6M14 11v6" />
      <path d="M6 7l1 13a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-13" />
      <path d="M9 7V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v3" />
    </svg>
  );
}

function AppIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} aria-hidden="true">
      <rect x="4" y="4" width="16" height="16" rx="4" strokeDasharray="3 3" />
    </svg>
  );
}

function CubeIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinejoin="round" aria-hidden="true">
      <path d="M12 3 20 7.5v9L12 21 4 16.5v-9L12 3Z" />
      <path d="M4 7.5 12 12l8-4.5M12 12v9" />
    </svg>
  );
}

function GlobeIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} aria-hidden="true">
      <circle cx="12" cy="12" r="9" />
      <path d="M3 12h18M12 3a15 15 0 0 1 0 18M12 3a15 15 0 0 0 0 18" />
    </svg>
  );
}

function ClockIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" aria-hidden="true">
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5l3 2" />
    </svg>
  );
}

function WaveformIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.6} strokeLinecap="round" aria-hidden="true">
      <path d="M4 11v2M8 8v8M12 4v16M16 8v8M20 11v2" />
    </svg>
  );
}

function CheckIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M5 13l4 4L19 7" />
    </svg>
  );
}

// ---- Types ----

type Toast = { text: string; warn: boolean } | null;

// ---- Component ----

export function HistoryPage({ dictation }: { dictation: DictationState }) {
  const [records, setRecords] = useState<TranscriptionRecord[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [editText, setEditText] = useState("");
  const [confirmClear, setConfirmClear] = useState(false);
  const [toast, setToast] = useState<Toast>(null);
  const [now, setNow] = useState(() => Date.now());

  const toastTimer = useRef<number | undefined>(undefined);
  const loadedForId = useRef<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      const list = await api.getHistory();
      setRecords(list);
      return list;
    } catch {
      return [] as TranscriptionRecord[];
    }
  }, []);

  // Initial load + select most recent.
  useEffect(() => {
    refresh().then((list) => {
      if (list.length > 0) setSelectedId((prev) => prev ?? list[0].id);
    });
  }, [refresh]);

  // A new transcription landed — refetch so the list stays live.
  useEffect(() => {
    if (!dictation.lastTranscript) return;
    refresh().then((list) => {
      if (list.length > 0) setSelectedId(list[0].id);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dictation.lastTranscript]);

  // Tick the relative-time display on a coarse 30s cadence.
  useEffect(() => {
    const t = window.setInterval(() => setNow(Date.now()), 30_000);
    return () => window.clearInterval(t);
  }, []);

  useEffect(() => () => window.clearTimeout(toastTimer.current), []);

  const selected = useMemo(
    () => records.find((r) => r.id === selectedId) ?? null,
    [records, selectedId],
  );

  // Load the selected record's text into the editable buffer once per id.
  useEffect(() => {
    if (!selected) {
      loadedForId.current = null;
      setEditText("");
      return;
    }
    if (loadedForId.current !== selected.id) {
      setEditText(selected.text);
      loadedForId.current = selected.id;
    }
  }, [selected]);

  const flashToast = useCallback((text: string, warn: boolean) => {
    window.clearTimeout(toastTimer.current);
    setToast({ text, warn });
    toastTimer.current = window.setTimeout(() => setToast(null), 1800);
  }, []);

  const handleCopy = useCallback(async () => {
    const text = editText;
    try {
      await navigator.clipboard.writeText(text);
      flashToast("Copied to clipboard", false);
    } catch {
      // Fallback for environments without the async clipboard API.
      const ta = document.createElement("textarea");
      ta.value = text;
      ta.style.position = "fixed";
      ta.style.opacity = "0";
      document.body.appendChild(ta);
      ta.select();
      const ok = document.execCommand("copy");
      document.body.removeChild(ta);
      flashToast(ok ? "Copied to clipboard" : "Copy failed", !ok);
    }
  }, [editText, flashToast]);

  const handlePaste = useCallback(async () => {
    try {
      const pasted = await api.pasteFromHistory(editText);
      if (pasted) {
        const target = dictation.lastExternalApp;
        flashToast(target ? `Pasted into ${target}` : "Pasted", false);
      } else {
        flashToast("Copied to clipboard (paste unavailable)", true);
      }
    } catch {
      flashToast("Paste failed", true);
    }
  }, [editText, dictation.lastExternalApp, flashToast]);

  const handleDelete = useCallback(async () => {
    if (!selected) return;
    const deletedId = selected.id;
    try {
      await api.deleteHistoryItem(deletedId);
    } catch {
      /* keep going; refresh will reconcile */
    }
    const list = await refresh();
    setSelectedId((prev) => {
      if (prev !== deletedId) return prev;
      return list.length > 0 ? list[0].id : null;
    });
  }, [selected, refresh]);

  const handleClearAll = useCallback(async () => {
    try {
      await api.clearHistory();
    } catch {
      /* refresh will reconcile */
    }
    setConfirmClear(false);
    setSelectedId(null);
    await refresh();
  }, [refresh]);

  // Cancel a pending clear-confirm if the list changes underneath it.
  useEffect(() => {
    if (records.length === 0) setConfirmClear(false);
  }, [records.length]);

  const pasteLabel = dictation.lastExternalApp
    ? `Paste into ${dictation.lastExternalApp}`
    : "Re-paste";

  // ---- Empty state ----
  if (records.length === 0) {
    return (
      <div className="history">
        <div className="history-toolbar">
          <span className="display">History</span>
        </div>
        <div className="history-empty empty">
          <WaveformIcon />
          <span className="display">No transcriptions yet</span>
          <span className="muted">
            Press your dictation hotkey anywhere to start. Transcripts show up here.
          </span>
        </div>
      </div>
    );
  }

  return (
    <div className="history">
      <div className="history-toolbar">
        <span className="display">History</span>
        <span className="history-count mono">
          {records.length} {records.length === 1 ? "record" : "records"}
        </span>
        <div className="history-toolbar-spacer" />
        {confirmClear ? (
          <div className="history-confirm">
            <span className="history-confirm-label">Clear all history?</span>
            <button className="btn btn-ghost btn-compact" onClick={() => setConfirmClear(false)}>
              Cancel
            </button>
            <button className="btn btn-danger btn-compact" onClick={handleClearAll}>
              Clear All
            </button>
          </div>
        ) : (
          <button className="btn btn-ghost btn-compact" onClick={() => setConfirmClear(true)}>
            <TrashIcon />
            Clear All
          </button>
        )}
      </div>

      <div className="history-split">
        {/* ---- List ---- */}
        <div className="history-list" role="listbox" aria-label="Transcription history">
          {records.map((r) => {
            const isSelected = r.id === selectedId;
            return (
              <button
                key={r.id}
                type="button"
                role="option"
                aria-selected={isSelected}
                className={`history-row${isSelected ? " selected" : ""}`}
                onClick={() => setSelectedId(r.id)}
              >
                <span className="history-row-preview">
                  {r.text.trim() || "(empty)"}
                </span>
                <span className="history-row-meta">
                  <span>{relativeTime(r.createdAt, now)}</span>
                  {r.targetAppName && (
                    <>
                      <span className="sep">·</span>
                      <span className="app">{r.targetAppName}</span>
                    </>
                  )}
                  <span className="sep">·</span>
                  <span>{formatDuration(r.durationSeconds)}</span>
                </span>
              </button>
            );
          })}
        </div>

        {/* ---- Detail ---- */}
        {selected ? (
          <div className="history-detail">
            <div className="history-detail-header">
              <div className="history-detail-headrow">
                <span className="history-detail-date">{formatFullDate(selected.createdAt)}</span>
                <span className="mono muted" style={{ fontSize: 12, whiteSpace: "nowrap" }}>
                  {formatDuration(selected.durationSeconds)}
                </span>
              </div>
              <div className="history-detail-badges">
                <span className="badge">
                  <ClockIcon />
                  {relativeTime(selected.createdAt, now)}
                </span>
                {selected.targetAppName && (
                  <span className="badge">
                    <AppIcon />
                    {selected.targetAppName}
                  </span>
                )}
                <span className="badge">
                  <CubeIcon />
                  {selected.modelName}
                </span>
                {selected.language && (
                  <span className="badge">
                    <GlobeIcon />
                    {selected.language}
                  </span>
                )}
              </div>
            </div>

            <div className="history-detail-body">
              <textarea
                className="history-detail-text"
                value={editText}
                spellCheck={false}
                onChange={(e) => setEditText(e.target.value)}
                aria-label="Transcript text"
                placeholder="(empty transcript)"
              />
            </div>

            <div className="history-detail-actions">
              <button className="btn btn-ghost btn-compact" onClick={handleCopy}>
                <CopyIcon />
                Copy
              </button>
              <button className="btn btn-primary btn-compact" onClick={handlePaste}>
                <PasteIcon />
                {pasteLabel}
              </button>
              <div className="spacer" />
              <button className="btn btn-danger btn-compact" onClick={handleDelete}>
                <TrashIcon />
                Delete
              </button>
            </div>

            {toast && (
              <div className={`history-toast${toast.warn ? " warn" : ""}`} role="status">
                {toast.warn ? <PasteIcon /> : <CheckIcon />}
                {toast.text}
              </div>
            )}
          </div>
        ) : (
          <div className="history-detail">
            <div className="history-detail-placeholder">Select a transcript to view it.</div>
          </div>
        )}
      </div>
    </div>
  );
}
