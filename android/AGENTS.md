# Android Agent Guide

This file extends the repository root `AGENTS.md` for work under `android/`.

## Invariants

- Do not copy scripture, manifests, schemas, or behavior cases into Android
  source. Android consumes `Products/` and `Contracts/` through generated build
  outputs or tests that read the shared files directly.
- `org.fuxuan.lengyan` is permanent. Do not upload another package name as a
  placeholder and do not put product switching flags in the Lengyan app.
- Keep `:libraries:core` free of Android, Compose, Room, DataStore, and Media3.
- Product modules are composition roots. Shared screens, repositories, player
  state, and Widget UI belong in their owning library modules.
- Use constructor injection through `AppContainer`; do not add a service
  locator or global mutable singleton.
- Access settings, progress, and favorites only through the core repository
  interfaces. Each product keeps the permanent `classics-<productID>` DataStore
  and Room namespace; never expose Room DAOs or DataStore keys to UI code.
- Commit every Room schema. Once a schema version has shipped, never edit or
  delete its JSON; add and device-test a migration with populated old data.
- Use stable serializable Navigation 3 keys. Never persist page numbers as a
  cross-device scripture location.
- Persist paragraph character offsets as Unicode code-point counts. Convert
  Compose UTF-16 offsets only at the rendering boundary, and preserve the
  anchor across width, font, locale, rotation, and process reflow.
- Dependency upgrades must update the version catalog, lockfiles, verification
  metadata, ADR evidence when relevant, and pass `./verify.sh android`.

## Verification

Run the public command from the repository root:

```bash
./verify.sh android
./verify.sh android-ui-smoke
./verify.sh android-benchmark
```

Do not replace these with a narrower module task in a completion report. The
managed-device command currently verifies the shell, packaged Lengyan contracts,
cross-script search, DataStore, Room, the Room v1 schema origin, the real volume
reader, stable rotation resume, complete 20,000-character layout at default and
200% system font scale, the daily-verse Widget provider/schedule/snapshot/route,
the Widget system-pin/state/fallback flow, the inexact daily-reminder
permission/notification/text-anchor flow, and the Pixel Tablet favorites
split-detail lifecycle.
The Android command also validates 26 host-rendered screenshot references across
compact phone, phone, foldable, and tablet widths; light/dark themes; 100%, 130%,
and 200% font scales; Traditional/Simplified Chinese; and all implemented primary
screens, including source and privacy information. The normal Android Gate also
compiles the release-derived Macrobenchmark target and harness, but compilation
is not a performance result. The benchmark command rejects emulators and API
levels below 31; record quantitative results only from a named physical reference
device. Audio and OEM Gates are added as their phases become implemented; absence
of those results must not be reported as success. The API 35 Media3 harness
proves service/controller lifecycle, contract-only URI resolution, loopback HTTP
Range recovery, cache-only length/SHA-256 rejection, bounded corrupt-download
repair, cache-metadata restoration around real spans, complete expiry removal,
and per-request metered-prefetch stop/runtime restoration/user promotion. It is
not evidence for production hosting, OS process-death recovery, codec support,
or physical-device playback.
