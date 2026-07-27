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

The second foundation slice pins Media3 1.10.1 and adds a product-neutral
`MediaSessionService` base. The service owns its `Player` and `MediaSession`,
accepts same-package or trusted controllers, and replaces every controller
supplied URI, title, and MIME type with values reconstructed from the resolved
artifact catalog. A queue containing any unknown artifact ID is rejected as a
unit instead of partially accepting untrusted input.

The service is exercised through a separate API 35 harness app that owns the
test-only foreground-service permissions. Lengyan's planned Android app no
longer depends on the media module, declares neither `INTERNET` nor
`FOREGROUND_SERVICE_MEDIA_PLAYBACK`, and registers no media service. The public
Android Gate inspects the release APK to preserve that boundary. Media3 is
therefore also absent from Lengyan's generated runtime notices until the app
actually ships it.

The first device run exposed Android ICU rejecting escaped literal braces in
two Apple delivery-template regular expressions even though desktop JVM tests
accepted them. The patterns now use portable brace character classes, and the
Media3 harness constructs the delivery provider on-device as regression
coverage.

Resumable `DownloadManager` integration, cached-byte SHA-256 verification,
playback persistence, a measured production host, format selection, and Android
redistribution approval remain open Phase 4 work. No audio entry is shown while
Lengyan delivery remains `planned`.
