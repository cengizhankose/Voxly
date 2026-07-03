# Voxly Landing Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a compact, animation-focused static landing page for Voxly in `site/`, deployed to GitHub Pages via Actions, faithful to the "Signal" design system.

**Architecture:** Three source files (`index.html`, `styles.css`, `main.js`) plus self-hosted fonts and favicon. No framework, no build step; GitHub Actions uploads `site/` as a Pages artifact. Verification is visual/manual (no test framework in repo) — each task ends with a concrete browser check.

**Tech Stack:** Semantic HTML5, CSS custom properties (design tokens), vanilla JS (theme toggle + IntersectionObserver), GitHub Actions `deploy-pages`.

## Global Constraints

- Colors: rose `#E11D54` is the ONLY accent. No second hue anywhere. Pure `#000`/`#fff` banned (off-black `#08080A`, off-white `#FCFCFD`).
- Radii: only `6px` (buttons/inputs), `12px` (cards), `999px` (pills). No others.
- Typography: Satoshi (display/UI, 400/500/700/900), Geist Mono (detail, 400/500). Self-hosted, `font-display: swap`. No CDN font requests in production.
- Em-dash banned everywhere visible. Use period, comma, parentheses, colon, or hyphen `-`.
- Motion `MOTION_INTENSITY: 3`: `transform`/`opacity` only. Everything honors `prefers-reduced-motion: reduce`. No scroll listeners, no parallax, no marquee.
- One theme per page. `data-theme` on `<html>`; absent = Auto (system). Manual persisted to `localStorage["voxly-signal-theme"]`.
- CTA copy: one label per intent. Primary `Download for macOS` → `https://github.com/cengizhankose/Voxly/releases/latest`. Secondary `View source` → repo.
- All asset paths relative (project sub-path `/Voxly/`).
- Hero: ≤2-line headline, ≤20-word sub, CTA above fold at 1280×768, top padding ≤96px.
- Focus-visible rose ring `0 0 0 3px var(--accent-soft)` on every interactive element.
- Tokens copied verbatim from design system §8.2.

---

### Task 1: Scaffold site/ — tokens, fonts, favicon, skeleton

**Files:**
- Create: `site/index.html`, `site/styles.css`, `site/main.js`
- Create: `site/fonts/` (Satoshi + Geist Mono woff2)
- Create: `site/favicon.png` (copy from `Resources/Assets.xcassets/AppIcon.appiconset/icon_512.png`)

**Interfaces:**
- Produces: CSS variable contract (`--bg`, `--surface`, `--surface-2`, `--border`, `--border-strong`, `--text`, `--muted`, `--accent-fill`, `--accent-ink`, `--accent-text`, `--accent-soft`, `--radius`, `--radius-lg`, `--radius-pill`, shadow tokens, ease/duration tokens, `--font`, `--mono`) available to all later tasks.

- [ ] **Step 1:** Copy favicon: `cp Resources/Assets.xcassets/AppIcon.appiconset/icon_512.png site/favicon.png`; also `cp .../icon_1024.png site/og-image.png`.
- [ ] **Step 2:** Fetch self-hosted fonts into `site/fonts/`: download Satoshi (400,500,700,900) and Geist Mono (400,500) woff2. Prefer Fontshare Satoshi + Google Geist Mono woff2 URLs; if variable unavailable, grab static weights. Add `@font-face` blocks in `styles.css` with `font-display: swap` and the exact family names `Satoshi` / `Geist Mono`.
- [ ] **Step 3:** In `styles.css`, paste the design system §8.2 token contract verbatim: light `:root`, `@media (prefers-color-scheme: dark) :root:not([data-theme="light"])`, `:root[data-theme="dark"]`. Add `--radius-pill: 999px`, shadow tokens (§4.2), ease/duration tokens (§5.1), `--font`/`--mono`. Add a `* { box-sizing: border-box }` reset, base `body { background: var(--bg); color: var(--text); font-family: var(--font) }`, `.container { max-width: 1080px; margin-inline: auto; padding-inline: 28px }`.
- [ ] **Step 4:** In `index.html`, write the document skeleton: `<!doctype html><html lang="en">`, `<head>` with charset, viewport, `<title>Voxly — Local dictation for macOS</title>`, `meta description`, favicon link, `<link rel="stylesheet" href="./styles.css">`, and the FOUC-guard inline theme script (reads `localStorage["voxly-signal-theme"]`, sets `data-theme` if `light`/`dark`). Empty `<body>` with `<script src="./main.js" defer></script>`.
- [ ] **Step 5 (verify):** `cd site && python3 -m http.server 8099` then load `http://localhost:8099/`. Confirm page loads with correct background in both OS appearances (toggle System Settings appearance), fonts present in the network tab loading from `./fonts/` (not a CDN). Stop server.
- [ ] **Step 6 (commit):**
```bash
git add site/ && git commit -m "feat(site): scaffold landing page tokens, fonts, skeleton"
```

---

### Task 2: Theme toggle (Light / Auto / Dark)

**Files:**
- Modify: `site/index.html` (add toggle markup — placed in nav in Task 3, but the control + JS wired here as a temporary top element, then moved), `site/styles.css`, `site/main.js`

**Interfaces:**
- Consumes: token contract (Task 1).
- Produces: `.seg` segmented-control component (CSS) and `main.js` theme module exposing behavior via DOM (`[data-theme-set]` buttons); `localStorage["voxly-signal-theme"]` persistence.

- [ ] **Step 1:** Add segmented control markup: a `<div class="seg" role="group" aria-label="Theme">` with three `<button data-theme-set="light|auto|dark" aria-pressed>` (labels Light / Auto / Dark). Temporarily place at top of `<body>`.
- [ ] **Step 2:** Style `.seg` per §6.6: `--surface-2` track, pill radius, active segment `--surface` + `--shadow-sm`; inactive text `--muted` → hover `--text`; focus-visible ring; segments ≥36px tall.
- [ ] **Step 3:** In `main.js`, implement theming: read stored value (`light`/`dark`/absent=auto), apply to `document.documentElement` (`data-theme` set for light/dark, removed for auto), set `aria-pressed` on the matching segment. On click: persist (`auto` → `removeItem`), re-apply, update pressed state. Add a `.theme-anim` class to `<html>` only after first paint so the 350ms color transition (`--dur-theme`) fires on toggle, not on load.
- [ ] **Step 4:** In `styles.css`, add `html.theme-anim, html.theme-anim body, html.theme-anim .surface { transition: background-color var(--dur-theme) var(--ease), color var(--dur-theme) var(--ease), border-color var(--dur-theme) var(--ease) }` guarded out under reduced-motion.
- [ ] **Step 5 (verify):** Serve, click each segment — background/text swap with a smooth 350ms transition; reload keeps the manual choice; Auto follows OS appearance; keyboard Tab + Enter operate segments; focus ring visible.
- [ ] **Step 6 (commit):** `git add site/ && git commit -m "feat(site): theme toggle with persistence and transition"`

---

### Task 3: Navigation bar

**Files:** Modify `site/index.html`, `site/styles.css`

**Interfaces:**
- Consumes: `.seg` (Task 2), tokens, button styles (defined here, reused later).
- Produces: `.btn`, `.btn--primary`, `.btn--ghost`, `.link` button/link components; `.brand` mark; `.nav` sticky-blur header.

- [ ] **Step 1:** Build `<nav class="nav">` inside a `.container` row: left `<a class="brand">` = inline rose SVG glyph (rounded square, `--accent-fill`) + `Voxly`; right = `<a class="link">Features</a>`, `<a class="link">Privacy</a>`, primary CTA `Download for macOS` (→ releases/latest, `rel="noopener"`), and the `.seg` toggle moved here from body top.
- [ ] **Step 2:** Style `.btn` sizes (§6.1): primary `bg --accent-fill` / `--accent-ink`, radius 6, padding `13px 22px`, min-height 44px, hover `opacity .92`, active `translateY(1px)`, focus ring; ghost transparent + `1px --border-strong`, hover `bg --surface-2`; `.link` `--accent-text`/`--muted` with 35%→100% underline on hover; small size variant for nav.
- [ ] **Step 3:** Style `.nav`: sticky top, `z-50`, height ≤72px, `backdrop-filter: blur(14px) saturate(140%)`, bg `--bg` at ~82% alpha, `1px --border` bottom. Add `@supports not (backdrop-filter: blur(1px))` and `@media (prefers-reduced-transparency: reduce)` solid-bg fallbacks. One row at desktop; on `<768px` allow the toggle/links to wrap gracefully (links hide or wrap under, CTA + toggle stay usable).
- [ ] **Step 4 (verify):** Serve, confirm nav sticks on scroll with blur, sits one line at desktop, CTA links to releases/latest, hover/active/focus states correct in both themes, wraps cleanly at 375px.
- [ ] **Step 5 (commit):** `git add site/ && git commit -m "feat(site): sticky nav with brand, links, CTA, toggle"`

---

### Task 4: Hero + recording chip + entrance animation

**Files:** Modify `site/index.html`, `site/styles.css`

**Interfaces:**
- Consumes: buttons (Task 3), tokens.
- Produces: `.hero`, `.eyebrow`, `.chip` (recording motif), `@keyframes wave/pulse/rise`.

- [ ] **Step 1:** Build `<section class="hero">` in `.container`: `.eyebrow` (mono, uppercase, rose) `On device · no cloud`; `<h1>` `Dictate anywhere, <em>instantly.</em>`; sub `<p>` (verbatim sub copy, ≤20 words); `.cta` row (primary `Download for macOS` + ghost `View source`); recording chip; mono detail `whisper.cpp · 16kHz · 100% local`.
- [ ] **Step 2:** Recording chip markup (verbatim from `design/signal.html`): `<div class="chip"><span class="chip__dot"></span><span class="chip__txt">Recording</span><span class="chip__wave"><i></i>×5</span><kbd>⌥</kbd><kbd>D</kbd></div>`.
- [ ] **Step 3:** Style hero: centered column, top padding `clamp(56px,9vw,96px)`, display H1 (`clamp(40px,7vw,76px)`, weight 900, tracking -0.04em), italic `em` in `--accent-text` with descender clearance (`display:inline-block; line-height:1.1; padding-bottom:2px`), body-lg sub (max ~50ch), single rose radial behind hero at ≤8%. Chip per §6.4: pill, `--surface`, `1px --border`, `--shadow`, mono text, `kbd` keycaps styled as small `--surface-2` pills. Waveform bars `2px` wide, rose.
- [ ] **Step 4:** Add `@keyframes wave { 0%,100%{height:4px} 50%{height:14px} }`, `@keyframes pulse { 0%,100%{opacity:1} 50%{opacity:.35} }`, `@keyframes rise { from{opacity:0;transform:translateY(10px)} to{opacity:1;transform:none} }`. Wire under `@media (prefers-reduced-motion: no-preference)`: chip bars `wave 1.1s ... infinite` with `nth-child` delays `0/.13/.26/.39/.52s`; dot `pulse 1.6s ... infinite`; hero children `rise .55s var(--ease-out) both` with delays `eyebrow 0 / h1 .05 / p .1 / cta .15 / chip .2`.
- [ ] **Step 5 (verify):** Serve at 1280×768: hero fits, CTA above fold, headline ≤2 lines. Entrance plays once on load (staggered rise). Chip waveform loops + dot pulses continuously. Descender of "instantly" not clipped. Both themes.
- [ ] **Step 6 (commit):** `git add site/ && git commit -m "feat(site): hero with recording chip and entrance animation"`

---

### Task 5: Features grid + scroll reveal

**Files:** Modify `site/index.html`, `site/styles.css`, `site/main.js`

**Interfaces:**
- Consumes: tokens, section rhythm.
- Produces: `.section`, `.section__title`, `.grid-2`, `.card`, `.reveal` + IntersectionObserver in `main.js`.

- [ ] **Step 1:** Build `<section class="section" id="features">`: h2 `Built to stay out of the way.` (plain, no filler), then `.grid-2` of four `.card`s. Each card: inline Phosphor SVG icon (regular weight) + `<h3>` + 2-line `<p>`. Content per spec §4 (On-device transcription / Global hotkey ⌥D / Auto-paste / Metal acceleration). Add `.reveal` class + `data-reveal-index` 0..3 to cards.
- [ ] **Step 2:** Style `.section` (rhythm `padding-block: clamp(48px,7vw,88px)`, `1px --border` top rule), `.section__title` (h2 scale), `.grid-2` (`display:grid; grid-template-columns:1fr 1fr; gap:20px`, single column `<768px`), `.card` (§6.7: `--surface`, `1px --border`, radius 12, padding 24; hover: border `--border-strong` + `translateY(-2px)` transform, no nested cards). Icon 22px, `--accent-text`.
- [ ] **Step 3:** Style `.reveal { opacity:0; transform:translateY(24px); transition:opacity .55s var(--ease-out), transform .55s var(--ease-out) }` and `.reveal.is-in { opacity:1; transform:none }`. Stagger via `.reveal[data-reveal-index="1"]{transition-delay:.06s}` etc (0/.06/.12/.18s).
- [ ] **Step 4:** In `main.js`, add IntersectionObserver (`threshold:0.3`) that adds `is-in` once per element then unobserves. Select all `.reveal`. Guard: if `matchMedia('(prefers-reduced-motion: reduce)').matches`, immediately add `is-in` to all and skip the observer.
- [ ] **Step 5 (verify):** Serve, scroll down: cards fade-up with left-to-right stagger, once. Hover lifts card. 2×2 at desktop, 1-col at 375px. Icons single rose family. Both themes.
- [ ] **Step 6 (commit):** `git add site/ && git commit -m "feat(site): features grid with scroll reveal"`

---

### Task 6: Privacy band + CTA band + footer

**Files:** Modify `site/index.html`, `site/styles.css`

**Interfaces:**
- Consumes: buttons, `.reveal`, tokens.
- Produces: `.band` (full-bleed), `.cta-band`, `.footer`.

- [ ] **Step 1:** Privacy band `<section class="band" id="privacy">`: full-bleed `--surface` background, centered `.container` content: h2 `Your voice never leaves this Mac.`, body (no accounts, no telemetry, no cloud), mono line `100% local · no network calls · open source`. Add `.reveal`.
- [ ] **Step 2:** CTA band `<section class="section cta-band">`: centered narrow, h2 `Talk. It types.`, primary `Download for macOS`, mono note `macOS 13+ · Apple Silicon`. Add `.reveal`.
- [ ] **Step 3:** Footer `<footer class="footer">` in `.container`: left © line `© 2026 Voxly · MIT License`; links GitHub (repo) / whisper.cpp / Report an issue (`.link`); privacy one-liner in `--muted`. `1px --border` top.
- [ ] **Step 4:** Style `.band` (full-bleed via `width:100%` section with inner container; distinct from plain sections — background fill, larger vertical rhythm), `.cta-band` (centered, max ~560px), `.footer` (rows, small type, `--muted`). Ensure full-bleed band does not introduce horizontal scroll.
- [ ] **Step 5 (verify):** Serve, full-page scroll: 4 distinct layout families read clearly, privacy band spans full width with no h-scroll, CTA band centered, footer links resolve. Reveals fire. Both themes.
- [ ] **Step 6 (commit):** `git add site/ && git commit -m "feat(site): privacy band, CTA band, footer"`

---

### Task 7: Reduced-motion, a11y, meta/OG polish

**Files:** Modify `site/index.html`, `site/styles.css`

**Interfaces:** Consumes: everything prior.

- [ ] **Step 1:** Add one consolidated `@media (prefers-reduced-motion: reduce)` block: disable `wave`/`pulse`/`rise` animations (bars rest mid-height, dot full opacity), set `.reveal{opacity:1;transform:none;transition:none}`, drop theme transition, remove reveal delays.
- [ ] **Step 2:** A11y sweep: `aria-label` on icon-only/brand controls, `rel="noopener noreferrer"` on external links, verify tab order (nav → hero CTAs → sections → footer), all interactive ≥40px, focus-visible ring present everywhere. Add `aria-hidden="true"` to purely decorative SVGs (chip waveform, radial).
- [ ] **Step 3:** Meta/OG in `<head>`: `meta description`, canonical `https://cengizhankose.github.io/Voxly/`, Open Graph (`og:title`, `og:description`, `og:image=./og-image.png`, `og:type=website`, `og:url`), `twitter:card=summary_large_image`, `theme-color`.
- [ ] **Step 4 (verify):** Emulate `prefers-reduced-motion: reduce` (DevTools rendering) — chip static, no entrance, reveals visible/static, no theme transition. Tab through whole page — logical order, visible focus. View source: OG tags present, image path relative.
- [ ] **Step 5 (commit):** `git add site/ && git commit -m "feat(site): reduced-motion, a11y, and social meta"`

---

### Task 8: GitHub Pages deploy workflow

**Files:** Create `.github/workflows/pages.yml`

- [ ] **Step 1:** Write the workflow: name `Deploy Pages`; `on: push: branches:[main] paths:['site/**','.github/workflows/pages.yml']` + `workflow_dispatch`; `permissions: pages: write, id-token: write, contents: read`; `concurrency: group: pages, cancel-in-progress: false`; single `deploy` job on `ubuntu-latest` with `environment: github-pages`: steps `actions/checkout@v4` → `actions/configure-pages@v5` → `actions/upload-pages-artifact@v3` (path `site`) → `actions/deploy-pages@v4` (id `deployment`, `url` output).
- [ ] **Step 2:** Enable Pages with Actions source (one-time): `gh api -X POST repos/cengizhankose/Voxly/pages -f build_type=workflow` (or PUT if it already exists); tolerate "already enabled".
- [ ] **Step 3 (commit + push):** `git add .github/workflows/pages.yml && git commit -m "ci: deploy site/ to GitHub Pages via Actions" && git push origin main`.
- [ ] **Step 4 (verify):** `gh run watch` (or `gh run list --workflow=pages.yml`) until success; then `curl -sI https://cengizhankose.github.io/Voxly/ | head -1` returns `HTTP/2 200`. Load the live URL, confirm rendering + assets.

---

### Task 9: Final verification pass

**Files:** none (may produce small fixes)

- [ ] **Step 1:** Anti-slop checklist (design system §11) against the live/served page — walk every box, fix any miss inline (re-commit + push if needed).
- [ ] **Step 2:** Cross-theme + responsive final: Light / Dark / Auto at 1280×768, 768, 375. Screenshot each for the record.
- [ ] **Step 3:** Confirm no CDN font requests in production network trace (privacy requirement). Confirm no horizontal scroll at any width. Confirm CTA → releases/latest resolves.
- [ ] **Step 4:** If any fixes were made, `git commit` + `git push`; re-confirm deploy succeeded.

---

## Self-Review

**Spec coverage:** Nav/Hero/Features/Privacy/CTA/Footer → Tasks 3–6. Motion (chip, entrance, reveal, hover, theme) → Tasks 2,4,5,7. Theming → Task 2. A11y → Task 7. Deploy → Task 8. Fonts/tokens → Task 1. Verification → Task 9. All spec sections mapped.

**Placeholders:** none — copy, keyframes, workflow YAML, and commands are concrete.

**Type/name consistency:** `.reveal`/`is-in`/`data-reveal-index`, `.chip`/`chip__dot`/`chip__wave`, `.btn--primary`/`.btn--ghost`, `.seg`/`data-theme-set`, `localStorage["voxly-signal-theme"]` used consistently across tasks.
