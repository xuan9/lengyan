# ADR 0002: Android Audio Cache and Delivery Boundary

- Status: Accepted with external host Gate
- Date: 2026-07-26

## Decision

- User-requested current-volume audio may use any connected network after clear
  system feedback. Automatic next-volume prefetch runs only on unmetered
  networks by default.
- Cache the current and next volumes first. Enforce a 192 MiB per-product and
  512 MiB all-products soft budget, remove unprotected assets after 28 days of
  inactivity, and evict least recently used unprotected assets before refusing
  a user request.
- Do not add a technical storage-management page or a download-all control in
  the first release. Add manual pinning only after user evidence shows the
  automatic model is insufficient.
- Consume `Products/<product>/audio-artifacts.json` for identity, size, codec,
  and SHA-256. Never parse the generated Swift catalog or use Apple delivery
  fields as an Android contract.
- The existing Cloudflare static fallback is a failure-comparison endpoint, not
  the Android primary host, because its current response path does not honor
  byte ranges and has no target-region service commitment.

## External Gate

Before Media3 download implementation is considered release-capable, the
publisher must provision a host that supports HTTPS byte ranges, resumable
downloads, immutable content-addressed keys, target-region measurements, and
operational ownership. The code may implement the provider interface and test
server before a production hostname exists, but plans must not label a host as
selected until those measurements are recorded.

## Implementation Status

As of 2026-07-27, Android parses the typed platform delivery contract and
cross-checks its product, platform state, artifact manifest, selected
rendition, and provider identity against the shared audio catalog. The media
module has deterministic gates for active delivery state, release-ready catalog
and rights, HTTPS base URLs, compatible primary providers, and verified
byte-range support. It also implements the network and 192 MiB/512 MiB/28-day
cache decisions above with JVM tests.

This foundation deliberately does not declare playback/download services or
show an audio entry while Lengyan delivery remains `planned`. Media3 playback,
resumable download integration, a measured production host, format selection,
and Android redistribution approval remain open Phase 4 work.
