//! Microphone capture. A dedicated thread owns the cpal stream (which is
//! `!Send`) and is driven over a channel. Samples are downmixed to mono and
//! accumulated at the device's native rate, then resampled to 16 kHz mono
//! Float32 on `take_16k_mono()` — the exact format whisper.cpp requires.

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use parking_lot::Mutex;
use serde::Serialize;
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::mpsc::{channel, Sender};
use std::sync::Arc;

pub const TARGET_RATE: u32 = 16_000;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct InputDevice {
    /// cpal exposes a device name, not the CoreAudio UID; we persist by name.
    pub id: String,
    pub name: String,
}

struct Shared {
    buffer: Mutex<Vec<f32>>,
    device_rate: AtomicU32,
    recording: AtomicBool,
    preferred: Mutex<Option<String>>,
}

enum Cmd {
    Start(Sender<Result<(), String>>),
    Stop,
}

pub struct AudioRecorder {
    cmd_tx: Sender<Cmd>,
    shared: Arc<Shared>,
}

impl AudioRecorder {
    pub fn new() -> AudioRecorder {
        let shared = Arc::new(Shared {
            buffer: Mutex::new(Vec::new()),
            device_rate: AtomicU32::new(TARGET_RATE),
            recording: AtomicBool::new(false),
            preferred: Mutex::new(None),
        });
        let (cmd_tx, cmd_rx) = channel::<Cmd>();
        let thread_shared = shared.clone();

        std::thread::spawn(move || {
            let host = cpal::default_host();
            // The stream is `!Send`; this binding owns it to keep capture alive.
            // Reassigning to `None` on Stop drops it, which stops capture.
            let mut held_stream: Option<cpal::Stream> = None;
            while let Ok(cmd) = cmd_rx.recv() {
                match cmd {
                    Cmd::Start(reply) => {
                        thread_shared.buffer.lock().clear();
                        match build_stream(&host, &thread_shared) {
                            Ok(s) => {
                                if let Err(e) = s.play() {
                                    let _ = reply.send(Err(format!("stream play failed: {e}")));
                                    continue;
                                }
                                held_stream = Some(s);
                                thread_shared.recording.store(true, Ordering::SeqCst);
                                let _ = reply.send(Ok(()));
                            }
                            Err(e) => {
                                let _ = reply.send(Err(e));
                            }
                        }
                    }
                    Cmd::Stop => {
                        thread_shared.recording.store(false, Ordering::SeqCst);
                        held_stream = None; // dropping the stream stops capture
                    }
                }
            }
            drop(held_stream);
        });

        AudioRecorder { cmd_tx, shared }
    }

    pub fn set_preferred_device(&self, uid: Option<String>) {
        *self.shared.preferred.lock() = uid.filter(|u| u != crate::storage::SYSTEM_DEFAULT_MIC);
    }

    #[allow(dead_code)]
    pub fn is_recording(&self) -> bool {
        self.shared.recording.load(Ordering::SeqCst)
    }

    pub fn start(&self) -> Result<(), String> {
        let (tx, rx) = channel();
        self.cmd_tx
            .send(Cmd::Start(tx))
            .map_err(|_| "audio thread gone".to_string())?;
        rx.recv().map_err(|_| "audio thread gone".to_string())?
    }

    pub fn stop(&self) {
        let _ = self.cmd_tx.send(Cmd::Stop);
    }

    /// Drain the accumulated audio and return it resampled to 16 kHz mono f32.
    pub fn take_16k_mono(&self) -> Vec<f32> {
        let samples = std::mem::take(&mut *self.shared.buffer.lock());
        let rate = self.shared.device_rate.load(Ordering::SeqCst);
        resample_linear(&samples, rate, TARGET_RATE)
    }

    pub fn list_devices() -> Vec<InputDevice> {
        let host = cpal::default_host();
        let mut out = Vec::new();
        if let Ok(devices) = host.input_devices() {
            for d in devices {
                if let Ok(name) = d.name() {
                    out.push(InputDevice {
                        id: name.clone(),
                        name,
                    });
                }
            }
        }
        out
    }
}

fn build_stream(host: &cpal::Host, shared: &Arc<Shared>) -> Result<cpal::Stream, String> {
    let preferred = shared.preferred.lock().clone();
    let device = match preferred {
        Some(name) => host
            .input_devices()
            .map_err(|e| e.to_string())?
            .find(|d| d.name().map(|n| n == name).unwrap_or(false))
            .or_else(|| host.default_input_device())
            .ok_or_else(|| "no input device".to_string())?,
        None => host
            .default_input_device()
            .ok_or_else(|| "no default input device".to_string())?,
    };

    let config = device
        .default_input_config()
        .map_err(|e| format!("no input config: {e}"))?;
    let channels = config.channels() as usize;
    shared
        .device_rate
        .store(config.sample_rate().0, Ordering::SeqCst);

    let err_fn = |e| log::error!("audio stream error: {e}");
    let sample_format = config.sample_format();
    let stream_config: cpal::StreamConfig = config.into();
    let buf = shared.clone();

    let stream = match sample_format {
        cpal::SampleFormat::F32 => device.build_input_stream(
            &stream_config,
            move |data: &[f32], _| push_mono(&buf, data, channels, |s| s),
            err_fn,
            None,
        ),
        cpal::SampleFormat::I16 => device.build_input_stream(
            &stream_config,
            move |data: &[i16], _| push_mono(&buf, data, channels, |s| s as f32 / 32768.0),
            err_fn,
            None,
        ),
        cpal::SampleFormat::U16 => device.build_input_stream(
            &stream_config,
            move |data: &[u16], _| {
                push_mono(&buf, data, channels, |s| (s as f32 - 32768.0) / 32768.0)
            },
            err_fn,
            None,
        ),
        other => return Err(format!("unsupported sample format: {other:?}")),
    }
    .map_err(|e| format!("build stream failed: {e}"))?;

    Ok(stream)
}

fn push_mono<T: Copy>(shared: &Arc<Shared>, data: &[T], channels: usize, conv: impl Fn(T) -> f32) {
    if channels == 0 {
        return;
    }
    let mut buf = shared.buffer.lock();
    buf.reserve(data.len() / channels);
    for frame in data.chunks(channels) {
        let mut acc = 0.0f32;
        for &s in frame {
            acc += conv(s);
        }
        buf.push(acc / channels as f32);
    }
}

/// Linear-interpolation resampler. Whisper is tolerant of the mild aliasing
/// this introduces at integer decimation ratios (e.g. 48k -> 16k); a
/// polyphase/sinc pass is a future quality improvement.
fn resample_linear(input: &[f32], from_rate: u32, to_rate: u32) -> Vec<f32> {
    if input.is_empty() || from_rate == 0 {
        return Vec::new();
    }
    if from_rate == to_rate {
        return input.to_vec();
    }
    let ratio = to_rate as f64 / from_rate as f64;
    let out_len = ((input.len() as f64) * ratio).round() as usize;
    let mut out = Vec::with_capacity(out_len);
    for i in 0..out_len {
        let src_pos = i as f64 / ratio;
        let idx = src_pos.floor() as usize;
        let frac = (src_pos - idx as f64) as f32;
        let a = input[idx.min(input.len() - 1)];
        let b = input[(idx + 1).min(input.len() - 1)];
        out.push(a + (b - a) * frac);
    }
    out
}
