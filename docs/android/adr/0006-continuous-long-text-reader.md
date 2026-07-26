# ADR 0006: Continuous Long-Text Reader

- Status: Accepted
- Date: 2026-07-26

## Context

The reader must remain legible for future products whose volumes or sections
may exceed the current Lengyan maximum. Pagination introduces device-specific
page boundaries and can hide truncation behind a plausible final page. Shrinking
the scripture font to make a long document cheaper or shorter is unacceptable.

## Decision

- Keep continuous vertical scrolling as the Android reading mode. Do not add
  pagination until product evidence establishes a user need and the paged
  implementation proves contiguous character ranges.
- Always lay out the complete document. Do not use `maxLines`, ellipsis, bitmap
  rendering, or length-dependent font scaling for scripture text.
- Keep the default at 24sp/42sp and allow system font scaling to enlarge it.
  The existing paragraph/code-point anchor remains canonical at every scale.
- Run the reader text itself on the managed API 35 device with a synthetic
  20,000-character CJK document at 100% and 200% system font scale. Verify that
  layout reaches the final UTF-16 offset without width or height overflow and
  that the enclosing reader can scroll to content after the final line.

## Consequences

This Gate proves complete Compose layout and scroll reachability; it does not
claim a frozen launch-time, frame-time, or memory budget. Those numbers require
a reference-device Macrobenchmark before they can become performance Gates.
