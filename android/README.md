# Classics Android

This directory is the native Android workspace for the scripture products in
this monorepo. It does not replace or fork the existing Lengyan iOS app.
Lengyan is the reference product used to prove shared content and behavior
contracts before the other products are enabled.

## Toolchain

- JDK 17
- Gradle Wrapper 9.6.1 with a pinned distribution checksum
- Android Gradle Plugin 9.3.1
- `compileSdk` 37.0, `targetSdk` 36, `minSdk` 26
- Kotlin/Compose compiler 2.3.21
- Compose BOM 2026.06.01 and Navigation 3 1.1.4
- Media3 1.10.1 in the isolated audio runtime boundary

Install the current Android SDK command-line tools plus packages
`platforms;android-37.0` and `build-tools;37.0.0`, set `ANDROID_SDK_ROOT` or
`ANDROID_HOME`, then run from the repository root:

```bash
./verify.sh android
```

The command runs every JVM unit test, Android lint, debug and unsigned release
builds, and compiles the instrumentation APK. Generated outputs stay under
module `build/` directories.

Run `./verify.sh android-ui-smoke` to install and exercise the app on pinned API
35 Gradle-managed compact-phone and Pixel Tablet profiles. The compact profile
runs the full persistence, content, reader, Widget, daily-reminder, Media3
session/download-contract, and shell suite; the tablet profile runs the
adaptive favorites split-detail lifecycle.
This requires the Android Emulator; Gradle provisions the AOSP
automated-test-device image when necessary.

## Modules

- `:apps:lengyan`: permanent application identity and composition root.
- `:libraries:core`: pure JVM domain types and behavior policies.
- `:libraries:data`: Android content and persistence adapters.
- `:libraries:ui`: shared Compose theme, typed routes, and screens.
- `:libraries:media`: Media3 playback and delivery adapters.
- `:libraries:reminder`: inexact daily scheduling and notification delivery.
- `:libraries:widget`: Glance Widget implementation.
- `:testing:media3-harness`: non-product app for service/controller device tests.

The app, `core`, `data`, `ui`, `reminder`, and `widget` modules contain active
production implementation. `media` now contains the contract-backed Media3
catalog, injectable session/download service lifecycles, an application-scoped
download runtime, stable product/artifact/rendition cache keys, and cache-only
length/SHA-256 verification. It also has one-attempt corrupt-download repair and
a persistent, serialized cache-policy executor that waits for Media3 index/cache
removal. The planned Lengyan product does not depend on that module or register
media components. The separate harness owns the network and foreground-service
permissions used by device tests; its loopback server proves non-zero HTTP Range
recovery after an interrupted response, bounded integrity repair, metadata
restoration around real cache spans, and complete 28-day expiry removal. Startup
reconciliation, metered prefetch control, cached playback, playback position, a
measured host, and media rights approval remain Phase 4 work. Shared libraries
remain product-neutral; each app module owns its permanent package identity,
generated product assets, system component registration, and composition root.

The daily-verse Widget uses stable paragraph IDs from the product contract,
locks one selection per local day and content version, and keeps a versioned
DataStore snapshot for offline/error fallback. Its Glance layout is responsive
to launcher-provided dimensions and always opens the product's explicit
activity, targeting the selected paragraph when one is available. Settings
exposes one "今日读经" entry: supported launchers receive the system pin sheet,
while unsupported or rejected requests receive a short product-localized
launcher guide. Installed state is read from the product's real Widget IDs and
refreshed when launcher UI returns focus.

Daily reminders use one-shot inexact `AlarmManager` scheduling. Android 13+
notification permission is requested only when the user enables the setting;
the app never requests exact-alarm permission. Protected system broadcasts
reconcile the next local trigger after reboot, time/time-zone changes, locale
changes, or package replacement. Notification clicks use the saved stable
paragraph ID and Unicode code-point offset.
