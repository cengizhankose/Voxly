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

/** Word count for the detail meta line — cheap, whitespace-split. */
function wordCount(text: string): number {
  const t = text.trim();
  return t ? t.split(/\s+/).length : 0;
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

function AlertIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M12 8v5" />
      <circle cx="12" cy="16.5" r="0.6" fill="currentColor" stroke="none" />
      <path d="M10.3 3.9 2.6 17.5A2 2 0 0 0 4.3 20.5h15.4a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z" />
    </svg>
  );
}

function Spinner() {
  return (
    <svg className="history-btn-icon history-spin" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth={2.2} strokeOpacity={0.25} />
      <path d="M12 3a9 9 0 0 1 9 9" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" />
    </svg>
  );
}

// ---- Types ----

type Toast = { text: string; tone: "ok" | "warn" } | null;

// ---- Component ----

export function HistoryPage({ dictation }: { dictation: DictationState }) {
  const [records, setRecords] = useState<TranscriptionRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [editText, setEditText] = useState("");
  const [confirmClear, setConfirmClear] = useState(false);
  const [toast, setToast] = useState<Toast>(null);
  const [now, setNow] = useState(() => Date.now());
  const [copyBusy, setCopyBusy] = useState(false);
  const [pasteBusy, setPasteBusy] = useState(false);
  const [deleteBusy, setDeleteBusy] = useState(false);

  const toastTimer = useRef<number | undefined>(undefined);
  const loadedForId = useRef<string | null>(null);
  const listRef = useRef<HTMLDivElement>(null);

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
      setLoading(false);
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

  const flashToast = useCallback((text: string, tone: "ok" | "warn") => {
    window.clearTimeout(toastTimer.current);
    setToast({ text, tone });
    toastTimer.current = window.setTimeout(() => setToast(null), 1800);
  }, []);

  const handleCopy = useCallback(async () => {
    const text = editText;
    setCopyBusy(true);
    try {
      await navigator.clipboard.writeText(text);
      flashToast("Copied to clipboard", "ok");
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
      flashToast(ok ? "Copied to clipboard" : "Copy failed", ok ? "ok" : "warn");
    } finally {
      setCopyBusy(false);
    }
  }, [editText, flashToast]);

  const handlePaste = useCallback(async () => {
    setPasteBusy(true);
    try {
      const pasted = await api.pasteFromHistory(editText);
      if (pasted) {
        const target = dictation.lastExternalApp;
        flashToast(target ? `Pasted into ${target}` : "Pasted", "ok");
      } else {
        flashToast("Copied to clipboard (paste unavailable)", "warn");
      }
    } catch {
      flashToast("Paste failed", "warn");
    } finally {
      setPasteBusy(false);
    }
  }, [editText, dictation.lastExternalApp, flashToast]);

  const handleDelete = useCallback(async () => {
    if (!selected) return;
    const deletedId = selected.id;
    setDeleteBusy(true);
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
    setDeleteBusy(false);
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

  // Keyboard navigation through the list (↑/↓ move selection, Home/End jump).
  const moveSelection = useCallback(
    (delta: number) => {
      if (records.length === 0) return;
      const idx = records.findIndex((r) => r.id === selectedId);
      const base = idx === -1 ? 0 : idx;
      const nextIdx = Math.min(records.length - 1, Math.max(0, base + delta));
      setSelectedId(records[nextIdx].id);
    },
    [records, selectedId],
  );

  const onListKeyDown = useCallback(
    (e: React.KeyboardEvent<HTMLDivElement>) => {
      if (e.key === "ArrowDown") {
        e.preventDefault();
        moveSelection(1);
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        moveSelection(-1);
      } else if (e.key === "Home") {
        e.preventDefault();
        if (records.length) setSelectedId(records[0].id);
      } else if (e.key === "End") {
        e.preventDefault();
        if (records.length) setSelectedId(records[records.length - 1].id);
      }
    },
    [moveSelection, records],
  );

  const pasteLabel = dictation.lastExternalApp
    ? `Paste into ${dictation.lastExternalApp}`
    : "Re-paste";

  const isDirty = selected ? editText !== selected.text : false;

  // ---- Loading state ----
  if (loading) {
    return (
      <div className="history">
        <div className="history-toolbar">
          <div className="history-title">
            <span className="kicker">Transcripts</span>
            <span className="display">History</span>
          </div>
        </div>
        <div className="history-split">
          <div className="history-list" aria-hidden="true">
            {Array.from({ length: 6 }).map((_, i) => (
              <div className="history-row skeleton" key={i}>
                <span className="sk-line sk-w1" />
                <span className="sk-line sk-w2" />
                <span className="sk-line sk-w3" />
              </div>
            ))}
          </div>
          <div className="history-detail">
            <div className="history-detail-placeholder">
              <Spinner />
              <span className="mono muted">Loading history…</span>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // ---- Empty state ----
  if (records.length === 0) {
    return (
      <div className="history">
        <div className="history-toolbar">
          <div className="history-title">
            <span className="kicker">Transcripts</span>
            <span className="display">History</span>
          </div>
        </div>
        <div className="history-empty">
          <div className="history-empty-art" aria-hidden="true">
            <WaveformIcon />
          </div>
          <span className="display">No transcriptions yet</span>
          <span className="muted history-empty-copy">
            Press your dictation hotkey anywhere to start speaking. Everything you
            transcribe is captured here — editable and ready to re-paste.
          </span>
        </div>
      </div>
    );
  }

  return (
    <div className="history">
      <div className="history-toolbar">
        <div className="history-title">
          <span className="kicker">Transcripts</span>
          <span className="display">History</span>
        </div>
        <span className="history-count badge mono">
          {records.length} {records.length === 1 ? "record" : "records"}
        </span>
        <div className="history-toolbar-spacer" />
        {confirmClear ? (
          <div className="history-confirm" role="group" aria-label="Confirm clear all history">
            <span className="history-confirm-label">Delete all {records.length}?</span>
            <button className="btn btn-ghost btn-compact" onClick={() => setConfirmClear(false)}>
              Cancel
            </button>
            <button className="btn btn-danger btn-compact history-confirm-go" onClick={handleClearAll}>
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
        <div
          className="history-list"
          role="listbox"
          aria-label="Transcription history"
          tabIndex={0}
          ref={listRef}
          onKeyDown={onListKeyDown}
        >
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
                tabIndex={-1}
              >
                <span className="history-row-rail" aria-hidden="true" />
                <span className="history-row-top">
                  <span className="history-row-time mono">{relativeTime(r.createdAt, now)}</span>
                  <span className="history-row-dur mono">{formatDuration(r.durationSeconds)}</span>
                </span>
                <span className="history-row-preview">{r.text.trim() || "(empty)"}</span>
                <span className="history-row-meta">
                  {r.targetAppName ? (
                    <span className="history-row-app">
                      <AppIcon />
                      <span className="history-row-app-name">{r.targetAppName}</span>
                    </span>
                  ) : (
                    <span className="history-row-app muted-tag">Clipboard only</span>
                  )}
                  {r.language && <span className="history-row-lang mono">{r.language}</span>}
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
                <div className="history-detail-headtext">
                  <span className="kicker">Transcript</span>
                  <span className="history-detail-date">{formatFullDate(selected.createdAt)}</span>
                </div>
                <span className="badge history-detail-dur mono">
                  <ClockIcon />
                  {formatDuration(selected.durationSeconds)}
                </span>
              </div>
              <div className="history-detail-badges">
                <span className="badge">
                  <ClockIcon />
                  {relativeTime(selected.createdAt, now)}
                </span>
                {selected.targetAppName && (
                  <span className="badge badge-accent">
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
              <span className="history-detail-stats mono muted">
                {wordCount(editText)} {wordCount(editText) === 1 ? "word" : "words"}
                {isDirty && <span className="history-dirty">· edited</span>}
              </span>
              <div className="spacer" />
              <button
                className="btn btn-ghost btn-compact"
                onClick={handleCopy}
                disabled={copyBusy}
              >
                {copyBusy ? <Spinner /> : <CopyIcon />}
                Copy
              </button>
              <button
                className="btn btn-primary btn-compact"
                onClick={handlePaste}
                disabled={pasteBusy}
              >
                {pasteBusy ? <Spinner /> : <PasteIcon />}
                {pasteBusy ? "Pasting…" : pasteLabel}
              </button>
              <button
                className="btn btn-danger btn-compact"
                onClick={handleDelete}
                disabled={deleteBusy}
                aria-label="Delete transcript"
              >
                {deleteBusy ? <Spinner /> : <TrashIcon />}
                Delete
              </button>
            </div>

            {toast && (
              <div className={`history-toast${toast.tone === "warn" ? " warn" : ""}`} role="status">
                {toast.tone === "warn" ? <AlertIcon /> : <CheckIcon />}
                {toast.text}
              </div>
            )}
          </div>
        ) : (
          <div className="history-detail">
            <div className="history-detail-placeholder">
              <span className="mono muted">Select a transcript to view it.</span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
