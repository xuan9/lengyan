# ADR 0005: Stable Volume Reading Layout

- Status: Accepted
- Date: 2026-07-26

## Context

The Lengyan Android text slice must render the same validated content package as
iOS while remaining native to Compose. A pixel scroll offset, rendered page
number, or Kotlin UTF-16 index is not a stable reading location across width,
font scale, script locale, platform, or process recreation.

## Decision

- Present volumes by volume `order`. Assemble each volume by depth-first
  traversal of the stable section tree and each section's paragraph `order`.
  JSON array order is not authoritative.
- Render a volume as continuous selectable text with paragraph separators. The
  default body is 24sp with 42sp line height, left aligned, zero letter spacing,
  and a maximum 760dp reading measure. User and system font scaling may enlarge
  it; layout never shrinks text to fit a viewport.
- Persist `paragraphID + characterOffset`. `characterOffset` counts Unicode code
  points within the paragraph, not UTF-16 code units. Compose UTF-16 layout
  offsets are converted at the UI boundary so supplementary characters remain
  portable to Apple and future platforms.
- Before width or typography reflow, resolve the first visible line to that
  stable anchor. Restore the anchor after layout instead of reusing a pixel
  offset. On activity/process recreation, prefer the latest persisted anchor in
  the same volume over the older navigation payload.
- Keep only 20dp top and 36dp bottom document padding. System bars and the app
  surface own their insets; the reader does not add a second footer inset.

## Verification

- JVM tests use deliberately shuffled paragraph input and a supplementary
  Unicode character to verify deterministic order and UTF-16/code-point
  conversion.
- Managed-device tests open the real first Lengyan volume and move a nonzero
  reading anchor through portrait-landscape-portrait activity recreation.
- Manual API 36 evidence covered 1080x2400 compact portrait, 200% system font,
  1600x2560 at 800dp width, and landscape. Text remained left aligned and no
  content, app-bar, or system-navigation overlap was observed.

## Consequences

Continuous volume reading stays simple and handles the current longest Lengyan
volume (9,115 source characters) without pagination. A future paged mode must
reuse the same paragraph/code-point anchor and prove contiguous character
ranges; it cannot introduce page number as canonical progress.
