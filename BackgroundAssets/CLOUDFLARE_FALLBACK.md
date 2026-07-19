# Cloudflare Zero-Overage Audio Fallback

This is an emergency source for the same 11 M4A files delivered primarily by
Apple ODR or Apple-hosted Managed Background Assets. It is intentionally not a
second default source, and silent prefetch never activates it.

## Runtime policy

- A valid fallback file already cached by the app is used immediately.
- An explicit playback request starts with Apple.
- A definitive Apple error switches to Cloudflare immediately.
- If Apple makes no forward progress for 15 seconds, the app cancels that
  request before switching.
- Background next-volume prefetch does not switch to Cloudflare on failure.
- Every downloaded file must match the exact byte count and SHA-256 compiled
  into the app before it is installed.
- Downloads live below Application Support, are excluded from backup, and are
  removed by the existing audio-storage cleanup action.

## Deployed topology

```text
iOS -> HTTPS workers.dev -> Workers Static Assets
```

Production URL:

```text
https://lengyan-audio-fallback.dhyana9.workers.dev
```

Cloudflare version deployed on 2026-07-19:

```text
efde653d-4a39-439b-8a96-2979d4e4b480
```

This is an assets-only project: `wrangler.jsonc` has no `main`, R2 binding,
Worker code, or `run_worker_first` route. Matching files are served directly by
Cloudflare; unknown files return 404 without invoking a Worker. Preview URLs
are disabled.

Cloudflare documents Static Asset requests as free and unlimited and asset
storage as having no additional cost. Every file is below the 25 MiB per-file
limit. R2 is deliberately absent because R2 has usage-priced operations above
its free tier and cannot provide the requested hard zero-overage guarantee.

The app downloads files at:

```text
audio/v1/<sha256>/<asset-id>.m4a
```

Content-addressed URLs must never be overwritten. A changed audio file gets a
new hash path and a new app catalog entry.

## Deploy and verify

Authenticate Wrangler, then run:

```sh
scripts/deploy-cloudflare-audio-fallback.sh
```

The script verifies the source catalog, stages the 11 files in a temporary
directory, asserts that the project has no executable Worker or R2 binding,
and deploys pure Static Assets. It does not commit a duplicate audio set.

Verify the public route:

```sh
scripts/verify-cloudflare-audio-fallback.sh \
  https://lengyan-audio-fallback.dhyana9.workers.dev
```

The verifier downloads all 11 public files and checks HTTPS-only redirects,
read-only behavior, exact byte counts, SHA-256, M4A readability, MIME type,
immutable cache headers, ETag, HEAD, and Range-request safety. Static Assets
currently ignores the Range header and returns the full file with 200; the iOS
fallback already uses complete-file downloads, so an interrupted fallback
download restarts that volume. The largest volume is about 20.1 MiB.

## App activation

The verified production values in `lengyan/Info.plist` are:

```xml
<key>LengyanCDNAudioFallbackEnabled</key>
<true/>
<key>LengyanCDNAudioFallbackBaseURL</key>
<string>https://lengyan-audio-fallback.dhyana9.workers.dev</string>
```

`LengyanCDNAudioFallbackStallTimeoutSeconds` is 15 and runtime-clamped to 5–60
seconds. ATS remains strict and the downloader rejects non-HTTPS redirects.

## Operational notes

- Static Assets billing and limits:
  https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/
- Static Assets per-file limit:
  https://developers.cloudflare.com/workers/platform/limits/#static-assets
- R2 pricing, documenting why R2 is not used here:
  https://developers.cloudflare.com/r2/pricing/
- Cloudflare documents `workers.dev` as a Free website for personal/hobby use,
  not a business-critical endpoint. It remains an emergency source behind
  Apple delivery:
  https://developers.cloudflare.com/workers/configuration/routing/workers-dev/
- Standard Cloudflare delivery is route diversity for Mainland China, not an
  in-China latency guarantee. Cloudflare China Network is a separate
  Enterprise service with ICP requirements:
  https://developers.cloudflare.com/china-network/
