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

The command runs every JVM unit test, Android lint, and both debug and unsigned
release builds. Generated outputs stay under module `build/` directories.

## Modules

- `:apps:lengyan`: permanent application identity and composition root.
- `:libraries:core`: pure JVM domain types and behavior policies.
- `:libraries:data`: Android content and persistence adapters.
- `:libraries:ui`: shared Compose theme, typed routes, and screens.
- `:libraries:media`: Media3 playback and delivery adapters.
- `:libraries:widget`: Glance Widget implementation.

Only `core` and the app composition root contain implementation in the first
scaffold milestone. Empty Android libraries deliberately establish dependency
boundaries before their Phase 2-5 implementations arrive.
