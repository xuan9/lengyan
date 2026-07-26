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
- Use stable serializable Navigation 3 keys. Never persist page numbers as a
  cross-device scripture location.
- Dependency upgrades must update the version catalog, lockfiles, verification
  metadata, ADR evidence when relevant, and pass `./verify.sh android`.

## Verification

Run the public command from the repository root:

```bash
./verify.sh android
```

Do not replace this with a narrower module task in a completion report. Managed
device, screenshot, long-text, audio, and OEM Gates are added as their phases
become implemented; absence of those tasks must not be reported as success.
