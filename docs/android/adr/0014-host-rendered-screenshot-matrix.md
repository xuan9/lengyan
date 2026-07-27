# ADR 0014: Host-Rendered Screenshot Matrix

Status: accepted

Date: 2026-07-26

## Context

Semantic and instrumentation tests verify behavior but do not detect visual
regressions such as clipped Chinese text, broken adaptive layouts, incorrect
theme colors, or content colliding with the bottom navigation region. The
product must remain readable at large system font scales on phones, foldables,
and tablets in both Chinese scripts.

## Decision

- Use Android's Compose Preview Screenshot Testing plugin and committed PNG
  references in `:libraries:ui`.
- Keep the experimental plugin inside the existing `build-logic` classpath so
  it resolves against the repository's pinned AGP and Kotlin versions and
  remains compatible with configuration cache.
- Validate 22 pairwise scenarios spanning 320dp, 393dp, 673dp, and 1,000dp
  widths; light and dark themes; 100%, 130%, and 200% system font scales;
  Traditional and Simplified Chinese; and home, reader, directory, favorites,
  settings, its Widget entry, and share-preview screens.
- Use synthetic scripture data that obeys the same domain contracts as packaged
  content. Do not duplicate production scripture text in screenshot fixtures.
- Run `:libraries:ui:validateDebugScreenshotTest` from the public
  `./verify.sh android` gate. Reference changes require visual review and an
  explicit `:libraries:ui:updateDebugScreenshotTest` invocation.

## Consequences

Visual changes now fail CI when rendered pixels differ from reviewed references.
The 22 PNGs add about 1.7 MiB to the repository and no bytes to production APKs.
The Android plugin is experimental, so its pinned version and configuration-cache
behavior must be revalidated before upgrades. Layoutlib rendering complements,
but does not replace, managed-device tests or manual checks on representative
physical hardware.

## Verification

- All 22 references render and validate with zero failures.
- Representative compact/200%, phone/dark, tablet/split, reader, and settings
  images were inspected for clipping, overlap, blank output, and incorrect
  framing.
- Consecutive validation runs succeeded, with the second run reusing the Gradle
  configuration cache.
