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
- Dependency upgrades must update the version catalog, lockfiles, verification
  metadata, ADR evidence when relevant, and pass `./verify.sh android`.

## Verification

Run the public command from the repository root:

```bash
./verify.sh android
./verify.sh android-ui-smoke
```

Do not replace these with a narrower module task in a completion report. The
managed-device command currently verifies the shell, packaged Lengyan contracts,
cross-script search, DataStore, Room, and the Room v1 schema origin. Screenshot
matrices, long-text, audio, and OEM Gates are added as their phases become
implemented; absence of those tasks must not be reported as success.
