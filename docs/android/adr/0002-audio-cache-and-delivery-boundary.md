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
