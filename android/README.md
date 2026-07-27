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

Install Android SDK packages `platforms;android-37.0` and
`build-tools;37.0.0`, set `ANDROID_SDK_ROOT` or `ANDROID_HOME`, then run from
the repository root:

```bash
./verify.sh android
```

The command runs every JVM unit test, Android lint, debug and unsigned release
builds, and compiles the instrumentation APK. Generated outputs stay under
module `build/` directories.

Run `./verify.sh android-ui-smoke` to install and exercise the app on pinned API
35 Gradle-managed compact-phone and Pixel Tablet profiles. The compact profile
runs the full persistence, content, reader, Widget, daily-reminder, and shell
suite; the tablet profile runs the adaptive favorites split-detail lifecycle.
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

The app, `core`, `data`, `ui`, `reminder`, and `widget` modules now contain
production implementation. `media` remains the declared Phase 4 boundary until
the native Media3 service and delivery stack are implemented. Shared libraries
remain product-neutral; each app module owns its permanent package identity,
generated product assets, system component registration, and composition root.

The daily-verse Widget uses stable paragraph IDs from the product contract,
locks one selection per local day and content version, and keeps a versioned
DataStore snapshot for offline/error fallback. Its Glance layout is responsive
to launcher-provided dimensions and always opens the product's explicit
activity, targeting the selected paragraph when one is available.

Daily reminders use one-shot inexact `AlarmManager` scheduling. Android 13+
notification permission is requested only when the user enables the setting;
the app never requests exact-alarm permission. Protected system broadcasts
reconcile the next local trigger after reboot, time/time-zone changes, locale
changes, or package replacement. Notification clicks use the saved stable
paragraph ID and Unicode code-point offset.
