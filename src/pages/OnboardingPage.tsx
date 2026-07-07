import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { api, events } from "../lib/ipc";
import type { PermissionState, Settings } from "../lib/types";
import "../styles/onboarding.css";

// ---- Wizard steps ----
type Step = "welcome" | "microphone" | "accessibility" | "ready" | "done";
const STEPS: Step[] = ["welcome", "microphone", "accessibility", "ready", "done"];

// Rail metadata — label + short caption shown in the left progress rail.
const RAIL_META: Record<Step, { label: string; caption: string }> = {
  welcome: { label: "Welcome", caption: "What Voxly does" },
  microphone: { label: "Microphone", caption: "Hear your voice" },
  accessibility: { label: "Auto-paste", caption: "Place the text" },
  ready: { label: "Hotkey test", caption: "Try it live" },
  done: { label: "Finish", caption: "Start dictating" },
};

// ---- Inline icon set (stroke = currentColor) ----
type IconProps = { className?: string };

function WaveIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor"
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M3 12h2M7 8v8M11 4v16M15 7v10M19 10v4M21 12h0" />
    </svg>
  );
}
function MicIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor"
      strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <rect x="9" y="2" width="6" height="12" rx="3" />
      <path d="M5 11a7 7 0 0 0 14 0M12 18v4M8 22h8" />
    </svg>
  );
}
function TapIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor"
      strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M9 11V5.5a1.5 1.5 0 0 1 3 0V11" />
      <path d="M12 11V7.5a1.5 1.5 0 0 1 3 0V12" />
      <path d="M15 12v-1a1.5 1.5 0 0 1 3 0v5a5 5 0 0 1-5 5h-2.5a4 4 0 0 1-3.3-1.75L5 17.5a1.6 1.6 0 0 1 2.5-2L9 17V8a1.5 1.5 0 0 1 3 0" />
    </svg>
  );
}
function KeyIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor"
      strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <rect x="2" y="5" width="20" height="14" rx="2.5" />
      <path d="M6 9h.01M10 9h.01M14 9h.01M18 9h.01M7 13h10" />
    </svg>
  );
}
function CheckIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor"
      strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M20 6 9 17l-5-5" />
    </svg>
  );
}
function SealIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor"
      strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M12 2 15 5l4-.5L18.5 8.5 22 12l-3.5 3.5L19 20l-4-.5L12 22l-3-2.5L5 20l.5-4.5L2 12l3.5-3.5L5 4.5 9 5z" />
      <path d="M8.5 12.5 11 15l4.5-5" strokeWidth="2" />
    </svg>
  );
}
function ArrowIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor"
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M5 12h14M13 6l6 6-6 6" />
    </svg>
  );
}
function DotIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor"
      strokeWidth="2" strokeLinecap="round" aria-hidden="true">
      <path d="M12 6v6M12 16h.01" />
      <circle cx="12" cy="12" r="9" strokeWidth="1.6" />
    </svg>
  );
}
function SpinIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor"
      strokeWidth="2.2" strokeLinecap="round" aria-hidden="true">
      <path d="M12 3a9 9 0 1 0 9 9" />
    </svg>
  );
}
function ShieldIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor"
      strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M12 3 5 6v5c0 4.4 3 8.3 7 9.5 4-1.2 7-5.1 7-9.5V6l-7-3z" />
      <path d="M9 12l2 2 4-4" strokeWidth="2" />
    </svg>
  );
}

// ---- Hotkey rendering: "Alt+D" -> mac glyphs ----
const MAC_GLYPH: Record<string, string> = {
  alt: "⌥", // ⌥ Option
  option: "⌥",
  cmd: "⌘",
  command: "⌘",
  meta: "⌘",
  ctrl: "⌃",
  control: "⌃",
  shift: "⇧",
};

function parseHotkey(hotkey: string): string[] {
  return hotkey
    .split("+")
    .map((raw) => {
      const token = raw.trim();
      const glyph = MAC_GLYPH[token.toLowerCase()];
      return glyph ?? token.toUpperCase();
    })
    .filter((t) => t.length > 0);
}

// ---- Live status pill ----
type PillTone = "ok" | "warn" | "idle";
function StatusPill({ tone, label, busy }: { tone: PillTone; label: string; busy?: boolean }) {
  const cls = tone === "ok" ? "onb-status ok" : tone === "warn" ? "onb-status warn" : "onb-status";
  return (
    <span className={cls} role="status">
      {busy ? <SpinIcon className="spin" /> : tone === "ok" ? <CheckIcon /> : <DotIcon />}
      {label}
    </span>
  );
}

export function OnboardingPage({ onDone }: { onDone: () => void }) {
  const [step, setStep] = useState<Step>("welcome");
  const [perms, setPerms] = useState<PermissionState>({ micGranted: false, accessibilityGranted: false });
  const [settings, setSettings] = useState<Settings | null>(null);
  const [modelReady, setModelReady] = useState(false);
  const [micBusy, setMicBusy] = useState(false);
  const [axBusy, setAxBusy] = useState(false);
  const [hotkeyFired, setHotkeyFired] = useState(false);
  const [finishing, setFinishing] = useState(false);

  const stepIndex = STEPS.indexOf(step);

  // Seed settings + initial model readiness.
  useEffect(() => {
    api.getSettings().then(setSettings).catch(() => {});
    api.getState().then((s) => setModelReady(s.modelReady)).catch(() => {});
    // Resume at the Accessibility step after a relaunch-to-apply: mic is
    // already granted from before the restart, Accessibility is what's pending.
    api
      .checkPermissions()
      .then((p) => {
        if (p.micGranted && !p.accessibilityGranted) setStep("accessibility");
      })
      .catch(() => {});
  }, []);

  // Poll permission status so grants made in System Settings reflect live.
  useEffect(() => {
    let alive = true;
    const tick = () =>
      api.checkPermissions().then((p) => {
        if (alive) setPerms(p);
      }).catch(() => {});
    tick();
    const id = window.setInterval(tick, 1200);
    return () => {
      alive = false;
      window.clearInterval(id);
    };
  }, []);

  // Detect the hotkey firing: dictation-state flips isRecording when it's pressed.
  useEffect(() => {
    let unlisten: (() => void) | undefined;
    let first = true;
    events
      .onDictationState((s) => {
        // Skip the initial replay; react to real recording transitions only.
        if (first) {
          first = false;
          return;
        }
        if (s.isRecording || s.isTranscribing) setHotkeyFired(true);
        if (s.modelReady) setModelReady(true);
      })
      .then((u) => (unlisten = u));
    return () => unlisten?.();
  }, []);

  const requestMic = useCallback(async () => {
    setMicBusy(true);
    try {
      const granted = await api.requestMicrophone();
      const next = await api.checkPermissions();
      setPerms(granted ? { ...next, micGranted: true } : next);
    } catch {
      /* status keeps polling */
    } finally {
      setMicBusy(false);
    }
  }, []);

  const requestAx = useCallback(async () => {
    setAxBusy(true);
    try {
      const granted = await api.requestAccessibility();
      const next = await api.checkPermissions();
      setPerms(granted ? { ...next, accessibilityGranted: true } : next);
    } catch {
      /* status keeps polling */
    } finally {
      setAxBusy(false);
    }
  }, []);

  // macOS only applies a fresh Accessibility grant after a relaunch. This quits
  // and reopens the app; on next launch the grant is detected and onboarding
  // resumes at the Accessibility step (mic already granted).
  const relaunch = useCallback(() => {
    void api.relaunchApp();
  }, []);

  const hotkeyGlyphs = useMemo(() => parseHotkey(settings?.hotkey ?? "Alt+D"), [settings]);

  // Latest onDone in a ref so the finish handler stays stable.
  const onDoneRef = useRef(onDone);
  onDoneRef.current = onDone;

  const finish = useCallback(async () => {
    if (finishing) return;
    setFinishing(true);
    try {
      await api.completeOnboarding();
    } catch {
      /* proceed regardless — backend records completion best-effort */
    }
    onDoneRef.current();
  }, [finishing]);

  const goNext = useCallback(() => {
    if (step === "done") {
      void finish();
      return;
    }
    const i = STEPS.indexOf(step);
    if (i < STEPS.length - 1) setStep(STEPS[i + 1]);
  }, [step, finish]);

  const goBack = useCallback(() => {
    const i = STEPS.indexOf(step);
    if (i > 0) setStep(STEPS[i - 1]);
  }, [step]);

  // Keyboard: Enter advances (when allowed), Escape/Backspace go back.
  const canAdvance = useMemo(() => {
    switch (step) {
      case "microphone":
        return perms.micGranted;
      case "accessibility":
        return perms.accessibilityGranted;
      default:
        return true;
    }
  }, [step, perms]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Enter" && canAdvance && !finishing) {
        e.preventDefault();
        goNext();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [canAdvance, finishing, goNext]);

  const nextLabel = step === "ready" ? "Finish setup" : step === "done" ? "Start dictating" : "Continue";

  return (
    <div className="onb">
      {/* ---- Left rail: brand + vertical progress + privacy seal ---- */}
      <aside className="onb-rail" aria-hidden="false">
        <div className="onb-brand">
          <span className="onb-mark"><WaveIcon /></span>
          <span className="onb-brand-text">
            <span className="display">Voxly</span>
            <span className="kicker">Local speech-to-text</span>
          </span>
        </div>

        <ol className="onb-track" aria-label="Setup progress">
          {STEPS.map((s, i) => {
            const state = i < stepIndex ? "done" : i === stepIndex ? "active" : "todo";
            const meta = RAIL_META[s];
            return (
              <li key={s} className={`onb-node ${state}`} aria-current={state === "active" ? "step" : undefined}>
                <span className="onb-node-disc">
                  {state === "done" ? <CheckIcon /> : <span className="onb-node-num">{i + 1}</span>}
                </span>
                <span className="onb-node-text">
                  <span className="onb-node-label">{meta.label}</span>
                  <span className="onb-node-caption">{meta.caption}</span>
                </span>
              </li>
            );
          })}
        </ol>

        <div className="onb-privacy">
          <span className="onb-privacy-ico"><ShieldIcon /></span>
          <span className="onb-privacy-text">
            Everything runs on this Mac. Your voice never leaves the device.
          </span>
        </div>
      </aside>

      {/* ---- Right stage: the active step ---- */}
      <section className="onb-stage">
        <div className="onb-stage-scroll">
          <div className="onb-body" key={step}>
            {step === "welcome" && <WelcomeStep glyphs={hotkeyGlyphs} />}

            {step === "microphone" && (
              <PermissionStep
                icon={<MicIcon />}
                granted={perms.micGranted}
                kicker="Permission 1 of 2"
                title="Enable your microphone"
                lede={
                  <>
                    Voxly listens only while you dictate, transcribes it{" "}
                    <strong>entirely on this Mac</strong>, and never sends your voice anywhere.
                  </>
                }
                grantLabel="Grant microphone access"
                grantedLabel="Microphone ready"
                pendingLabel="Awaiting permission"
                busy={micBusy}
                onGrant={requestMic}
              />
            )}

            {step === "accessibility" && (
              <PermissionStep
                icon={<TapIcon />}
                granted={perms.accessibilityGranted}
                kicker="Permission 2 of 2 · Optional"
                title="Allow auto-paste"
                lede={
                  <>
                    Accessibility lets Voxly paste your transcript straight into the focused app via a
                    synthesized <strong>Cmd+V</strong>.
                  </>
                }
                grantLabel="Grant accessibility access"
                grantedLabel="Accessibility granted"
                pendingLabel="Enable Voxly in System Settings"
                busy={axBusy}
                onGrant={requestAx}
                onRelaunch={relaunch}
                relaunchLabel="Enabled it? Quit & Reopen to apply"
                note={
                  <>
                    macOS only applies this after a relaunch. Enable Voxly under System
                    Settings → Privacy &amp; Security → Accessibility, then use{" "}
                    <strong>Quit &amp; Reopen</strong>. Optional — without it, transcripts
                    are copied to your <strong>clipboard</strong> to paste manually.
                  </>
                }
              />
            )}

            {step === "ready" && (
              <ReadyStep
                glyphs={hotkeyGlyphs}
                hotkeyFired={hotkeyFired}
                micGranted={perms.micGranted}
                axGranted={perms.accessibilityGranted}
                modelReady={modelReady}
              />
            )}

            {step === "done" && <DoneStep glyphs={hotkeyGlyphs} />}
          </div>
        </div>

        {/* ---- Footer controls ---- */}
        <footer className="onb-foot">
          <span className="onb-foot-count">
            Step {stepIndex + 1} <span className="muted">/ {STEPS.length}</span>
          </span>
          <div className="onb-foot-actions">
            {(step === "microphone" || step === "accessibility") && !canAdvance && (
              <button className="onb-skip" onClick={goNext}>
                {step === "accessibility" ? "Skip — use clipboard" : "Skip for now"}
              </button>
            )}
            {stepIndex > 0 && (
              <button className="btn btn-ghost" onClick={goBack} disabled={finishing}>
                Back
              </button>
            )}
            <button
              className="btn btn-primary"
              onClick={goNext}
              disabled={!canAdvance || finishing}
            >
              {finishing ? <SpinIcon className="spin" /> : null}
              {finishing ? "Finishing…" : nextLabel}
              {!finishing && step !== "done" && <ArrowIcon />}
            </button>
          </div>
        </footer>
      </section>
    </div>
  );
}

// ---- Step: Welcome ----
function WelcomeStep({ glyphs }: { glyphs: string[] }) {
  return (
    <div className="onb-step">
      <span className="onb-eyebrow kicker">Welcome</span>
      <div className="onb-disc onb-disc-hero"><WaveIcon /></div>
      <h1 className="display onb-title">Dictate anywhere,<br />privately.</h1>
      <p className="onb-lede">
        Press <KeyCombo glyphs={glyphs} /> anywhere on your Mac and start talking. Voxly
        transcribes on-device — <strong>your voice never leaves the machine</strong>.
      </p>
      <ul className="onb-highlights" role="list">
        <li><span className="onb-hl-ico"><CheckIcon /></span>Two quick permissions, about a minute</li>
        <li><span className="onb-hl-ico"><CheckIcon /></span>No account, no cloud, no telemetry</li>
        <li><span className="onb-hl-ico"><CheckIcon /></span>Lives quietly in your menu bar</li>
      </ul>
    </div>
  );
}

// ---- Step: generic permission ----
function PermissionStep(props: {
  icon: ReactNode;
  granted: boolean;
  kicker: string;
  title: string;
  lede: ReactNode;
  grantLabel: string;
  grantedLabel: string;
  pendingLabel: string;
  busy: boolean;
  onGrant: () => void;
  onRelaunch?: () => void;
  relaunchLabel?: string;
  note?: ReactNode;
}) {
  const {
    icon,
    granted,
    kicker,
    title,
    lede,
    grantLabel,
    grantedLabel,
    pendingLabel,
    busy,
    onGrant,
    onRelaunch,
    relaunchLabel,
    note,
  } = props;
  return (
    <div className="onb-step">
      <span className="onb-eyebrow kicker">{kicker}</span>
      <div className={`onb-disc${granted ? " is-granted" : " pending"}`}>
        {granted ? <CheckIcon /> : icon}
      </div>
      <h1 className="display onb-title">{title}</h1>
      <p className="onb-lede">{lede}</p>
      <div className="onb-action">
        {granted ? (
          <StatusPill tone="ok" label={grantedLabel} />
        ) : (
          <>
            <button className="btn btn-primary" onClick={onGrant} disabled={busy}>
              {busy ? <SpinIcon className="spin" /> : null}
              {busy ? "Requesting…" : grantLabel}
            </button>
            <StatusPill tone="warn" label={pendingLabel} busy={busy} />
          </>
        )}
      </div>
      {!granted && onRelaunch && (
        <button className="btn btn-ghost btn-compact onb-relaunch" onClick={onRelaunch}>
          {relaunchLabel ?? "Quit & Reopen"}
        </button>
      )}
      {note && <p className="onb-note">{note}</p>}
    </div>
  );
}

// ---- Step: Ready (hotkey test + readiness checklist) ----
function ReadyStep(props: {
  glyphs: string[];
  hotkeyFired: boolean;
  micGranted: boolean;
  axGranted: boolean;
  modelReady: boolean;
}) {
  const { glyphs, hotkeyFired, micGranted, axGranted, modelReady } = props;
  return (
    <div className="onb-step">
      <span className="onb-eyebrow kicker">Live test</span>
      <div className={`onb-disc${hotkeyFired ? " is-granted" : " pending"}`}>
        {hotkeyFired ? <CheckIcon /> : <KeyIcon />}
      </div>
      <h1 className="display onb-title">Try your hotkey</h1>
      <p className="onb-lede">
        Press <KeyCombo glyphs={glyphs} fired={hotkeyFired} /> now to confirm it works — start and
        stop dictation with the same keys. You can rebind it later in Settings.
      </p>
      <div className="onb-action">
        <StatusPill
          tone={hotkeyFired ? "ok" : "idle"}
          label={hotkeyFired ? "Hotkey detected" : "Waiting for your hotkey…"}
        />
      </div>

      <div className="onb-ready" role="list">
        <ReadyRow
          ok={micGranted}
          name="Microphone"
          hint={micGranted ? "Ready to capture your voice" : "Not granted — dictation needs this"}
        />
        <ReadyRow
          ok={axGranted}
          warnOnly
          name="Auto-paste"
          hint={axGranted ? "Transcripts paste automatically" : "Clipboard-only until enabled"}
        />
        <ReadyRow
          ok={modelReady}
          name="Speech model"
          hint={modelReady ? "Loaded and ready on-device" : "Preparing — this can take a moment"}
        />
      </div>
    </div>
  );
}

function ReadyRow({
  ok,
  name,
  hint,
  warnOnly,
}: {
  ok: boolean;
  name: string;
  hint: string;
  warnOnly?: boolean;
}) {
  const iconCls = ok ? "onb-ready-ico ok" : warnOnly ? "onb-ready-ico warn" : "onb-ready-ico";
  return (
    <div className="onb-ready-row" role="listitem">
      <span className={iconCls}>{ok ? <CheckIcon /> : <DotIcon />}</span>
      <span className="onb-ready-text">
        <span className="onb-ready-name">{name}</span>
        <span className="onb-ready-hint">{hint}</span>
      </span>
      <span className={`onb-ready-tag${ok ? " ok" : warnOnly ? " warn" : ""}`}>
        {ok ? "Ready" : warnOnly ? "Optional" : "Pending"}
      </span>
    </div>
  );
}

// ---- Step: Done ----
function DoneStep({ glyphs }: { glyphs: string[] }) {
  return (
    <div className="onb-step">
      <span className="onb-eyebrow kicker">Setup complete</span>
      <div className="onb-seal"><SealIcon /></div>
      <h1 className="display onb-title">You're all set</h1>
      <p className="onb-lede">
        Press <KeyCombo glyphs={glyphs} /> anywhere to dictate. Voxly lives quietly in your menu
        bar — open this window again any time from there.
      </p>
    </div>
  );
}

// ---- Keycap combo ----
function KeyCombo({ glyphs, fired }: { glyphs: string[]; fired?: boolean }) {
  return (
    <span className={`onb-keys${fired ? " fired" : ""}`}>
      {glyphs.map((g, i) => (
        <span key={`${g}-${i}`} className="onb-keys-seg">
          {i > 0 && <span className="plus">+</span>}
          <kbd className="kbd">{g}</kbd>
        </span>
      ))}
    </span>
  );
}
