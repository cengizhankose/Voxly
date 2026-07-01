# Voxly Design System — "Signal"

> Design language for the Voxly marketing/landing surface.
> Voxly is a privacy-first macOS menu bar dictation app: press `Option+D`, speak, and the transcript is pasted into the focused app. Everything runs on device via whisper.cpp. The web surface sells that promise: fast, local, Mac-native.

**Status:** Locked (direction "Signal", light + dark).
**Source of truth for tokens:** this document. The preview `design/signal.html` is the visual reference; production values below override it where they differ.
**Owners:** design + frontend.
**Last updated:** 2026-06-25.

---

## 0. Design Read & Dials

**Reading this as:** a download/marketing landing for a privacy-first macOS dictation app, audience = Mac power users and developers, with a Linear-clean minimalist language, leaning toward a sans display + mono detail system with restrained motion.

| Dial | Value | Meaning for Voxly |
|------|-------|-------------------|
| `DESIGN_VARIANCE` | **5** | Mostly aligned, deliberate. Asymmetry used sparingly (hero, one or two feature breaks), never chaotic. |
| `MOTION_INTENSITY` | **3** | Micro only: entrance fades, hover feedback, the recording-chip pulse/waveform. No scroll hijack, no parallax. |
| `VISUAL_DENSITY` | **3** | Airy. Generous section rhythm, one idea per section. |

**"Signal" in one line:** high-contrast, confident, sharp. Off-black or near-white surfaces, one saturated rose accent, sharp 6px corners, Satoshi display + Geist Mono. The design gets out of the way of the message.

### Design principles
1. **Local is the feature.** Every layout choice reinforces "on your Mac, nothing leaves." Privacy is not a footnote.
2. **One accent, used with intent.** Rose `#E11D54` is the only color. It marks the primary action and emphasis, nothing decorative.
3. **Mono carries the technical truth.** Geist Mono is reserved for specs, shortcuts, status, metadata. It signals "this is a real tool," not a brochure.
4. **Sharp over soft.** 6px corners, hairline borders, no heavy drop shadows. The product feels engineered.
5. **Both modes are first-class.** Light and dark are designed together. Auto follows macOS appearance.

---

## 1. Color System

### 1.1 Semantic tokens (the only colors used)

Both modes carry the **same brand rose** `#E11D54` as the fill, so Voxly is recognisably one brand. `accent-text` shifts (darker on light, brighter on dark) so rose-as-text always clears WCAG AA.

| Token | Role | Light | Dark |
|-------|------|-------|------|
| `--bg` | Page background | `#FCFCFD` | `#08080A` |
| `--surface` | Elevated surface (cards, chips) | `#FFFFFF` | `#131318` |
| `--surface-2` | Second step (inputs, inset, segmented) | `#F4F5F7` | `#1C1C23` |
| `--border` | Hairline border | `#E6E8EB` | `#2C2C35` |
| `--border-strong` | Stronger border (ghost btn, input) | `#D5D8DD` | `#3A3A45` |
| `--text` | Primary text | `#0A0A0B` | `#F7F7F9` |
| `--muted` | Secondary text | `#6B7075` | `#9A9AA4` |
| `--accent-fill` | Button fill, brand mark, dot, waveform | `#E11D54` | `#E11D54` |
| `--accent-ink` | Label on accent fill | `#FFFFFF` | `#FFFFFF` |
| `--accent-text` | Rose as text (eyebrow, emphasis, links) | `#BE123C` | `#FF5C86` |
| `--accent-soft` | Rose tint (focus ring, badge bg) | `rgba(225,29,84,0.08)` | `rgba(255,92,134,0.10)` |

### 1.2 Contrast (verified WCAG, deterministic)

All pairs pass. Body threshold 4.5:1, primary text targets ≥7:1 (AAA).

| Pair | Light | Dark | Min req |
|------|-------|------|---------|
| text / bg | 19.3:1 | 18.7:1 | 7.0 |
| muted / bg | 4.88:1 | 7.18:1 | 4.5 |
| accent-text / bg | 6.13:1 | 6.79:1 | 4.5 |
| accent-ink / accent-fill | 4.66:1 | 4.66:1 | 4.5 |
| border / bg | 1.2:1 | 1.45:1 | (hairline, non-text) |

### 1.3 Color rules
- **Color Consistency Lock:** rose is the only accent on the entire page. No second hue appears anywhere (no blue CTA in a later section, no green "success", no amber warning). Status uses rose + text, or neutral.
- **No AI-purple / blue glow.** No neon outer glows. The only "glow" allowed is the single faint rose radial behind the hero at ≤8% opacity.
- **Shadows are tinted, never pure black.** See §4.
- **Pure `#000`/`#fff` banned.** Backgrounds use off-black `#08080A` / off-white `#FCFCFD`. `--accent-ink` may be `#FFFFFF` because it is a small label on a saturated fill, not a surface.

---

## 2. Typography

### 2.1 Families
| Role | Family | Source | Fallback |
|------|--------|--------|----------|
| Display / UI | **Satoshi** (400, 500, 700, 900) | Fontshare | `system-ui, -apple-system, sans-serif` |
| Mono / detail | **Geist Mono** (400, 500) | Google Fonts | `ui-monospace, SFMono-Regular, monospace` |

Production: load via `next/font` (self-host Satoshi from Fontshare files, Geist Mono via `next/font/google`). `font-display: swap`. No `<link>` to Google Fonts in production.

### 2.2 Scale

| Token | Size (clamp) | Weight | Tracking | Line-height | Use |
|-------|--------------|--------|----------|-------------|-----|
| `display` | `clamp(40px, 7vw, 76px)` | 900 | -0.04em | 1.0 | Hero H1 only |
| `h2` | `clamp(28px, 3.4vw, 40px)` | 800 | -0.03em | 1.05 | Section titles |
| `h3` | `21px` | 700 | -0.02em | 1.2 | Sub-headers, card titles |
| `body-lg` | `clamp(16px, 2vw, 19px)` | 400 | 0 | 1.55 | Hero sub, lead paragraphs |
| `body` | `16px` | 400 | 0 | 1.5 | Default copy (max-width 65ch) |
| `small` | `13.5px` | 400 | 0 | 1.45 | Captions, helper text |
| `mono` | `11–13px` | 400/500 | 0.01–0.16em | 1.4 | Specs, kicker/eyebrow, shortcuts, status |

### 2.3 Type rules
- **Emphasis = italic of the same family in `--accent-text`.** e.g. headline `Dictate anywhere, *instantly.*` Never inject a serif word into the sans headline.
- **Italic descender clearance:** any italic display word with `y g j p q` (e.g. "instantly") gets `line-height: 1.1` + `padding-bottom: 2px` and `display: inline-block` so the descender is not clipped.
- **Eyebrow / kicker** uses Geist Mono, `11px`, `uppercase`, `letter-spacing: 0.16em`, color `--accent-text` (hero) or `--muted` (sections).
- **Eyebrow restraint:** max 1 eyebrow per 3 sections. Hero counts as 1. Most sections use the headline alone.
- **Body max-width 65ch** (Tailwind `max-w-prose`, mapped in §8.3 — not the Typography plugin). Hero sub max 20 words / 4 lines.

---

## 3. Spacing, Layout & Grid

### 3.1 Spacing scale (4px base)
`2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 80, 96, 128` (px).

### 3.2 Layout
- **Container:** `max-width: 1080px`, side padding `28px` (`px-7`), centered. Wider full-bleed bands allowed for backgrounds; content stays in the 1080 rail.
- **Section rhythm:** `padding-block: clamp(48px, 7vw, 88px)`, separated by a single `--border` top rule. Airy (density 3).
- **Hero top padding cap:** `clamp(56px, 9vw, 96px)` — never exceed `96px` (`pt-24`) at desktop. Hero content must not float halfway down the viewport.
- **Grid over flex-math:** use CSS Grid (`grid-cols-1 md:grid-cols-2`) for multi-column; never `w-[calc(33%-1rem)]`.

### 3.3 Breakpoints (standard)
`sm 640 · md 768 · lg 1024 · xl 1280 · 2xl 1536`. High-variance layouts collapse to single column `< 768px` (`w-full`, `px-7`).

### 3.4 Layout discipline (hard rules)
- Hero fits the initial viewport: headline ≤ 2 lines, sub ≤ 20 words, CTAs visible without scroll.
- Nav on one line at desktop, height ≤ 72px.
- Section-layout-repetition ban: a layout family appears at most once. Across ~8 sections use ≥ 4 families.
- Max 2 consecutive image+text-split (zigzag) sections.
- Viewport stability: `min-h-[100dvh]` for full-height sections, never `h-screen`. **Hero is the exception:** it must *fit* the initial viewport on a 13-inch MacBook Air (test ≈ `1280×768`), CTA visible without scroll — do not lock the hero to `100dvh` and let copy overflow. Reserve `min-h-[100dvh]` for below-the-fold full-bleed sections.

---

## 4. Radius & Elevation

### 4.1 Radius (sharp system — locked)
| Token | Value | Applied to |
|-------|-------|-----------|
| `--radius` | `6px` | Buttons, inputs, swatches, small chips |
| `--radius-lg` | `12px` | Cards, token panels, larger containers |
| `--radius-pill` | `999px` | Badges, segmented control, recording chip |

**Shape Consistency Lock:** these three are the only radii. Buttons/inputs = 6px, cards = 12px, pills = full. No other values.

### 4.2 Elevation (tinted, restrained)
Cards are mostly defined by `1px --border`, not shadow. Shadow only where elevation communicates real lift.

| Token | Use | Light | Dark |
|-------|-----|-------|------|
| `--shadow-sm` | button / chip / toggle hover lift | `0 1px 2px rgba(10,10,11,.06)` | `0 1px 2px rgba(0,0,0,.45)` |
| `--shadow` (md) | recording chip, popover | `0 1px 2px rgba(10,10,11,.05), 0 8px 24px rgba(10,10,11,.06)` | `0 1px 2px rgba(0,0,0,.40), 0 12px 40px rgba(0,0,0,.50)` |
| `--shadow-lg` | modal, dropdown / mobile menu | `0 8px 16px rgba(10,10,11,.08), 0 24px 64px rgba(10,10,11,.12)` | `0 8px 16px rgba(0,0,0,.5), 0 24px 64px rgba(0,0,0,.6)` |

Cards default to border-only; reserve shadow for the recording chip and floating surfaces. No pure-black shadow on light. No neon glow as elevation.

---

## 5. Motion (`MOTION_INTENSITY: 3`)

Motion is micro and motivated. Every animation maps to: hierarchy, feedback, state transition, or the product's "recording" story.

### 5.1 Tokens
| Token | Value | Use |
|-------|-------|-----|
| `--ease-out` | `cubic-bezier(.16, 1, .3, 1)` | Entrances |
| `--ease` | `ease` | State / hover |
| `--dur-tactile` | `120ms` | `:active` press (`translateY(1px)`) |
| `--dur-state` | `180–220ms` | Hover, focus, border |
| `--dur-theme` | `350ms` | Light↔dark surface/text transition |
| `--dur-enter` | `550ms` | Hero entrance, scroll reveal |

### 5.2 What moves
- **Hero entrance:** eyebrow → h1 → sub → CTA → chip rise+fade (`translateY(10px)→0`, `opacity 0→1`), staggered 50ms, `--dur-enter`, `--ease-out`.
- **Recording chip:** waveform bars loop (`wave`), dot pulse (`pulse`). The brand's living detail — exact keyframes in §5.5. Visible always (hero visual + components), not state-gated.
- **Hover:** buttons opacity/bg shift; ghost button fills `--surface-2`; `:active` press down 1px.
- **Scroll reveal:** key sections fade-up once via Motion `whileInView` — `initial {opacity:0, y:24}` → `{opacity:1, y:0}`, `--dur-enter` (550ms), `--ease-out`, `viewport={{ once:true, amount:0.3 }}`. Multi-column children stagger 50–60ms. Not GSAP — no pinning. Animated sections: feature blocks, token panel, quote, CTA band (the hero uses its own entrance, not `whileInView`).

### 5.3 Forbidden
- No `window.addEventListener('scroll')`. Use Motion `useScroll`/`whileInView`, IntersectionObserver, or CSS scroll-driven animations.
- No scroll hijack, no parallax, no marquee, no custom cursor.
- Animate only `transform` / `opacity`.

### 5.4 Reduced motion (mandatory)
Everything above 3 honors `prefers-reduced-motion`. Loops (waveform, pulse), entrance stagger, and scroll reveals collapse to static/instant under `reduce`. In Motion, gate with `useReducedMotion()`.

### 5.5 Keyframe spec (recording chip)
Exact values, matching `design/signal.html`. Both loops collapse to static under `prefers-reduced-motion: reduce`.

```css
/* 5 waveform bars, staggered 0 / .13 / .26 / .39 / .52s */
@keyframes wave  { 0%,100% { height: 4px; } 50% { height: 14px; } }
/* rose recording dot */
@keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: .35; } }

@media (prefers-reduced-motion: no-preference) {
  .chip__wave i { animation: wave 1.1s ease-in-out infinite; }
  .chip__dot    { animation: pulse 1.6s ease-in-out infinite; }
}
/* reduce → no animation: bars rest at mid-height, dot at full opacity */
```

---

## 6. Components

States are defined for each: **default / hover / active / focus-visible / disabled**.

### 6.1 Button
| Variant | Default | Hover | Active | Focus-visible | Disabled |
|---------|---------|-------|--------|---------------|----------|
| **Primary** | `bg --accent-fill`, `--accent-ink`, radius 6 | `opacity .92` | `translateY(1px)` | `0 0 0 3px --accent-soft` ring | `opacity .5`, no pointer |
| **Ghost** | transparent, `--text`, `1px --border-strong` | `bg --surface-2` | `translateY(1px)` | same ring | `opacity .5` |
| **Link** | `--accent-text`, 1px underline at 35% | underline 100% | — | ring | — |

- **Sizing:** default = padding `13px 22px` (y/x), font-size `14.5px`, line-height 1, min-height 44px; small = padding `9px 16px`, font-size `13px`, min-height 36px. Leading icon 16px, `gap 8px`.
- **Disabled:** primary/ghost = `opacity .5`, `cursor: not-allowed`, no pointer events. Link = `--muted`, no underline, `cursor: not-allowed`.
- Label ≤ 3 words, one line at desktop (no wrap).
- **CTA repetition is fine, label drift is not.** The same primary label ("Download for macOS") may repeat in nav, hero, and footer — that is intentional multi-touchpoint design. Banned: (a) two different labels for one intent ("Download" vs "Get the app" vs "Try it"), and (b) two competing primary buttons side-by-side in one region. One label per intent; one primary per region.

### 6.2 Badge / pill
- `--radius-pill`, `1px --border-strong`, Geist Mono 11.5px, `--muted`.
- Accent variant: `--accent-text` text, `--accent-soft` bg, rose dot. Use only for real state ("On device"), not decoration. **Zero decorative status dots.**

### 6.3 Input / form
- Label **above** input (`gap 7px`), helper text **below**, error text **below** in `--accent-text`.
- Field: `bg --surface-2`, `1px --border-strong`, radius 6, font-size 14px, padding `11px 14px`.
- **States:** default as above · **hover** border `--border-strong → --muted` · **focus** `border-color --accent-fill` + `0 0 0 3px --accent-soft` ring · **error** `border-color --accent-fill`, keep `--surface-2` bg (no red tint), message below in `--accent-text`, `aria-invalid="true"` · **disabled** `opacity .5`, `cursor: not-allowed`.
- Placeholder is never a label. Placeholder color `--muted` (passes AA).

### 6.4 Recording chip (signature motif)
Abstract stand-in for the menu-bar `Option+D` moment. **Not** a fake screenshot.
- Pill, `--surface` bg, `1px --border`, `--shadow`.
- Rose dot (pulsing) + "Recording" (mono) + 5-bar waveform (rose, looping) + `⌥` `D` keycaps.
- Reuse as the hero visual and in feature sections. This is the product's face on the web.

### 6.5 Navigation
- Sticky, `≤ 72px`, blurred bg (`backdrop-filter: blur(14px) saturate(140%)` over `bg` at ~82%), `1px --border` bottom, `z-50`.
- Left: brand (rose mark + "Voxly"). Right: links + primary CTA + theme toggle. One line at desktop.
- **No-backdrop / reduced-transparency fallback:**
  ```css
  @supports not (backdrop-filter: blur(1px)) { .nav { background: var(--bg); } }
  @media (prefers-reduced-transparency: reduce) { .nav { background: var(--bg); backdrop-filter: none; } }
  ```
- **Mobile (`< 768px`):** hamburger opens a top-slide drawer — full width, `bg --bg`, `--shadow-lg`, dark scrim (`rgba(0,0,0,.6)`) behind, `z-50`; same links + CTA + toggle. Closes on link click, scrim click, or `Esc`. Focus trapped while open; first link focused on open; trigger regains focus on close.

### 6.6 Theme toggle (segmented)
- 3-segment pill: `Light / Auto / Dark`. `--surface-2` track, active segment `--surface` + `--shadow-sm`, `aria-pressed` per segment.
- **States:** inactive text `--muted` → hover `--text`; active `--text`. **Focus-visible:** `0 0 0 3px --accent-soft` ring on the focused segment.
- **Keyboard:** segments are `<button>`s in a `role="group"`; Tab moves between them, Space/Enter selects. (Optional: upgrade to a `radiogroup` with roving-tabindex + arrow keys.)
- Default **Auto** (system). Manual choice persists (`localStorage` key `voxly-signal-theme`). See §8.

### 6.7 Card
- `--surface`, `1px --border`, `--radius-lg`, padding 24px. Prefer borders/spacing over shadow.
- **Cards do not nest.** For grouped content use a grid/list with shared borders and spacing, not a card inside a card.

---

## 7. Iconography & Imagery

### 7.1 Icons
- **Library:** Phosphor (`@phosphor-icons/react`), regular weight, `strokeWidth` consistent. One family only.
- **No hand-rolled SVG icon paths** in production. (The inline SVGs in `design/signal.html` are preview-only stand-ins and must be replaced with Phosphor in the build.)

### 7.2 Imagery
- **Real product over generated lifestyle.** Voxly is a developer-credible tool, not a SaaS brochure. Priority: (1) real screenshots of the menu-bar app / transcript-landing-in-app, (2) the recording-chip motif, (3) technical generated imagery only (the app on a Mac, terminal, waveform, architecture). **Never** people / coffee-shop / desk lifestyle stock — it reads as AI-landing filler and kills credibility for a privacy-first app.
- **Aspect ratios:** hero visual 16:9 (`1600×900`) or 3:2 (`1500×1000`); feature shots 3:2 (`1200×800`); product close-ups use the chip motif. Hero ships `next/image priority` (LCP).
- Demo fallback only: `https://picsum.photos/seed/voxly-on-mac/1600/900` (fixed seed, reproducible). Replace before ship.
- **No div-based fake screenshots.** Show the app via a real screenshot, a technical generated image, or the recording chip.
- **Logo wall** (only with real social proof) sits **under** the hero: real SVG logos (Simple Icons) or generated monograms — never plain text wordmarks, never category labels under each logo.

---

## 8. Theming (light / dark)

### 8.1 Strategy
- Page-level theme on `<html>` via `data-theme`. **One theme per page** — no section inverts mid-scroll.
- **Auto** = no `data-theme` attribute; CSS follows `prefers-color-scheme`.
- **Manual** = `data-theme="light"|"dark"` overrides system, persisted to `localStorage` (`voxly-signal-theme`).

### 8.2 CSS variable contract (matches `design/signal.html`)

```css
:root { /* LIGHT defaults */
  --bg:#FCFCFD; --surface:#FFFFFF; --surface-2:#F4F5F7;
  --border:#E6E8EB; --border-strong:#D5D8DD;
  --text:#0A0A0B; --muted:#6B7075;
  --accent-fill:#E11D54; --accent-ink:#FFFFFF; --accent-text:#BE123C;
  --accent-soft:rgba(225,29,84,.08);
  --radius:6px; --radius-lg:12px;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) { /* AUTO → dark */
    --bg:#08080A; --surface:#131318; --surface-2:#1C1C23;
    --border:#2C2C35; --border-strong:#3A3A45;
    --text:#F7F7F9; --muted:#9A9AA4;
    --accent-fill:#E11D54; --accent-ink:#FFFFFF; --accent-text:#FF5C86;
    --accent-soft:rgba(255,92,134,.10);
  }
}
:root[data-theme="dark"] { /* manual dark — same dark block */ }
```

### 8.3 Tailwind v4 mapping (`@theme inline`)
Production stack is Next.js (RSC) + Tailwind v4 + Motion + next/font. Map the CSS vars into Tailwind tokens:

```css
@import "tailwindcss";
@theme inline {
  --color-bg: var(--bg);
  --color-surface: var(--surface);
  --color-surface-2: var(--surface-2);
  --color-border: var(--border);
  --color-border-strong: var(--border-strong);
  --color-text: var(--text);
  --color-muted: var(--muted);
  --color-accent: var(--accent-fill);
  --color-accent-ink: var(--accent-ink);
  --color-accent-text: var(--accent-text);
  --color-accent-soft: var(--accent-soft);
  --radius: 6px; --radius-lg: 12px;
  --shadow-sm: var(--shadow-sm);
  --shadow-md: var(--shadow);
  --shadow-lg: var(--shadow-lg);
  --ease-out: cubic-bezier(.16, 1, .3, 1);
  --max-width-prose: 65ch;
  --font-sans: "Satoshi", system-ui, sans-serif;
  --font-mono: "Geist Mono", ui-monospace, monospace;
}
```
PostCSS: use `@tailwindcss/postcss` (or the Vite plugin), **not** the legacy `tailwindcss` plugin. Motion durations (`--dur-*`, §5.1) stay raw CSS vars, consumed via arbitrary values (`duration-[120ms]`) or a small Motion config — they are not color/spacing tokens. Body copy uses `max-w-prose` (65ch, mapped above), not the Typography plugin.

---

## 9. Accessibility

- **Contrast:** all text pairs meet WCAG AA (body 4.5:1); primary text ≥ 7:1. See §1.2.
- **Focus-visible:** every interactive element shows the rose ring `0 0 0 3px --accent-soft` (+ border shift on inputs). Never remove focus outlines without a replacement.
- **Reduced motion:** §5.4 — loops/entrances collapse under `prefers-reduced-motion: reduce`.
- **Reduced transparency:** any glass/blur (nav) provides a solid-fill fallback under `prefers-reduced-transparency: reduce`.
- **Targets:** interactive ≥ 40px tall. **Semantics:** real `<button>`/`<a>`, labelled inputs, the segmented toggle uses `role="group"` + `aria-pressed`.
- **Keyboard:** full tab order, visible focus, hamburger menu operable.

---

## 10. Voice & Content

- **Tone:** concrete, technical, privacy-forward. Talk like a tool, not a brochure.
- **Banned filler verbs:** "elevate, seamless, unleash, next-gen, revolutionize." Use plain verbs ("paste", "run", "press", "stay").
- **Em-dash banned everywhere** (headlines, body, captions, attribution, alt text). Use a period, comma, parentheses, colon, or a hyphen `-`.
- **Numbers:** only real ones (whisper.cpp `v1.8.1`, `16kHz`, `Option+D`). No invented spec precision.
- **CTA labels:** one per intent. Primary "Download for macOS", secondary "View source". No "Get started"/"Try it"/"Let's go" duplicates.
- **No locale/time/weather strips, no scroll cues, no version labels in hero, no section-number eyebrows, no decorative middle-dots as a separator system.**
- **Sample copy:**
  - Eyebrow: `On device · no cloud` (the privacy promise, not a spec sheet — "Apple Silicon" as an eyebrow is padding that buys no credibility with Mac power users)
  - H1: `Dictate anywhere, *instantly.*`
  - Sub: `Press Option+D, talk, and Voxly drops the transcript straight into whatever app has focus. Every word stays on your Mac.`
  - Mono detail: `whisper.cpp · 16kHz · 100% local`

---

## 11. Anti-Slop Guardrails (Voxly-specific quick check)

- [ ] Rose `#E11D54` is the only accent, used identically in every section.
- [ ] One theme per page; no inverted section mid-scroll; Auto follows macOS.
- [ ] Zero em-dashes anywhere visible.
- [ ] Radii are only 6 / 12 / pill.
- [ ] Hero ≤ 2-line headline, ≤ 20-word sub, CTA above the fold, top padding ≤ 96px.
- [ ] Max 1 eyebrow per 3 sections.
- [ ] Real images (generated or Picsum-seed), recording chip instead of fake screenshots.
- [ ] No hand-rolled icons in production (Phosphor only).
- [ ] Every CTA passes contrast and fits one line; one label per intent.
- [ ] Motion ≤ 3, reduced-motion safe, `transform`/`opacity` only.
- [ ] Both modes tested before shipping.

---

## 12. References

- Preview / visual source: `design/signal.html` (dual-mode, toggle).
- Direction picker (archived): `design/design-systems.html`.
- App context: `CLAUDE.md` (Voxly architecture, `Option+D`, whisper.cpp, on-device).
- Fonts: Satoshi (Fontshare), Geist Mono (Google Fonts / `next/font`).
- Icons: Phosphor — https://phosphoricons.com
- Tailwind v4: https://tailwindcss.com/blog/tailwindcss-v4 · Motion: https://motion.dev
