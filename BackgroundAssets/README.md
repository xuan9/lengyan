# Production Managed Audio Packs

The production catalog contains exactly 11 Apple-hosted `onDemand` packs in
this order:

`ly01 ... ly10, lyz1`

Each pack contains one file at `Audio/<asset-id>.m4a`. The source remains the
existing ODR-tagged file under `lengyan/屏東能淨協會讀誦`; packaging stages a
temporary copy so the repository does not store a second 154 MiB audio set.

Package and verify all packs:

```sh
scripts/package-production-audio-packs.sh
```

Package a subset:

```sh
scripts/package-production-audio-packs.sh ly01 ly02
```

Artifacts are written to `BackgroundAssets/Artifacts/` and ignored by Git.
For App Store submission, upload `ly01`-`ly10` as the first ten-pack batch and
`lyz1` as the second batch. The app router already selects Managed Background
Assets on iOS 26+ and legacy ODR below iOS 26.

After creating an Archive, verify the ODR and Managed sides together:

```sh
scripts/verify-dual-stack-archive.sh /path/to/lengyan.xcarchive
```
