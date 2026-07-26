# ADR 0001: Android Toolchain and Product Identity

- Status: Accepted
- Date: 2026-07-26

## Context

The repository must add several native Android scripture products without
rebuilding or forking the working Lengyan iOS product. Android needs one
reproducible baseline that can consume the existing shared contracts while
preserving permanent product identities.

## Decision

- Keep Android in this monorepo and use one Gradle build with thin product apps
  plus `core`, `data`, `ui`, `media`, and `widget` libraries.
- Use publisher namespace `org.fuxuan`, matching the existing signed Apple
  product. The permanent Lengyan Android application ID is
  `org.fuxuan.lengyan`.
- Use JDK 17, Gradle 9.6.1, AGP 9.3.1, Kotlin/Compose compiler 2.3.21,
  Compose BOM 2026.06.01, and Navigation 3 1.1.4.
- Compile against stable API 37.0 because the current Compose line requires API
  37; target API 36 for the current store requirement and keep API 26 as the
  tested minimum.
- Use AGP 9 built-in Kotlin for Android modules. Keep `core` as a Kotlin/JVM
  module and use the Kotlin plugin only there.
- Pin dependencies in one version catalog, lock every resolvable configuration,
  verify downloaded artifacts, and use the checksummed Gradle Wrapper.
- Disable Android cloud backup and device transfer until an explicit export or
  backup product decision updates the privacy contract.

Kotlin 2.4.10 exists, but Android's current Compose setup documentation uses
2.3.21. This baseline keeps the compiler pair that was built and tested here;
Kotlin upgrades are atomic dependency changes, not automatic lint fixes.

## Evidence

- Android Gradle Plugin 9.3 supports API 37, requires Gradle 9.5 or newer, and
  runs on JDK 17: https://developer.android.com/build/releases/agp-9-3-0-release-notes
- AGP 9 built-in Kotlin removes the Android Kotlin plugin from Android modules:
  https://developer.android.com/build/migrate-to-built-in-kotlin
- Compose setup lists BOM 2026.06 and API 37 for the current Compose line:
  https://developer.android.com/develop/ui/compose/setup-compose-dependencies-and-compiler
- Navigation 3 stable routes use serializable `NavKey` values:
  https://developer.android.com/guide/navigation/navigation-3/save-state

## Consequences

The iOS runtime, UI, bundle identity, persistence, and bundled scripture remain
untouched. New Android products can reuse the same libraries, but no new product
app is created until its source and release manifests pass their existing
content and rights Gates.
