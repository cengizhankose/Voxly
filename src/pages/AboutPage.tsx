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
  license: string;
}

interface LinkItem {
  title: string;
  hint: string;
  url: string;
}

const ACKNOWLEDGEMENTS: AckItem[] = [
  { name: "whisper.cpp", detail: "On-device Whisper inference engine", license: "MIT" },
  { name: "ggml", detail: "Tensor library powering the model runtime", license: "MIT" },
  { name: "Tauri", detail: "Rust + system webview app framework", license: "MIT · Apache-2.0" },
  { name: "Accelerate / Metal", detail: "Apple vDSP + GPU inference kernels", license: "Apple SDK" },
];

const LINKS: LinkItem[] = [
  { title: "Source on GitHub", hint: "cengizhankose/Voxly", url: "https://github.com/cengizhankose/Voxly" },
  { title: "whisper.cpp", hint: "ggerganov/whisper.cpp", url: "https://github.com/ggerganov/whisper.cpp" },
  { title: "Report an issue", hint: "GitHub Issues", url: "https://github.com/cengizhankose/Voxly/issues" },
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

/** Lock glyph for the privacy focal line. */
function ShieldIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M12 3l7 3v5c0 4.4-3 8.2-7 9.5C8 19.2 5 15.4 5 11V6l7-3z"
        stroke="currentColor"
        strokeWidth="1.7"
        strokeLinejoin="round"
      />
      <path
        d="M9 12l2 2 4-4"
        stroke="currentColor"
        strokeWidth="1.7"
        strokeLinecap="round"
        strokeLinejoin="round"
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
  const activeModel = model ? `ggml-${model}.bin` : "not loaded";

  const metaRows: MetaRow[] = [
    { label: "Version", value: "1.0.0 (1)" },
    { label: "Active model", value: activeModel },
    { label: "whisper.cpp", value: "v1.8.1" },
    { label: "System", value: "macOS" },
    { label: "Architecture", value: "arm64 · Apple Silicon" },
    { label: "Inference", value: "Metal + Accelerate" },
  ];

  const openExternal = (url: string) => {
    void openUrl(url);
  };

  return (
    <div className="about">
      {/* Identity */}
      <section className="about-band about-identity">
        <span className="kicker about-eyebrow">Local dictation for macOS</span>
        <span className="about-mark">
          <BrandMark />
        </span>
        <h1 className="display about-wordmark">Voxly</h1>
        <p className="about-tagline">
          Press-to-talk transcription powered by <span className="mono">whisper.cpp</span>,
          running entirely on your Mac.
        </p>
      </section>

      {/* Privacy focal line */}
      <section className="about-band about-privacy-band">
        <div className="about-privacy" role="note">
          <span className="about-privacy-icon" aria-hidden="true">
            <ShieldIcon />
          </span>
          <div className="about-privacy-copy">
            <span className="about-privacy-title">All transcription on-device</span>
            <span className="about-privacy-sub">
              Audio is processed locally and never leaves this Mac.
            </span>
          </div>
        </div>
      </section>

      {/* Meta grid */}
      <section className="about-band about-meta-band" aria-label="Build details">
        <h2 className="kicker about-section-kicker">Build</h2>
        <dl className="about-meta-grid">
          {metaRows.map((row) => (
            <div className="about-meta-cell" key={row.label}>
              <dt className="about-meta-label">{row.label}</dt>
              <dd className="about-meta-value mono">{row.value}</dd>
            </div>
          ))}
        </dl>
      </section>

      {/* Acknowledgements */}
      <section className="about-band about-ack-band">
        <h2 className="kicker about-section-kicker">Built with</h2>
        <ul className="about-ack-list">
          {ACKNOWLEDGEMENTS.map((ack) => (
            <li className="about-ack-item" key={ack.name}>
              <div className="about-ack-head">
                <span className="about-ack-name">{ack.name}</span>
                <span className="badge about-ack-license">{ack.license}</span>
              </div>
              <span className="about-ack-detail">{ack.detail}</span>
            </li>
          ))}
        </ul>
      </section>

      {/* Links */}
      <section className="about-band about-links-band">
        <h2 className="kicker about-section-kicker">Links</h2>
        <div className="about-links">
          {LINKS.map((link) => (
            <button
              type="button"
              className="about-link"
              key={link.url}
              onClick={() => openExternal(link.url)}
            >
              <span className="about-link-body">
                <span className="about-link-title">{link.title}</span>
                <span className="about-link-hint mono">{link.hint}</span>
              </span>
              <ExternalIcon />
            </button>
          ))}
        </div>
      </section>

      {/* License footer */}
      <section className="about-band about-foot-band">
        <p className="about-license">
          © 2026 Voxly · MIT License · Made for people who’d rather speak than type.
        </p>
      </section>
    </div>
  );
}
