# ADR 0004: Product-Isolated User Persistence

- Status: Accepted
- Date: 2026-07-26

## Context

Each scripture is a standalone app, but Android screens need the same typed
settings, stable reading progress, and favorite behavior. Read-only scripture
content must remain in validated packaged assets. Device page numbers are not
stable across width, font scale, or app upgrades, and user data from one
scripture must never appear in another product.

## Decision

- Use DataStore Preferences 1.2.1 behind `UserPreferencesRepository` for theme,
  script locale, font level, reading mode, reminders, audio preferences, stable
  paragraph progress, audio progress, and expanded section IDs.
- Use Room 2.8.4 behind `FavoriteRepository` for favorites only. Do not add the
  scripture corpus, notes, or speculative history tables to the first schema.
- Use KSP2 2.3.10 through one build-logic plugin. This is compatible with the
  AGP 9 built-in Kotlin setup and avoids loading the Kotlin Gradle plugin in
  separate project classloaders.
- Name files `classics-<productID>.preferences_pb` and
  `classics-<productID>.db`. Domain rows still include product and edition IDs
  so accidental cross-product writes fail at repository boundaries.
- Persist reading position as `productID + editionID + paragraphID + character
  offset + mode`; never persist a device page number as the canonical location.
- Keep unresolved legacy favorites with their original path. A later content
  map can recover them instead of silently discarding user intent.
- Export and commit every Room schema. Version 1 is the first Android release
  origin, so no fictional version 0-to-1 migration is created. The next schema
  change must retain v1, add an explicit or auto migration, and run the full
  migration chain against populated fixtures.
- Keep Android cloud backup and device transfer disabled under ADR 0001.

## Verification

- JVM behavior tests run the shared legacy-favorites fixture through the
  production importer and Lengyan path map.
- Managed-device tests write and read all typed DataStore values, exercise Room
  ordering and reopen a file database, and use `MigrationTestHelper` to create
  the committed v1 schema populated from the shared legacy fixture before
  production Room validates and reads it.
- Dependency locks and SHA-256 verification metadata cover DataStore, Room,
  KSP, SQLite, and their transitive artifacts.

## Consequences

The UI only sees domain repositories, and future product modules can obtain an
isolated persistence pair from the same factory. A schema change is deliberately
more work than editing an entity because preserving released user favorites is
a release requirement.
