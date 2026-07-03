//! Streaming model downloader with live progress events and cancellation.

use crate::models::{AppPaths, ModelSize};
use futures_util::StreamExt;
use serde::Serialize;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use tauri::{AppHandle, Emitter};
use tokio::io::AsyncWriteExt;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DownloadProgress {
    pub size: String,
    pub progress: f64,
    pub bytes_written: u64,
    pub total_bytes: u64,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DownloadResult {
    pub size: String,
    pub ok: bool,
    pub error: Option<String>,
}

/// Stream a model to `models/<file>.part`, emitting `model-download-progress`
/// events, then atomically rename to the final path. Emits `model-download-done`
/// on completion (success or failure).
pub async fn download(app: AppHandle, size: ModelSize, cancel: Arc<AtomicBool>) {
    let result = download_inner(&app, size, &cancel).await;
    let payload = match &result {
        Ok(_) => DownloadResult {
            size: size.raw().to_string(),
            ok: true,
            error: None,
        },
        Err(e) => DownloadResult {
            size: size.raw().to_string(),
            ok: false,
            error: Some(e.clone()),
        },
    };
    let _ = app.emit("model-download-done", payload);
}

async fn download_inner(
    app: &AppHandle,
    size: ModelSize,
    cancel: &Arc<AtomicBool>,
) -> Result<(), String> {
    AppPaths::ensure_dirs();
    let dest = AppPaths::models_dir().join(size.filename());
    let part = AppPaths::models_dir().join(format!("{}.part", size.filename()));

    let client = reqwest::Client::builder()
        .build()
        .map_err(|e| e.to_string())?;
    let resp = client
        .get(size.remote_url())
        .send()
        .await
        .map_err(|e| e.to_string())?
        .error_for_status()
        .map_err(|e| e.to_string())?;

    let total = resp.content_length().unwrap_or(size.approximate_bytes());
    let mut file = tokio::fs::File::create(&part)
        .await
        .map_err(|e| e.to_string())?;

    let mut stream = resp.bytes_stream();
    let mut written: u64 = 0;
    let mut last_emit: u64 = 0;

    while let Some(chunk) = stream.next().await {
        if cancel.load(Ordering::SeqCst) {
            drop(file);
            let _ = tokio::fs::remove_file(&part).await;
            return Err("cancelled".to_string());
        }
        let chunk = chunk.map_err(|e| e.to_string())?;
        file.write_all(&chunk).await.map_err(|e| e.to_string())?;
        written += chunk.len() as u64;

        // Throttle progress events to ~every 512 KB.
        if written - last_emit >= 512 * 1024 || written == total {
            last_emit = written;
            let progress = if total > 0 {
                (written as f64 / total as f64).min(1.0)
            } else {
                0.0
            };
            let _ = app.emit(
                "model-download-progress",
                DownloadProgress {
                    size: size.raw().to_string(),
                    progress,
                    bytes_written: written,
                    total_bytes: total,
                },
            );
        }
    }

    file.flush().await.map_err(|e| e.to_string())?;
    drop(file);
    tokio::fs::rename(&part, &dest)
        .await
        .map_err(|e| e.to_string())?;
    Ok(())
}
