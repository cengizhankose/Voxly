import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { UnlistenFn } from "@tauri-apps/api/event";
import { api, events } from "../lib/ipc";
import type { DownloadProgress, ModelInfo, ModelSize } from "../lib/types";
import "../styles/models.css";

// Canonical order shown in the native page (tiny -> large).
const MODEL_ORDER: ModelSize[] = ["tiny", "base", "small", "medium", "large"];

// Live per-model download state, driven entirely by backend events. `null`
// error means "in flight"; a string means the last attempt failed.
interface DownloadState {
  progress: number; // 0..1
  bytesWritten: number;
  totalBytes: number;
  inFlight: boolean;
  error: string | null;
}

// Local MB/GB byte formatter (mirrors ByteCountFormatter .useMB/.useGB, file style).
function formatBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 MB";
  const MB = 1000 * 1000;
  const GB = 1000 * MB;
  if (bytes >= GB) {
    const gb = bytes / GB;
    return `${gb >= 10 ? Math.round(gb) : gb.toFixed(1)} GB`;
  }
  return `${Math.max(1, Math.round(bytes / MB))} MB`;
}

export function ModelsPage() {
  const [models, setModels] = useState<ModelInfo[] | null>(null);
  const [downloads, setDownloads] = useState<Record<string, DownloadState>>({});
  const [busySize, setBusySize] = useState<ModelSize | null>(null); // activate/delete guard
  const mounted = useRef(true);

  const refresh = useCallback(async () => {
    try {
      const list = await api.listModels();
      if (mounted.current) setModels(list);
    } catch {
      if (mounted.current) setModels([]);
    }
  }, []);

  useEffect(() => {
    mounted.current = true;
    void refresh();

    let unlistenProgress: UnlistenFn | undefined;
    let unlistenDone: UnlistenFn | undefined;

    void events
      .onDownloadProgress((p: DownloadProgress) => {
        setDownloads((prev) => ({
          ...prev,
          [p.size]: {
            progress: p.progress,
            bytesWritten: p.bytesWritten,
            totalBytes: p.totalBytes,
            inFlight: true,
            error: null,
          },
        }));
      })
      .then((fn) => {
        unlistenProgress = fn;
      });

    void events
      .onDownloadDone((r) => {
        setDownloads((prev) => {
          const next = { ...prev };
          if (r.ok) {
            // Success: drop local state, the refetched list becomes source of truth.
            delete next[r.size];
          } else {
            next[r.size] = {
              progress: prev[r.size]?.progress ?? 0,
              bytesWritten: prev[r.size]?.bytesWritten ?? 0,
              totalBytes: prev[r.size]?.totalBytes ?? 0,
              inFlight: false,
              error: r.error ?? "Download failed",
            };
          }
          return next;
        });
        if (r.ok) void refresh();
      })
      .then((fn) => {
        unlistenDone = fn;
      });

    return () => {
      mounted.current = false;
      unlistenProgress?.();
      unlistenDone?.();
    };
  }, [refresh]);

  const anyInFlight = useMemo(
    () => Object.values(downloads).some((d) => d.inFlight),
    [downloads]
  );

  const rows = useMemo(() => {
    const bySize = new Map(models?.map((m) => [m.size, m]) ?? []);
    return MODEL_ORDER.map((size) => bySize.get(size)).filter(
      (m): m is ModelInfo => m != null
    );
  }, [models]);

  const startDownload = useCallback(async (size: ModelSize) => {
    // Optimistically mark in-flight so the button flips immediately; the first
    // progress event overwrites this with real numbers.
    setDownloads((prev) => ({
      ...prev,
      [size]: { progress: 0, bytesWritten: 0, totalBytes: 0, inFlight: true, error: null },
    }));
    try {
      await api.downloadModel(size);
    } catch (e) {
      setDownloads((prev) => ({
        ...prev,
        [size]: {
          progress: 0,
          bytesWritten: 0,
          totalBytes: 0,
          inFlight: false,
          error: e instanceof Error ? e.message : "Failed to start download",
        },
      }));
    }
  }, []);

  const cancelDownload = useCallback(async (size: ModelSize) => {
    try {
      await api.cancelDownload();
    } finally {
      setDownloads((prev) => {
        const next = { ...prev };
        delete next[size];
        return next;
      });
    }
  }, []);

  const activate = useCallback(
    async (size: ModelSize) => {
      setBusySize(size);
      try {
        await api.activateModel(size);
        await refresh();
      } finally {
        if (mounted.current) setBusySize(null);
      }
    },
    [refresh]
  );

  const remove = useCallback(
    async (model: ModelInfo) => {
      setBusySize(model.size);
      try {
        await api.deleteModel(model.size);
        await refresh();
      } finally {
        if (mounted.current) setBusySize(null);
      }
    },
    [refresh]
  );

  const reveal = useCallback(() => {
    void api.revealModelsFolder();
  }, []);

  return (
    <>
      <header className="page-header">
        <div className="kicker">Speech-to-text</div>
        <h1 className="display">Models</h1>
        <p className="subtitle">
          Larger models transcribe more accurately but run slower and use more
          memory. Only one model is active at a time.
        </p>
      </header>

      <section className="section">
        <div className="kicker section-title">Whisper models</div>
        <div className="card">
          {models === null ? (
            <div className="model-skeleton" aria-busy="true" aria-live="polite">
              {MODEL_ORDER.map((s) => (
                <div key={s} className="skeleton-row" />
              ))}
            </div>
          ) : rows.length === 0 ? (
            <div className="empty" style={{ height: "auto", padding: "24px 0" }}>
              <span className="muted">No models available.</span>
            </div>
          ) : (
            <div className="models-list">
              {rows.map((model) => (
                <ModelRow
                  key={model.size}
                  model={model}
                  download={downloads[model.size]}
                  anyInFlight={anyInFlight}
                  busy={busySize === model.size}
                  onDownload={() => void startDownload(model.size)}
                  onCancel={() => void cancelDownload(model.size)}
                  onActivate={() => void activate(model.size)}
                  onDelete={() => void remove(model)}
                />
              ))}
            </div>
          )}
        </div>
      </section>

      <section className="section">
        <div className="kicker section-title">Storage</div>
        <div className="card">
          <div className="storage-row">
            <div className="row-label">
              <span>Downloaded models</span>
              <span className="row-hint">
                Models are stored in Application Support. Open the folder to
                inspect or clear them manually.
              </span>
            </div>
            <button className="btn btn-ghost btn-compact" onClick={reveal}>
              <FolderIcon />
              Reveal Models Folder
            </button>
          </div>
        </div>
      </section>
    </>
  );
}

// ---- Row ----

interface ModelRowProps {
  model: ModelInfo;
  download: DownloadState | undefined;
  anyInFlight: boolean;
  busy: boolean;
  onDownload: () => void;
  onCancel: () => void;
  onActivate: () => void;
  onDelete: () => void;
}

function ModelRow({
  model,
  download,
  anyInFlight,
  busy,
  onDownload,
  onCancel,
  onActivate,
  onDelete,
}: ModelRowProps) {
  const isDownloading = download?.inFlight ?? false;
  const isFailed = !isDownloading && download?.error != null;

  // Precedence mirrors the native switch: downloading > failed > available > not-downloaded.
  const state: "downloading" | "failed" | "active" | "available" | "missing" =
    isDownloading
      ? "downloading"
      : isFailed
        ? "failed"
        : model.active
          ? "active"
          : model.available
            ? "available"
            : "missing";

  const stateClass =
    state === "downloading"
      ? "is-downloading"
      : state === "failed"
        ? "is-failed"
        : state === "active"
          ? "is-active"
          : state === "available"
            ? "is-available"
            : "is-missing";

  const pct =
    download && download.totalBytes > 0
      ? Math.round(download.progress * 100)
      : Math.round((download?.progress ?? 0) * 100);

  return (
    <div className={`model-row ${stateClass}`}>
      <div className="model-main">
        <span className="model-icon" aria-hidden="true">
          <StatusIcon state={state} />
        </span>

        <div className="model-info">
          <span className="model-name">{model.displayName}</span>
          {model.active && (
            <div className="model-sub">
              <span className="badge badge-accent badge-dot">Active model</span>
            </div>
          )}
        </div>

        <div className="model-actions">
          {state === "downloading" && (
            <button className="btn btn-ghost btn-compact" onClick={onCancel}>
              Cancel
            </button>
          )}

          {state === "failed" && (
            <button
              className="btn btn-primary btn-compact"
              onClick={onDownload}
              disabled={anyInFlight}
            >
              Retry
            </button>
          )}

          {state === "missing" && (
            <button
              className="btn btn-primary btn-compact"
              onClick={onDownload}
              disabled={anyInFlight}
            >
              <DownloadIcon />
              Download
            </button>
          )}

          {(state === "available" || state === "active") && (
            <>
              {state === "active" ? (
                <span className="model-check" title="Active model" aria-label="Active model">
                  <CheckCircleIcon />
                </span>
              ) : (
                <button
                  className="btn btn-primary btn-compact"
                  onClick={onActivate}
                  disabled={busy || anyInFlight}
                >
                  Use
                </button>
              )}
              {model.userInstalled && (
                <button
                  className="icon-btn"
                  onClick={onDelete}
                  disabled={busy}
                  title="Delete downloaded copy"
                  aria-label={`Delete ${model.displayName}`}
                >
                  <TrashIcon />
                </button>
              )}
            </>
          )}
        </div>
      </div>

      {state === "downloading" && (
        <div className="model-progress">
          <div className="progress" role="progressbar" aria-valuenow={pct} aria-valuemin={0} aria-valuemax={100}>
            <div style={{ width: `${Math.min(100, Math.max(2, pct))}%` }} />
          </div>
          <div className="model-progress-meta">
            <span>
              {formatBytes(download?.bytesWritten ?? 0)} /{" "}
              {formatBytes(download?.totalBytes ?? 0)}
            </span>
            <span className="model-progress-pct">{pct}%</span>
          </div>
        </div>
      )}

      {state === "failed" && download?.error && (
        <div className="model-error">{download.error}</div>
      )}
    </div>
  );
}

// ---- Icons (inline SVG, currentColor) ----

function StatusIcon({
  state,
}: {
  state: "downloading" | "failed" | "active" | "available" | "missing";
}) {
  switch (state) {
    case "active":
      return <CheckCircleIcon />;
    case "downloading":
      return <DownloadCircleIcon />;
    case "failed":
      return <WarningIcon />;
    case "available":
      return <BoxFilledIcon />;
    case "missing":
      return <BoxIcon />;
  }
}

function BoxIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 8 12 3 3 8v8l9 5 9-5V8Z" />
      <path d="m3.3 7.5 8.7 5 8.7-5" />
      <path d="M12 12.5V21" />
    </svg>
  );
}

function BoxFilledIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 8 12 3 3 8v8l9 5 9-5V8Z" fill="currentColor" fillOpacity="0.14" />
      <path d="m3.3 7.5 8.7 5 8.7-5" />
      <path d="M12 12.5V21" />
    </svg>
  );
}

function CheckCircleIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="9" fill="currentColor" fillOpacity="0.14" />
      <path d="m8.5 12 2.5 2.5 4.5-5" />
    </svg>
  );
}

function DownloadCircleIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 3a9 9 0 1 0 9 9" />
      <path d="M12 8v6" />
      <path d="m9 11.5 3 3 3-3" />
    </svg>
  );
}

function WarningIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
      <path d="M10.3 3.9 2.4 17.5A2 2 0 0 0 4.1 20.5h15.8a2 2 0 0 0 1.7-3l-7.9-13.6a2 2 0 0 0-3.4 0Z" fill="currentColor" fillOpacity="0.12" />
      <path d="M12 9v4.5" />
      <path d="M12 17h.01" />
    </svg>
  );
}

function DownloadIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 3v11" />
      <path d="m7.5 10 4.5 4.5 4.5-4.5" />
      <path d="M4.5 20h15" />
    </svg>
  );
}

function TrashIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 7h16" />
      <path d="M9.5 7V5.5a1.5 1.5 0 0 1 1.5-1.5h2a1.5 1.5 0 0 1 1.5 1.5V7" />
      <path d="M6.5 7 7.3 19a2 2 0 0 0 2 1.9h5.4a2 2 0 0 0 2-1.9L17.5 7" />
      <path d="M10 11v6M14 11v6" />
    </svg>
  );
}

function FolderIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 7.5A1.5 1.5 0 0 1 4.5 6h4l2 2.5h7A1.5 1.5 0 0 1 21 10v7.5A1.5 1.5 0 0 1 19.5 19h-15A1.5 1.5 0 0 1 3 17.5Z" />
    </svg>
  );
}
