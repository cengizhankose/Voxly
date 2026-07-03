# Voxly Landing Page — Design Spec

**Date:** 2026-07-03
**Status:** Approved (design), pending implementation
**Owner:** frontend
**Design source of truth:** `claudedocs/voxly-design-system.md` ("Signal" v-locked), visual ref `design/signal.html`

---

## 1. Goal

A single, compact marketing/landing page for Voxly (privacy-first macOS dictation app), embedded in the repo and deployed to GitHub Pages. Sells the promise: press `Option+D`, speak, transcript pasted locally. The page must be a faithful, production-quality application of the "Signal" design system, with careful attention to motion and micro-detail.

**Non-goals:** blog, docs site, changelog, multi-page, analytics, forms/newsletter, i18n.

---

## 2. Decisions (from Q&A)

| Topic | Decision |
|-------|----------|
| Stack | Static HTML + CSS + vanilla JS. No framework, no build step. |
| Download CTA | `https://github.com/cengizhankose/Voxly/releases/latest` |
| Scope | Compact: Nav, Hero, Features, Privacy band, CTA band, Footer (5 content sections) |
| Deploy | `site/` folder + GitHub Actions (`actions/deploy-pages`), Pages source = "GitHub Actions" |
| Imagery | Recording-chip motif only (pure CSS). No image assets, no fake screenshots. |
| Fonts | Self-hosted Satoshi + Geist Mono woff2 (privacy: no CDN font requests in production) |

---

## 3. Architecture

```
site/
  index.html          # semantic single page (nav/main/footer)
  styles.css          # design tokens (§8.2 of design system, verbatim) + all component CSS
  main.js             # theme toggle (Light/Auto/Dark) + IntersectionObserver scroll reveal
  fonts/
    Satoshi-Variable.woff2      # 400..900
    GeistMono-Variable.woff2    # 400..600
  favicon.png         # from Resources/Assets.xcassets/AppIcon icon_512
  og-image.png        # from icon_1024 (social preview)
.github/workflows/pages.yml     # deploy site/ on push to main
```

**Isolation:** three files, each one purpose — `index.html` (structure/content), `styles.css` (all presentation + tokens), `main.js` (the only two behaviors: theming + reveal). No inline styles except the FOUC-guard theme script in `<head>`.

**Base path:** all asset references relative (`./styles.css`, `./fonts/...`) so the project-pages sub-path `/Voxly/` works without a `<base>` tag.

---

## 4. Page structure & content

Copy is taken verbatim from design system §10 where sample copy exists. Em-dash banned everywhere.

### Nav (sticky, ≤72px, blur)
- Left: rose brand mark (inline SVG, the app's rounded-square glyph) + "Voxly" wordmark.
- Right: text links (`Features`, `Privacy`), primary CTA `Download for macOS`, theme toggle (3-segment `Light / Auto / Dark`).
- Blur backdrop with solid fallbacks (`@supports not`, `prefers-reduced-transparency`).
- Mobile <768px: links collapse; keep CTA + toggle. (Compact page — a full hamburger drawer is optional; minimum is a clean single-row wrap that stays usable.)

### Hero
- Eyebrow (mono, uppercase, rose): `On device · no cloud`
- H1 (display, 900): `Dictate anywhere, ` + italic accent `instantly.` (descender clearance rules applied).
- Sub (body-lg, ≤20 words): `Press Option+D, talk, and Voxly drops the transcript straight into whatever app has focus. Every word stays on your Mac.`
- CTA row: primary `Download for macOS` (→ releases/latest), ghost `View source` (→ repo).
- Recording chip (signature motif) centered below CTAs.
- Mono detail line: `whisper.cpp · 16kHz · 100% local`
- Faint single rose radial behind hero at ≤8% opacity.
- Fits 1280×768 viewport, CTA above the fold, top padding ≤96px.

### Features (2×2 grid)
Four cards (border-defined, no nested cards), each: Phosphor icon (inline SVG) + h3 + 2-line body.
1. **On-device transcription** — whisper.cpp runs locally; audio never leaves the Mac.
2. **Global hotkey** — `⌥D` from any app to start/stop. Rebindable.
3. **Auto-paste** — transcript lands in the focused app via synthesized `⌘V`.
4. **Metal acceleration** — Apple GPU kernels for fast on-device inference.

### Privacy band (full-bleed)
- H2: `Your voice never leaves this Mac.`
- Short body reinforcing local processing (no accounts, no telemetry, no cloud).
- Mono spec line: `100% local · no network calls · open source`

### CTA band (centered, narrow)
- H2: `Talk. It types.` (plain, concrete, no filler verbs)
- Primary `Download for macOS`
- Mono requirement note: `macOS 13+ · Apple Silicon`

### Footer
- © 2026 Voxly · MIT License.
- Links: GitHub (repo), whisper.cpp, Report an issue.
- Privacy one-liner: `All transcription happens on-device. Your audio never leaves this Mac.`

**Layout-family audit:** centered-hero, 2×2 grid, full-bleed band, centered-narrow-band, nav, footer → ≥4 distinct families across 6 regions. One eyebrow total (hero). ✓

---

## 5. Motion (the focus)

`MOTION_INTENSITY: 3` — micro and motivated. Every animation maps to hierarchy, feedback, state, or the recording story. `transform`/`opacity` only. All of the below collapse to static/instant under `prefers-reduced-motion: reduce`.

### 5.1 Recording chip (living detail) — verbatim from §5.5
- 5 waveform bars: `@keyframes wave { 0%,100%{height:4px} 50%{height:14px} }`, `wave 1.1s ease-in-out infinite`, staggered delays `0 / .13 / .26 / .39 / .52s`.
- Rose dot: `@keyframes pulse { 0%,100%{opacity:1} 50%{opacity:.35} }`, `pulse 1.6s ease-in-out infinite`.
- Always-on (not state-gated).

### 5.2 Hero entrance (staggered rise)
- `@keyframes rise { from{opacity:0; transform:translateY(10px)} to{opacity:1; transform:none} }`
- Sequence eyebrow → h1 → sub → CTA → chip, each `rise .55s cubic-bezier(.16,1,.3,1) both`, stagger ~50ms (`0 / .05 / .1 / .15 / .2s`).
- Hero uses its own entrance, not IntersectionObserver.

### 5.3 Scroll reveal (below the fold)
- IntersectionObserver, `once`, `threshold 0.3`. Elements start `opacity:0; translateY(24px)`, animate to rest over 550ms `ease-out`.
- Multi-column children (feature cards) stagger 50–60ms via incremental `transition-delay` / data-index.
- Applies to: feature cards, privacy band, CTA band. No `scroll` event listener; IO only.

### 5.4 Hover / active micro-states
- Primary button: `opacity .92` hover, `translateY(1px)` active, focus ring `0 0 0 3px --accent-soft`.
- Ghost button: fill `--surface-2` hover, same active/focus.
- Link: underline 35%→100% on hover.
- Feature card: subtle border-strong shift + 1px lift on hover (transform only).
- Nav links: `--muted → --text`.
- Tactile press `120ms`, state transitions `180–220ms`.

### 5.5 Theme transition
- `--dur-theme: 350ms` on surface/text color transitions when toggling Light↔Dark (guarded so it does not fire on initial load / reduced-motion).

### 5.6 Reduced motion
- One `@media (prefers-reduced-motion: reduce)` block: disable `wave`/`pulse`/`rise`, set reveal elements to visible/static, drop transition-delays. Bars rest mid-height, dot at full opacity.

---

## 6. Theming

- `data-theme` on `<html>`: absent = Auto (`prefers-color-scheme`), `"light"`/`"dark"` = manual override.
- Persist manual choice to `localStorage["voxly-signal-theme"]`.
- **FOUC guard:** tiny inline script in `<head>` reads localStorage and sets `data-theme` before first paint.
- Tokens: design system §8.2 CSS variable contract, copied verbatim (light `:root`, auto-dark media block, manual-dark selector).
- One theme per page; no section inversion.

---

## 7. Accessibility

- Contrast pairs already verified in design system §1.2 (AA body, ≥7:1 primary).
- Focus-visible rose ring on every interactive element.
- Semantic `<nav> <main> <section> <footer>`, real `<button>`/`<a>`, `aria-label` on icon-only controls.
- Theme toggle: `role="group"` + `aria-pressed` per segment, keyboard operable.
- Targets ≥40px tall.
- `prefers-reduced-motion` + `prefers-reduced-transparency` honored.
- `<html lang="en">`, meaningful `<title>`, `meta description`.

---

## 8. Deploy pipeline

`.github/workflows/pages.yml`:
- Trigger: `push` to `main` on `site/**` and the workflow file; plus `workflow_dispatch`.
- Permissions: `pages: write`, `id-token: write`.
- Concurrency group `pages`.
- Jobs: `actions/configure-pages` → `actions/upload-pages-artifact` (path `site`) → `actions/deploy-pages`.
- One-time: enable Pages with source = GitHub Actions (via `gh api` PUT `/repos/:owner/:repo/pages` build_type `workflow`, or repo settings).
- Result URL: `https://cengizhankose.github.io/Voxly/`.

---

## 9. Verification

- Serve `site/` locally; visual pass in Light, Dark, and Auto (toggle both OS modes).
- Responsive: 1280×768 (hero fits, CTA above fold), 768, 375.
- `prefers-reduced-motion` emulation: loops/entrance/reveal all static.
- Animation correctness: chip stagger, hero sequence timing, card reveal stagger, hover/active states, theme-toggle transition.
- Anti-slop checklist (design system §11) — every box.
- Post-deploy: hit live URL, confirm assets load (fonts self-hosted, no CDN font requests), CTA links resolve, favicon/OG present.

---

## 10. Risks / notes

- **Fonts:** Satoshi is not on Google Fonts; fetch woff2 from Fontshare at build-authoring time and commit into `site/fonts/`. If a variable woff2 is unavailable, ship static weights (400/500/700/900 sans, 400/500 mono). Strong system fallback stack regardless.
- **Project sub-path:** everything relative; verified no absolute `/` asset paths.
- **No JS framework:** reveal + theme are ~60 lines total vanilla; keep it that way (YAGNI).
- **Model/zip:** unrelated to this page; `dist/` stays gitignored.
