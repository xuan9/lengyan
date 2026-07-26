# Lengyan Audio Fallback Static Assets

This assets-only Workers project exposes the immutable audio files declared in
`../Products/lengyan/audio-artifacts.json`. `AudioAssets/audio-manifest.json`,
`src/catalog.mjs`, and the static health contract are generated compatibility
outputs. The project deliberately has no Worker script, R2 bucket, binding, or
`run_worker_first` route. Production uses the free
`lengyan-audio-fallback.dhyana9.workers.dev` HTTPS route until a custom domain
is available.

Cloudflare serves matching assets directly without invoking Worker code;
unknown paths return 404. Static Assets handles HTTPS, caching, `GET`, `HEAD`
and ETag. The platform currently ignores byte-range requests and returns the
complete file with 200. The iOS client independently checks the complete file's
byte count and SHA-256 before installing it.

Cloudflare documents Static Asset requests as free and unlimited, with no
additional asset-storage charge. The 25 MiB per-file ceiling is enforced by a
test; the largest production file is about 20.1 MiB. R2 is intentionally not
used because its free tier can incur usage charges when exceeded.

## Local verification

```sh
node scripts/generate-audio-manifest.mjs --check
node scripts/verify-audio-fallback-catalogs.mjs
node --test CloudflareAudioFallback/tests/*.test.mjs
asset_dir="$(mktemp -d /tmp/lengyan-assets.XXXXXX)"
scripts/stage-cloudflare-audio-fallback.sh "${asset_dir}"
server/node_modules/.bin/wrangler deploy \
  --config CloudflareAudioFallback/wrangler.jsonc \
  --assets "${asset_dir}" \
  --dry-run
```

## Idempotent deployment

Authenticate Wrangler once, then run:

```sh
scripts/deploy-cloudflare-audio-fallback.sh
```

This verifies and stages every canonical source file, reruns catalog/config tests, then
deploys them as pure Static Assets with preview URLs disabled. It never creates
or accesses R2. Verify the public result with:

```sh
scripts/verify-cloudflare-audio-fallback.sh \
  https://lengyan-audio-fallback.dhyana9.workers.dev
```
