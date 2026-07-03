import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type ReactElement,
  type ReactNode,
} from "react";
import { api } from "../lib/ipc";
import {
  LANGUAGES,
  RETENTION_OPTIONS,
  SYSTEM_DEFAULT_MIC,
  type DictationState,
  type InputDevice,
  type PasteMode,
  type PermissionState,
  type Settings,
} from "../lib/types";
import "../styles/settings.css";

type TabId = "general" | "permissions" | "advanced";

const TABS: { id: TabId; label: string; icon: () => ReactElement }[] = [
  { id: "general", label: "General", icon: GearIcon },
  { id: "permissions", label: "Permissions", icon: ShieldIcon },
  { id: "advanced", label: "Advanced", icon: SlidersIcon },
];

const PERMISSION_POLL_MS = 1200;

export function SettingsPage({ dictation }: { dictation: DictationState }) {
  const [tab, setTab] = useState<TabId>("general");
  const [settings, setSettings] = useState<Settings | null>(null);
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    api
      .getSettings()
      .then((s) => {
        if (mounted.current) setSettings(s);
      })
      .catch(() => {});
    return () => {
      mounted.current = false;
    };
  }, []);

  // Persist a single-field change: mutate a copy of the FULL object and send it.
  const patch = useCallback(
    async (next: Partial<Settings>) => {
      setSettings((prev) => {
        if (!prev) return prev;
        const merged = { ...prev, ...next };
        void api.updateSettings(merged).catch(() => {});
        return merged;
      });
    },
    []
  );

  return (
    <>
      <header className="page-header">
        <div className="kicker">Preferences</div>
        <h1 className="display">Settings</h1>
        <p className="subtitle">
          Configure the hotkey, system permissions, and how transcripts land in
          your apps.
        </p>
      </header>

      <div className="settings-tabs" role="tablist" aria-label="Settings sections">
        {TABS.map((t) => {
          const Icon = t.icon;
          const active = tab === t.id;
          return (
            <button
              key={t.id}
              role="tab"
              aria-selected={active}
              className={`settings-tab ${active ? "active" : ""}`}
              onClick={() => setTab(t.id)}
            >
              <Icon />
              {t.label}
            </button>
          );
        })}
      </div>

      {settings === null ? (
        <SettingsSkeleton />
      ) : tab === "general" ? (
        <GeneralTab settings={settings} patch={patch} />
      ) : tab === "permissions" ? (
        <PermissionsTab dictation={dictation} />
      ) : (
        <AdvancedTab settings={settings} patch={patch} />
      )}
    </>
  );
}

// ============================================================ GENERAL

function GeneralTab({
  settings,
  patch,
}: {
  settings: Settings;
  patch: (next: Partial<Settings>) => Promise<void>;
}) {
  const [resetting, setResetting] = useState(false);

  const confirmReset = useCallback(async () => {
    const ok = window.confirm(
      "Reset Voxly's Accessibility permission and quit?\n\n" +
        "Use this if Voxly says “Accessibility not granted” even after " +
        "you've enabled it. This wipes the TCC entry and relaunches the app — " +
        "you'll need to re-add Voxly in System Settings → Accessibility."
    );
    if (!ok) return;
    setResetting(true);
    try {
      await api.resetAccessibility();
    } catch {
      setResetting(false);
    }
  }, []);

  return (
    <>
      <section className="section">
        <div className="kicker section-title">Startup</div>
        <div className="card">
          <div className="row">
            <div className="row-label">
              <span>Launch Voxly at login</span>
              <span className="row-hint">
                Start dictation in the menu bar automatically when you log in.
              </span>
            </div>
            <Switch
              checked={settings.launchAtLogin}
              onChange={(v) => void patch({ launchAtLogin: v })}
              label="Launch Voxly at login"
            />
          </div>
          <div className="row">
            <div className="row-label">
              <span>Show main window when launched</span>
              <span className="row-hint">
                Open this window on launch instead of staying only in the menu bar.
              </span>
            </div>
            <Switch
              checked={settings.showWindowOnLaunch}
              onChange={(v) => void patch({ showWindowOnLaunch: v })}
              label="Show main window when launched"
            />
          </div>
        </div>
      </section>

      <section className="section">
        <div className="kicker section-title">Hotkey</div>
        <div className="card">
          <div className="row">
            <div className="row-label">
              <span>Toggle dictation</span>
              <span className="row-hint">
                Press this shortcut anywhere to start and stop recording.
              </span>
            </div>
            <HotkeyRecorder
              value={settings.hotkey}
              onChange={(hotkey) => void patch({ hotkey })}
            />
          </div>
        </div>
      </section>

      <section className="section">
        <div className="kicker section-title">History</div>
        <div className="card">
          <div className="row">
            <div className="row-label">
              <span>Retention</span>
              <span className="row-hint">
                How long transcripts are kept before they're pruned automatically.
              </span>
            </div>
            <Segmented
              options={RETENTION_OPTIONS.map((o) => ({
                value: o.days,
                label: o.label,
              }))}
              value={settings.historyRetentionDays}
              onChange={(days) => void patch({ historyRetentionDays: days })}
              ariaLabel="History retention"
            />
          </div>
        </div>
      </section>

      <section className="section">
        <div className="kicker section-title">Troubleshooting</div>
        <div className="card">
          <div className="row">
            <div className="row-label">
              <span>Reset Accessibility permission</span>
              <span className="row-hint">
                Use if Voxly says &ldquo;Accessibility not granted&rdquo; even after
                you've enabled it. Wipes the TCC entry and relaunches &mdash; then
                re-add Voxly in System Settings.
              </span>
            </div>
            <button
              className="btn btn-ghost btn-compact settings-danger"
              onClick={() => void confirmReset()}
              disabled={resetting}
            >
              <ResetIcon />
              {resetting ? "Relaunching…" : "Reset & Relaunch"}
            </button>
          </div>
        </div>
      </section>
    </>
  );
}

// ============================================================ PERMISSIONS

function PermissionsTab({ dictation }: { dictation: DictationState }) {
  // Seed from live dictation flags, then keep fresh with a light poll so the
  // status reflects grants made in System Settings without a relaunch.
  const [perms, setPerms] = useState<PermissionState>({
    micGranted: dictation.micGranted,
    accessibilityGranted: dictation.accessibilityGranted,
  });
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    const poll = () => {
      api
        .checkPermissions()
        .then((p) => {
          if (mounted.current) setPerms(p);
        })
        .catch(() => {});
    };
    poll();
    const id = window.setInterval(poll, PERMISSION_POLL_MS);
    return () => {
      mounted.current = false;
      window.clearInterval(id);
    };
  }, []);

  // Prefer the freshest signal: OR the poll result with live event flags.
  const micGranted = perms.micGranted || dictation.micGranted;
  const accessibilityGranted =
    perms.accessibilityGranted || dictation.accessibilityGranted;

  const grantMic = useCallback(() => {
    void api.requestMicrophone().catch(() => {});
  }, []);
  const grantAccessibility = useCallback(() => {
    void api.requestAccessibility().catch(() => {});
  }, []);

  return (
    <section className="section">
      <div className="kicker section-title">System access</div>
      <div className="card">
        <PermissionRow
          icon={<MicIcon />}
          label="Microphone"
          hint="Required to capture audio while you dictate."
          granted={micGranted}
          onGrant={grantMic}
        />
        <PermissionRow
          icon={<AccessibilityIcon />}
          label="Accessibility"
          hint="Lets Voxly paste the transcript into the active app via a synthesized ⌘V."
          granted={accessibilityGranted}
          onGrant={grantAccessibility}
        />
      </div>

      {!accessibilityGranted && (
        <div className="settings-note" style={{ alignItems: "center" }}>
          <InfoIcon />
          <p style={{ flex: 1 }}>
            Enabled Voxly under Accessibility but it still shows “Grant”? macOS
            only applies the permission after the app relaunches.
          </p>
          <button
            className="btn btn-ghost btn-compact"
            style={{ flexShrink: 0 }}
            onClick={() => void api.relaunchApp()}
          >
            Quit &amp; Reopen
          </button>
        </div>
      )}

      <div className="settings-note">
        <InfoIcon />
        <p>
          Microphone is required to record. Accessibility lets Voxly paste the
          transcript into the active app via a synthesized <Kbd>&#8984;</Kbd>
          <Kbd>V</Kbd>; without it, text is copied to the clipboard only.
        </p>
      </div>
    </section>
  );
}

function PermissionRow({
  icon,
  label,
  hint,
  granted,
  onGrant,
}: {
  icon: ReactElement;
  label: string;
  hint: string;
  granted: boolean;
  onGrant: () => void;
}) {
  return (
    <div className="row perm-row">
      <div className="perm-lead">
        <span className={`perm-icon ${granted ? "is-granted" : ""}`}>{icon}</span>
        <div className="row-label">
          <span>{label}</span>
          <span className="row-hint">{hint}</span>
        </div>
      </div>
      {granted ? (
        <span className="perm-status">
          <CheckIcon />
          Granted
        </span>
      ) : (
        <button className="btn btn-primary btn-compact" onClick={onGrant}>
          Grant
        </button>
      )}
    </div>
  );
}

// ============================================================ ADVANCED

const PASTE_MODES: { value: PasteMode; label: string; hint: string }[] = [
  {
    value: "paste",
    label: "Auto-paste",
    hint: "Insert the transcript into the active app.",
  },
  {
    value: "clipboard",
    label: "Clipboard only",
    hint: "Copy the transcript; paste it yourself.",
  },
  {
    value: "both",
    label: "Paste & copy",
    hint: "Insert and also leave a copy on the clipboard.",
  },
];

function AdvancedTab({
  settings,
  patch,
}: {
  settings: Settings;
  patch: (next: Partial<Settings>) => Promise<void>;
}) {
  const [devices, setDevices] = useState<InputDevice[]>([]);
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    api
      .listInputDevices()
      .then((list) => {
        if (mounted.current) setDevices(list);
      })
      .catch(() => {});
    return () => {
      mounted.current = false;
    };
  }, []);

  return (
    <>
      <section className="section">
        <div className="kicker section-title">Output</div>
        <div className="card">
          <div className="row settings-row-stacked">
            <div className="row-label">
              <span>Paste mode</span>
              <span className="row-hint">
                {PASTE_MODES.find((m) => m.value === settings.pasteMode)?.hint}{" "}
                Voxly falls back to the clipboard if Accessibility isn't granted.
              </span>
            </div>
            <Segmented
              options={PASTE_MODES.map((m) => ({
                value: m.value,
                label: m.label,
              }))}
              value={settings.pasteMode}
              onChange={(v) => void patch({ pasteMode: v })}
              ariaLabel="Paste mode"
            />
          </div>
        </div>
      </section>

      <section className="section">
        <div className="kicker section-title">Recognition</div>
        <div className="card">
          <div className="row">
            <div className="row-label">
              <span>Language</span>
              <span className="row-hint">
                Auto-detect works well for most speech. Pick a language to force
                it when detection struggles.
              </span>
            </div>
            <div className="settings-select">
              <select
                value={settings.languageOverride}
                onChange={(e) => void patch({ languageOverride: e.target.value })}
                aria-label="Recognition language"
              >
                {LANGUAGES.map((l) => (
                  <option key={l.code} value={l.code}>
                    {l.label}
                  </option>
                ))}
              </select>
              <ChevronIcon />
            </div>
          </div>
        </div>
      </section>

      <section className="section">
        <div className="kicker section-title">Input</div>
        <div className="card">
          <div className="row">
            <div className="row-label">
              <span>Microphone</span>
              <span className="row-hint">
                Applies to the next recording. &ldquo;System Default&rdquo; follows
                your macOS Sound settings.
              </span>
            </div>
            <div className="settings-select">
              <select
                value={settings.selectedInputDeviceUid}
                onChange={(e) =>
                  void patch({ selectedInputDeviceUid: e.target.value })
                }
                aria-label="Microphone input device"
              >
                <option value={SYSTEM_DEFAULT_MIC}>System Default</option>
                {devices.map((d) => (
                  <option key={d.id} value={d.id}>
                    {d.name}
                  </option>
                ))}
              </select>
              <ChevronIcon />
            </div>
          </div>
        </div>
      </section>
    </>
  );
}

// ============================================================ SWITCH

function Switch({
  checked,
  onChange,
  label,
}: {
  checked: boolean;
  onChange: (value: boolean) => void;
  label: string;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      className={`switch ${checked ? "on" : ""}`}
      onClick={() => onChange(!checked)}
    >
      <span className="switch-thumb" />
    </button>
  );
}

// ============================================================ SEGMENTED

function Segmented<T extends string | number>({
  options,
  value,
  onChange,
  ariaLabel,
}: {
  options: { value: T; label: string }[];
  value: T;
  onChange: (value: T) => void;
  ariaLabel: string;
}) {
  return (
    <div className="segmented" role="radiogroup" aria-label={ariaLabel}>
      {options.map((o) => {
        const active = o.value === value;
        return (
          <button
            key={String(o.value)}
            type="button"
            role="radio"
            aria-checked={active}
            className={`segmented-item ${active ? "active" : ""}`}
            onClick={() => onChange(o.value)}
          >
            {o.label}
          </button>
        );
      })}
    </div>
  );
}

// ============================================================ HOTKEY RECORDER

// Modifier order for both accelerator strings and keycap rendering.
const MOD_KEYCAP: Record<string, string> = {
  CmdOrCtrl: "⌘", // ⌘
  Alt: "⌥", // ⌥
  Ctrl: "⌃", // ⌃
  Shift: "⇧", // ⇧
};
// macOS reading order for keycaps: ⌃ ⌥ ⇧ ⌘
const KEYCAP_ORDER = ["Ctrl", "Alt", "Shift", "CmdOrCtrl"];
// Accelerator string order (mirrors Tauri examples: CmdOrCtrl+Shift+Key).
const ACCEL_ORDER = ["CmdOrCtrl", "Ctrl", "Alt", "Shift"];

// Turn a KeyboardEvent.code/key into the token Tauri expects for the main key.
function normalizeKey(e: KeyboardEvent): string | null {
  const code = e.code;
  if (code.startsWith("Key")) return code.slice(3); // KeyD -> D
  if (code.startsWith("Digit")) return code.slice(5); // Digit1 -> 1
  if (code.startsWith("Numpad")) {
    const n = code.slice(6);
    if (/^\d$/.test(n)) return `Num${n}`;
  }
  const map: Record<string, string> = {
    Space: "Space",
    Enter: "Enter",
    Escape: "Escape",
    Tab: "Tab",
    Backspace: "Backspace",
    Delete: "Delete",
    ArrowUp: "Up",
    ArrowDown: "Down",
    ArrowLeft: "Left",
    ArrowRight: "Right",
    Comma: ",",
    Period: ".",
    Slash: "/",
    Semicolon: ";",
    Quote: "'",
    BracketLeft: "[",
    BracketRight: "]",
    Backslash: "\\",
    Minus: "-",
    Equal: "=",
    Backquote: "`",
  };
  if (map[code]) return map[code];
  if (/^F\d{1,2}$/.test(code)) return code; // F1..F12
  return null;
}

// Parse a stored accelerator ("Alt+D") into { mods, key } for keycap rendering.
function parseAccelerator(accel: string): { mods: string[]; key: string | null } {
  if (!accel) return { mods: [], key: null };
  const parts = accel.split("+");
  const mods: string[] = [];
  let key: string | null = null;
  for (const p of parts) {
    if (p === "CmdOrCtrl" || p === "Cmd" || p === "Command" || p === "Super")
      mods.push("CmdOrCtrl");
    else if (p === "Ctrl" || p === "Control") mods.push("Ctrl");
    else if (p === "Alt" || p === "Option") mods.push("Alt");
    else if (p === "Shift") mods.push("Shift");
    else key = p;
  }
  return { mods, key };
}

// Human-readable key label for the keycap (Space stays "Space", letters uppercase).
function keyLabel(key: string): string {
  if (key.length === 1) return key.toUpperCase();
  return key;
}

function HotkeyRecorder({
  value,
  onChange,
}: {
  value: string;
  onChange: (accel: string) => void;
}) {
  const [recording, setRecording] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const btnRef = useRef<HTMLButtonElement>(null);

  const stop = useCallback(() => {
    setRecording(false);
    btnRef.current?.blur();
  }, []);

  useEffect(() => {
    if (!recording) return;

    const onKeyDown = (e: KeyboardEvent) => {
      e.preventDefault();
      e.stopPropagation();

      if (e.key === "Escape") {
        setError(null);
        stop();
        return;
      }

      // Ignore lone modifier presses — wait for a real key.
      if (["Shift", "Alt", "Control", "Meta"].includes(e.key)) return;

      const key = normalizeKey(e);
      if (!key) {
        setError("Unsupported key");
        return;
      }

      const mods: string[] = [];
      if (e.metaKey) mods.push("CmdOrCtrl");
      if (e.ctrlKey) mods.push("Ctrl");
      if (e.altKey) mods.push("Alt");
      if (e.shiftKey) mods.push("Shift");

      if (mods.length === 0) {
        setError("Add at least one modifier (⌘ ⌥ ⌃ ⇧)");
        return;
      }

      const ordered = ACCEL_ORDER.filter((m) => mods.includes(m));
      const accel = [...ordered, key].join("+");
      setError(null);
      onChange(accel);
      stop();
    };

    window.addEventListener("keydown", onKeyDown, true);
    return () => window.removeEventListener("keydown", onKeyDown, true);
  }, [recording, onChange, stop]);

  const { mods, key } = parseAccelerator(value);
  const capMods = KEYCAP_ORDER.filter((m) => mods.includes(m));

  return (
    <div className="hotkey-wrap">
      <button
        ref={btnRef}
        type="button"
        className={`hotkey-recorder ${recording ? "recording" : ""}`}
        onClick={() => {
          setError(null);
          setRecording(true);
        }}
        onBlur={stop}
        aria-label="Record dictation hotkey"
      >
        {recording ? (
          <span className="hotkey-listening">
            <span className="hotkey-pulse" />
            Press keys&hellip;
          </span>
        ) : key ? (
          <span className="keycaps">
            {capMods.map((m) => (
              <kbd key={m} className="keycap">
                {MOD_KEYCAP[m]}
              </kbd>
            ))}
            <kbd className="keycap">{keyLabel(key)}</kbd>
          </span>
        ) : (
          <span className="hotkey-empty">Click to set</span>
        )}
      </button>
      {error && <span className="hotkey-error">{error}</span>}
    </div>
  );
}

// ============================================================ SKELETON

function SettingsSkeleton() {
  return (
    <div className="settings-skeleton" aria-busy="true" aria-live="polite">
      {[0, 1, 2].map((i) => (
        <div key={i} className="settings-skeleton-card">
          <div className="skeleton-line" />
          <div className="skeleton-line short" />
        </div>
      ))}
    </div>
  );
}

// ============================================================ Kbd / small bits

function Kbd({ children }: { children: ReactNode }) {
  return <kbd className="inline-kbd">{children}</kbd>;
}

// ============================================================ ICONS (inline SVG)

function GearIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1Z" />
    </svg>
  );
}

function ShieldIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 3 5 6v5c0 4.5 3 7.7 7 9 4-1.3 7-4.5 7-9V6Z" />
      <path d="m9 12 2 2 4-4" />
    </svg>
  );
}

function SlidersIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 6h10M18 6h2M4 12h2M10 12h10M4 18h8M16 18h4" />
      <circle cx="16" cy="6" r="2" />
      <circle cx="8" cy="12" r="2" />
      <circle cx="14" cy="18" r="2" />
    </svg>
  );
}

function MicIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <rect x="9" y="3" width="6" height="11" rx="3" />
      <path d="M6 11a6 6 0 0 0 12 0" />
      <path d="M12 17v4M9 21h6" />
    </svg>
  );
}

function AccessibilityIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="4.5" r="1.6" />
      <path d="M4.5 8.5c2.4.9 5 1.4 7.5 1.4s5.1-.5 7.5-1.4" />
      <path d="M12 9.9V15" />
      <path d="m9 21 3-6 3 6" />
    </svg>
  );
}

function CheckIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="m5 12 4.5 4.5L19 7" />
    </svg>
  );
}

function ResetIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3.5 12a8.5 8.5 0 1 1 2.5 6" />
      <path d="M3 20v-5h5" />
    </svg>
  );
}

function ChevronIcon() {
  return (
    <svg className="select-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="m6 9 6 6 6-6" />
    </svg>
  );
}

function InfoIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="9" />
      <path d="M12 11v5M12 8h.01" />
    </svg>
  );
}
