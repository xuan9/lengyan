# ADR 0008: Search Navigation And Resume Priority

Status: accepted

Date: 2026-07-26

## Context

Android search must match traditional and simplified input while displaying the
active locale. A result can identify either a section title or a paragraph. The
reader also has persisted progress, so blindly preferring same-volume progress
would make an explicit search result open at the old location. Blindly
preferring the route forever would instead restore a stale result after the
user had read further and the process was recreated.

## Decision

- Build one immutable index from both locale packages and emit results in the
  canonical section/paragraph reading order.
- Represent a match with a Unicode code-point offset and length. Device UTF-16
  layout offsets are derived only at rendering time.
- Resolve paragraph results to their exact paragraph and match offset. Resolve
  section results to the first readable paragraph in that section subtree.
- Request at most 51 results for the UI, display 50, and disclose when a more
  specific query is needed.
- Give an explicit navigation request a timestamp newer than current persisted
  progress and save its stable anchor when the result opens.
- On reader creation, use the newest eligible same-volume anchor. Progress from
  another volume never overrides the requested destination. After later
  scrolling is saved, that newer progress wins on process recreation.
- Treat the match highlight as transient route presentation state. Persist only
  edition, paragraph ID, code-point offset, mode, and update time.

## Consequences

Search can jump within the current resume volume without being redirected to an
older position. Simplified queries can locate and highlight traditional text
without changing canonical content. Favorites and deep links must reuse the
same anchor-selection policy instead of adding entry-specific precedence rules.

The index remains an in-memory linear scan. The current 2,931 searchable
documents are small enough for this implementation; a different index requires
measured latency or memory evidence and must preserve the same result and anchor
contracts.

## Verification

- JVM tests verify explicit-versus-persisted timestamp ordering and cross-volume
  isolation.
- Real-content tests verify that simplified `转物` resolves to the exact `轉物`
  code-point range, every section leads to readable text, and both scripts use
  stable identities.
- The API 35 managed-device test seeds an old anchor in the same volume, searches
  with simplified input, opens the traditional paragraph, verifies nonzero
  reader scroll, persisted target identity, and a rendered highlight span.
