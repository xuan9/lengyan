# ADR 0010: Persistent Outline Disclosure State

Status: accepted

Date: 2026-07-26

## Context

The Lengyan hierarchy contains 1,669 sections, reaches depth 19, and has 1,155
readable leaves. A flat list loses the existing iOS navigation behavior, while
using list positions as state would break after a content revision. Android
must preserve disclosure across top-level tab switches and process recreation,
open the exact stable paragraph represented by a leaf, and discard stale state
after a content package update.

## Decision

- Store only expanded stable section IDs in the existing product-isolated
  DataStore preferences. Never store list indexes or localized titles.
- Sanitize persisted state against the loaded content on every package load.
  Unknown IDs and leaf IDs are removed because only current parent nodes can be
  expanded.
- Derive visible rows with a canonical depth-first traversal. Parent taps only
  expand or collapse; leaf taps open the first readable paragraph in that
  subtree and immediately persist its exact paragraph progress.
- Present `科判` and `卷目` as two explicit directory tabs. Keep volume-based
  navigation for users who do not use the hierarchy.
- Cap visual indentation after seven levels while preserving the real depth in
  the row model and canonical traversal. This keeps depth-19 titles readable on
  compact phones.
- Use one stable LazyColumn key per section, expose expanded/collapsed state to
  accessibility services, and allow titles to wrap instead of truncating them.

## Consequences

The Android UI does not copy the UIKit tree implementation, but it preserves
the same user result and consumes the shared stable-ID content contract. A
content update cannot leave invisible or invalid disclosure state behind. The
directory defaults to the outline; the ten-volume list remains one tab away.

Reader pagination remains deferred by ADR 0006, and broader TalkBack traversal
remains separate Gate D work. Tablet split-detail behavior and typed deep links
are covered by ADRs 0012 and 0011 respectively.

## Verification

- JVM policy tests cover canonical partial expansion, invalid/leaf ID removal,
  and all-section uniqueness.
- The real Traditional Chinese package proves all 1,669 sections and all 1,155
  leaves are reached exactly once when every parent is expanded.
- API 35 device tests cover invalid-ID cleanup, tab round-trips, Activity
  recreation, a depth-19 branch, exact leaf-to-paragraph navigation, and return
  to the expanded branch.
- API 36 screenshots cover collapsed, expanded, and two-level outlines plus the
  outline and ten-volume tabs at 100% and 200% system font scale.
- A 320dp Compose test at 200% font scale protects long-title wrapping, tab/list
  separation, disclosure semantics, and leaf actionability.
