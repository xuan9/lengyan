# ADR 0013: Accessibility Semantics and Automated Checks

Status: accepted

Date: 2026-07-26

## Context

Material components expose baseline accessibility behavior, but the scripture
domain also contains state that was previously visual only: the current volume,
the current outline leaf, section hierarchy, a discrete five-level reader font
setting, and asynchronous search results. Screenshot tests cannot prove that a
screen reader can discover or understand those states.

## Decision

- Keep Material semantics for navigation, tabs, radio choices, icon buttons,
  and sliders. Add custom semantics only for scripture-specific meaning.
- Mark screen titles, settings groups, the product title, and top-level outline
  rows as headings.
- Expose the current outline leaf and resume volume as selected, while retaining
  their visible color treatment. Expose volume rows as buttons.
- Give the five-level font slider a localized name and state description without
  removing its adjustable progress action.
- Announce completed search result counts and empty result/favorite states as
  polite live regions. Keep suggested-search controls at least 48dp high.
- Run Compose's Accessibility Test Framework integration on API 35 across home,
  directory, reader, search, favorites, and settings as part of the existing app
  managed-device suite.
- Retain manual TalkBack, Switch Access, hardware keyboard, and physical-device
  traversal as release gates. Automated checks complement rather than replace
  assistive-technology testing.

## Consequences

The UI now exposes domain state independently of color and can fail CI for
common label, contrast, target-size, and traversal regressions. The additional
test dependency is confined to the Lengyan instrumentation APK and is pinned in
the version catalog, dependency lockfile, and verification metadata; it does not
ship in the production APK.

## Verification

- API 35 device tests assert selected and button semantics for the current
  outline/volume entries, heading semantics for settings, the localized slider
  state, and polite search result announcements.
- Two full-app Accessibility Test Framework workflows cover the six implemented
  screens and pass with zero failures.
- Manual screen-reader and alternative-input verification remains outstanding
  until representative physical phone and tablet hardware is available.
