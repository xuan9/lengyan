# ADR 0002: Android Audio Cache and Delivery Boundary

- Status: Accepted with external host Gate
- Date: 2026-07-26

## Decision

- User-requested current-volume audio may use any connected network after clear
  system feedback. Automatic next-volume prefetch runs only on unmetered
  networks by default.
- Cache the current and next volumes first. Enforce a 192 MiB per-product and
  512 MiB per-application-runtime soft budget, remove unprotected assets after
  28 days of inactivity, and evict least recently used unprotected assets before
  refusing a user request. Independently installed scripture apps remain in
  separate Android sandboxes; this is not a device-wide cross-app quota.
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

The third foundation slice adds stable product/artifact/rendition
`DownloadRequest` and custom-cache keys, an application-scoped
`SimpleCache`/`DownloadManager`
runtime, and an injectable foreground `DownloadService` base. The runtime uses
a no-op cache evictor and one parallel download; eviction decisions remain in
the explicit cache policy rather than being delegated to Media3.

The API 35 harness maps a contract-valid HTTPS URI to a loopback HTTP server
only inside its test data source. The server truncates the first 512 KiB
response, and the subsequent request must carry a non-zero byte range before
the service download can complete. After the server is closed, verification
reads through a `CacheDataSource` with no upstream and accepts only exact cache
spans, Media3 content length, and SHA-256. Missing bytes, an unexpected tail,
and a same-length wrong hash are rejected; hashing on the main thread is also
rejected.

The fourth foundation slice adds a product-neutral integrity coordinator on the
`DownloadManager` application looper. Completed tracked downloads are hashed on
a background executor and become usable only after exact cache verification. A
first invalid result emits a repair event, removes the indexed download and its
cache, waits for `onDownloadRemoved`, and then uses a product-injected enqueuer
to request one replacement. A second invalid result removes the replacement and
ends in a rejected state, preventing an unbounded repair loop. Late verifier
callbacks are generation-checked and ignored after release or untracking.

The API 35 harness serves a same-length corrupt payload before the correct
payload and proves exactly one network repair reaches verified state. A second
case serves corrupt bytes every time and proves the coordinator makes exactly
two body requests, rejects after one repair, removes the DownloadIndex entry,
and leaves zero cached bytes. A verified download removed by the user or a
future cache-policy executor immediately loses its in-memory verified state and
repair budget. All integrity events are asserted on the main application
looper. The service-based Range test remains separate because a
Media3 `DownloadService` and its application-scoped `DownloadManager` are
singletons in production rather than replaceable per test.

The fifth foundation slice stores a versioned reservation/verified state,
product/artifact/rendition contract, expected bytes/SHA-256, and last-access time
in Media3 content metadata. The blocking policy executor is worker-thread-only
and serialized: it reserves full expected bytes, removes stale entries before
LRU pressure, rejects an immutable-contract conflict, and refuses to replace or
deduplicate a currently protected artifact. The Media3 evictor registers on the
DownloadManager application looper, performs index/cache work off that looper,
waits for `onDownloadRemoved`, and returns only after cached bytes are gone.

API 35 recreates `SimpleCache` around a real cache span and restores the exact
verified record. A second device case admits a resource, downloads and verifies
it, advances to the 28-day boundary, and proves one maintenance operation clears
the DownloadIndex entry, cache spans, and policy metadata. Media3 intentionally
drops metadata-only entries that have no cache span during reconstruction; a
zero-byte queued download must therefore be rebuilt from the catalog and
DownloadIndex by the still-open process-recovery coordinator.

The sixth foundation slice keeps the global Media3 requirement at `NETWORK` and
applies automatic-prefetch policy with an application-owned, per-request stop
reason. A schema-v1 marker in `DownloadRequest.data` distinguishes user playback
from automatic next-volume prefetch across runtime recreation. Metered or offline
prefetch requests are retained in `STATE_STOPPED`; provider- or user-disabled new
prefetches are not created. Policy reevaluation only clears its own stop reason,
preserves another subsystem's reason, and never applies the unmetered restriction
to a user-owned task. Construction requires an initial policy snapshot so restored
downloads are reconciled while Media3 is still paused, before product code resumes
the manager.

Promotion rewrites the same request as user playback and preserves its cache key
and cached spans. User ownership is monotonic in memory so a late prefetch
callback cannot demote or stop a promoted request. Integrity repair also carries
the latest purpose through its product-injected reenqueue boundary. On API 35, a
metered prefetch made zero HTTP body requests and cached zero bytes, retained its
purpose and stop reason after the Media3 runtime was released and recreated, then
completed with one body request after user promotion. This is runtime-recreation
evidence, not an OS process-kill claim.

The seventh foundation slice adds worker-only startup reconciliation while
DownloadManager is initialized, idle, and still paused. It reads every persisted
DownloadIndex request, requires an exact current catalog contract and known
schema-v1 or legacy-user purpose, and treats removing/restarting or duplicate
entries as unresolved. Valid active tasks are temporarily protected as a set
while their missing reservations are readmitted through the cache budget
executor. Existing records keep their last-access time so app launch cannot
postpone the 28-day expiry boundary. Any index, contract, metadata, or admission issue makes
`readyToResume=false`; catalog validation issues cause no partial metadata write
or LRU eviction. Reconciliation never calls `resumeDownloads`.

On API 35, a metered stopped prefetch first had a zero-byte `RESERVED` record.
Deleting the cache directory during runtime recreation removed that metadata but
left the DownloadIndex marker and stop reason. Startup reconciliation restored
the exact reservation from the catalog while paused, after which resuming the
manager still produced zero HTTP requests and zero cached bytes. This remains
runtime-recreation evidence, not an OS process-kill claim.

The eighth foundation slice closes the reusable startup composition boundary.
A single-use application-looper coordinator schedules reconciliation on a worker,
revalidates that DownloadManager remains initialized and paused, then atomically
registers every restored task with the integrity coordinator before calling
`resumeDownloads`. The initial reconciler construction still requires an idle
manager; activation does not require a second idle edge because reconciliation
may itself complete a cache eviction. Registration preflights the complete batch before changing
integrity state; persisted completed downloads explicitly begin cache-only
bytes/SHA-256 verification because their historical completion callback will not
be replayed. Reconciliation, registration, scheduling, and resume failures are
typed and fail closed. Releasing the coordinator while worker reconciliation is
pending suppresses its late result and cannot resume downloads.

On API 35, the stopped metered-prefetch fixture now activates through this full
coordinator and remains at zero HTTP requests and zero bytes. A second fixture
downloads valid content once, recreates Media3 without deleting its cache or
DownloadIndex, and proves startup activation registers and starts verification
of the already completed file before resume; verification then completes without
another request or last-access refresh. A
third fixture releases activation before its queued reconciliation runs and
proves no callback and no resume. JVM tests cover atomic catalog/transfer batch
validation. This is still runtime recreation, not OS process-death evidence.

The reusable composition sequence and completed-download startup integrity
registration are now complete. Formal product instantiation remains disabled
while Lengyan delivery is `planned`; live connectivity/preference observation,
cache-backed playback, playback-position persistence, complete process-death
recovery evidence, a measured production host, format selection, and Android
redistribution approval remain open Phase 4 work.
