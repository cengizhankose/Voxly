import type { DictationState } from "../lib/types";

export type Section = "history" | "models" | "settings" | "about";

const ICONS: Record<Section, JSX.Element> = {
  history: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M12 8v4l3 2" strokeLinecap="round" />
      <path d="M3.05 11a9 9 0 1 1 .5 4" strokeLinecap="round" />
      <path d="M3 3v5h5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  models: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M12 2 3 7v10l9 5 9-5V7z" strokeLinejoin="round" />
      <path d="M3 7l9 5 9-5M12 12v10" strokeLinejoin="round" />
    </svg>
  ),
  settings: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
    </svg>
  ),
  about: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <circle cx="12" cy="12" r="10" />
      <path d="M12 16v-4M12 8h.01" strokeLinecap="round" />
    </svg>
  ),
};

const LABELS: Record<Section, string> = {
  history: "History",
  models: "Models",
  settings: "Settings",
  about: "About",
};

export function Sidebar({
  section,
  onSelect,
  dictation,
}: {
  section: Section;
  onSelect: (s: Section) => void;
  dictation: DictationState;
}) {
  const sections: Section[] = ["history", "models", "settings", "about"];
  return (
    <nav className="sidebar">
      <div className="sidebar-brand">
        <BrandMark />
        <span className="display">Voxly</span>
      </div>
      {sections.map((s) => (
        <button
          key={s}
          className={`nav-item${section === s ? " active" : ""}`}
          onClick={() => onSelect(s)}
        >
          {ICONS[s]}
          {LABELS[s]}
        </button>
      ))}
      <div className="sidebar-spacer" />
      <div className="sidebar-status kicker">
        {dictation.isRecording ? "● Recording" : dictation.modelReady ? "Ready" : "…"}
      </div>
    </nav>
  );
}

function BrandMark() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
      <rect x="9" y="2" width="6" height="12" rx="3" fill="var(--accent)" />
      <path
        d="M5 11a7 7 0 0 0 14 0M12 18v3"
        stroke="var(--accent)"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  );
}
