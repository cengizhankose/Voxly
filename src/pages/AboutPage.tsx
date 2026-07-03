import { openUrl } from "@tauri-apps/plugin-opener";
import type { DictationState } from "../lib/types";
import "../styles/about.css";

// ---- Static content ----

interface MetaRow {
  label: string;
  value: string;
}

interface AckItem {
  name: string;
  detail: string;
}

interface LinkItem {
  title: string;
  url: string;
}

const ACKNOWLEDGEMENTS: AckItem[] = [
  { name: "whisper.cpp", detail: "Georgi Gerganov — local Whisper inference (MIT)" },
  { name: "ggml", detail: "ML tensor library used by whisper.cpp (MIT)" },
  { name: "Tauri", detail: "Rust + system webview application framework (MIT / Apache-2.0)" },
  { name: "Apple Accelerate / Metal", detail: "vDSP + GPU kernels for on-device inference" },
];

const LINKS: LinkItem[] = [
  { title: "Source on GitHub", url: "https://github.com/cengizhankose/Voxly" },
  { title: "whisper.cpp", url: "https://github.com/ggerganov/whisper.cpp" },
  { title: "Report an issue", url: "https://github.com/cengizhankose/Voxly/issues" },
];

// ---- Icons (inline SVG) ----

/** Rose microphone glyph — echoes the sidebar BrandMark motif at hero scale. */
function BrandMark() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <rect x="9" y="2" width="6" height="12" rx="3" fill="var(--accent)" />
      <path
        d="M5 11a7 7 0 0 0 14 0M12 18v3M9 21h6"
        stroke="var(--accent)"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  );
}

function ExternalIcon() {
  return (
    <svg
      className="about-link-icon"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M14 4h6v6M20 4l-9 9" />
      <path d="M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5" />
    </svg>
  );
}

// ---- Page ----

export function AboutPage({ dictation }: { dictation: DictationState }) {
  const model = dictation.currentModel.trim();
  const activeModel = model ? `ggml-${model}.bin` : "—";

  const metaRows: MetaRow[] = [
    { label: "Version", value: "1.0.0 (1)" },
    { label: "Active model", value: activeModel },
    { label: "whisper.cpp", value: "v1.8.1" },
    { label: "Platform", value: "macOS" },
    { label: "Architecture", value: "arm64 (Apple Silicon)" },
  ];

  const openExternal = (url: string) => {
    void openUrl(url);
  };

  return (
    <div className="about">
      {/* Identity */}
      <section className="about-band about-identity">
        <span className="about-mark">
          <BrandMark />
        </span>
        <h1 className="display about-wordmark">Voxly</h1>
        <p className="mono about-tagline">Local speech-to-text via whisper.cpp</p>
      </section>

      {/* Meta */}
      <section className="about-band about-meta" aria-label="Build details">
        {metaRows.map((row) => (
          <div className="about-meta-row" key={row.label}>
            <span className="about-meta-label">{row.label}</span>
            <span className="about-meta-value">{row.value}</span>
          </div>
        ))}
      </section>

      {/* Acknowledgements */}
      <section className="about-band about-ack">
        <hr className="about-divider" />
        <h2 className="display about-section-title">Built with</h2>
        <ul className="about-ack-list">
          {ACKNOWLEDGEMENTS.map((ack) => (
            <li className="about-ack-item" key={ack.name}>
              <span className="about-ack-name">{ack.name}</span>
              <span className="about-ack-detail">{ack.detail}</span>
            </li>
          ))}
        </ul>
      </section>

      {/* Links + license */}
      <section className="about-band about-ack">
        <hr className="about-divider" />
        <div className="about-links">
          {LINKS.map((link) => (
            <button
              type="button"
              className="about-link"
              key={link.url}
              onClick={() => openExternal(link.url)}
            >
              {link.title}
              <ExternalIcon />
            </button>
          ))}
        </div>
        <p className="about-license">
          © 2026 Voxly. MIT License. All transcription happens on-device. Your audio
          never leaves this Mac.
        </p>
      </section>
    </div>
  );
}
