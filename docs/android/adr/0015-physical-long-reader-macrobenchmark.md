# ADR 0015: Physical Long-Reader Macrobenchmark

Status: accepted

Date: 2026-07-26

## Context

The managed-device suite proves that a synthetic 20,000-character document is
complete and scrollable at 100% and 200% system font scale. It does not provide
trustworthy frame-time or memory numbers. Emulator load, host contention, and a
debuggable target would make those measurements unsuitable for a release Gate.

The current Traditional Chinese package contains 6,249 to 9,115 Unicode code
points per volume. Volume nine is the longest real packaged volume and therefore
provides a stable production-content path without adding test text to the app.

## Decision

- Add a separate `:benchmark:lengyan` `com.android.test` module. It launches the
  real volume-nine reader through the public product deep link and performs eight
  repeatable vertical scroll gestures over ten iterations.
- Measure `FrameTimingMetric` and maximum `MemoryUsageMetric` under partial
  compilation using AndroidX Macrobenchmark 1.4.1.
- Benchmark a release-derived `benchmark` target that is non-debuggable,
  profileable by shell, and signed with the debug key only for local installation.
  Give it the isolated `org.fuxuan.lengyan.macrobenchmark` application ID, reset
  only that sandbox before a run, and keep the self-instrumenting harness out of
  production APKs. This avoids replacing or clearing an installed user App.
- Make `./verify.sh android` compile both benchmark APKs so dependency and source
  regressions fail normal CI. Execute `./verify.sh android-benchmark` only on a
  selected Android 12 / API 31+ physical device; the script rejects emulators.
- Do not freeze pass/fail thresholds until repeated runs on a named mid-range
  reference device establish a variance envelope. Store that device, OS, thermal
  state, run count, raw JSON, and accepted thresholds with the future baseline.

## Consequences

The repository now has an honest, reproducible measurement path without claiming
that CI emulator results represent users. The normal Gate grows by two APK builds
but does not execute the ten-iteration benchmark. Profile Installer is included in
the target app to support profile-aware compilation and future Baseline Profiles.

The harness currently covers long-volume scrolling, not cold start, search, or
sharing. Those scenarios and a generated Baseline Profile remain Phase 6 work.

## Verification

- Both benchmark variants assemble with dependency locking and verification
  metadata enabled.
- The target APK manifest is non-debuggable and contains
  `profileable enabled="true" shell="true"`.
- The harness APK contains `LongReaderBenchmark` and targets the Lengyan benchmark
  variant through the Android test plugin.
- The physical runner also rejects a non-default system font scale so repeated
  baselines use the same layout input.
- Physical frame-time, jank, and peak-memory values remain outstanding until an
  API 31+ reference device is connected; no emulator number is accepted.
