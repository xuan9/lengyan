# Production Managed Audio Packs

[`../AudioAssets/audio-manifest.json`](../AudioAssets/audio-manifest.json) is
the only hand-edited source for audio IDs, order, localized titles, integrity
metadata, Apple pack settings, and Cloudflare paths. The production catalog
currently contains 11 Apple-hosted `onDemand` packs; array order in that file
is playback and prefetch order.

Each pack contains one file at `Audio/<asset-id>.m4a`. The source remains the
existing ODR-tagged file under `lengyan/屏東能淨協會讀誦`; packaging stages a
temporary copy so the repository does not store a second 154 MiB audio set.

Package and verify all packs:

```sh
scripts/package-production-audio-packs.sh
```

After editing the canonical manifest, regenerate and check every derived
catalog before packaging:

```sh
scripts/generate-audio-manifest.mjs --write
scripts/generate-audio-manifest.mjs --check
```

The generated Swift catalog is compiled by both the app and downloader
extension. The checksum list, Apple manifests, Cloudflare catalog and health
contract, and both legacy media JSON files are generated as well; don't edit
them directly.

Package a subset:

```sh
scripts/package-production-audio-packs.sh ly01 ly02
```

Artifacts are written to `BackgroundAssets/Artifacts/` and ignored by Git.
For App Store submission, upload the first ten manifest entries as one batch
and the remaining entry as the second batch. The app router already selects
Managed Background Assets on iOS 26+ and legacy ODR below iOS 26.

After creating an Archive, verify the ODR and Managed sides together:

```sh
scripts/verify-dual-stack-archive.sh /path/to/lengyan.xcarchive
```

The optional zero-overage Cloudflare emergency source is documented separately
in [`CLOUDFLARE_FALLBACK.md`](CLOUDFLARE_FALLBACK.md). Its assets-only
`workers.dev` route must pass the public verifier before the production plist
is enabled.
