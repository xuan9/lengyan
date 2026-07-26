# ADR 0012: Adaptive Favorites Split Detail

Status: accepted

Date: 2026-07-26

## Context

The production iOS reference keeps an opened favorite visible on iPad even
when that favorite is removed. Android must preserve that user result on wide
screens without forcing the compact-phone navigation model into a stretched
layout or coupling shared UI to an Activity.

## Decision

- At 720dp or wider, show a fixed 340dp favorites list beside the existing
  volume reader. Below that threshold, keep the established single-pane route.
- Keep selection as a stable favorite ID plus paragraph ID. Resolve the reader
  target from current content rather than persisting a list index or page.
- Give the selected row both a visible theme-derived background and selected
  accessibility semantics.
- If the selected favorite is removed, remove it from the list but retain its
  paragraph detail until the user selects another favorite or leaves the tab.
- Embed the existing reader with its back action hidden. The reading tab keeps
  its independent root and back stack; the detail does not rewrite that stack.
- Keep the app composition root responsible for supplying reader content. The
  reusable favorites screen receives only a typed navigation target and a
  composable detail slot.

## Consequences

Tablet users can scan favorites and read without route churn, while compact
phones retain their existing behavior. Product storage and stable text anchors
remain unchanged. The fixed list width leaves sufficient reader width at the
720dp threshold and allows favorite rows to grow under large system fonts.

## Verification

- Compose device tests cover 480dp compact navigation and 1,000dp split detail
  at 200% font scale, including selected semantics and removal persistence.
- An API 35 Pixel Tablet app test seeds a real Lengyan favorite, opens the live
  reader, removes the selected favorite, verifies that the detail remains, and
  verifies that the independent reading tab still opens its root.
- API 36 Pixel Tablet screenshots were inspected at 100% and 200% system font
  scale for readable text, visible selection, stable panes, and non-overlapping
  bottom navigation.
