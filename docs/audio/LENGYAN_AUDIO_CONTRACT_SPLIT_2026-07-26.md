# Lengyan Audio Contract Split - 2026-07-26

## Scope

This change separates audio identity from platform delivery without changing
the production app. Legacy track IDs (`ly01` through `ly10`, plus `lyz1`),
ordering, M4A bytes, hashes, ODR tags, Managed Background Assets pack IDs,
Cloudflare paths, Swift descriptors, and media-index titles remain unchanged.

## Authority

| File | Responsibility |
|---|---|
| `Products/lengyan/audio-artifacts.json` | Artifact ID, title, rights state, content mapping, rendition metadata, immutable key, bytes, and SHA-256 |
| `Products/lengyan/Platform/ios/audio-delivery.json` | Existing iOS 15-25 ODR, iOS 26+ Managed Background Assets, and emergency HTTPS fallback policy |
| `Products/lengyan/Platform/android/audio-delivery.json` | Explicitly planned Android delivery with unresolved host, rendition, and cache-policy blockers |
| `Products/lengyan/Tooling/audio-input.json` | Repository source directory and paths of generated compatibility outputs |
| `AudioAssets/audio-manifest.json` | Generated legacy projection consumed by existing scripts and native code |

The Android file intentionally has no provider and no selected rendition. The
existing `workers.dev` route is an iOS emergency fallback that does not support
byte ranges and has no target-region SLA; it is not silently promoted to an
Android primary source.

## Artifact Evidence

All 11 checked-in M4A files total 161,420,718 bytes. Their total measured
duration is 29,121,172 milliseconds (about 8 hours 5 minutes). FFprobe 8.1.2
reported HE-AACv2, 22,050 Hz decoded output, and two channels for every file.
The manifest records the RFC 6381 codec value `mp4a.40.29`; durations are the
container duration rounded to the nearest millisecond. File bytes and SHA-256
remain the immutable evidence, so changing a file requires an explicit artifact
revision rather than silently updating metadata.

The ten scripture recitations now map to stable volume IDs
`lengyan.v000001` through `lengyan.v000010`. `lyz1` remains
`legacy-unmapped`: this migration does not guess a canonical paragraph or
volume mapping for the standalone chant.

## Compatibility Proof

The new generator derives the old manifest and all downstream files from the
three separated inputs. Its first `--check` completed with zero changed output.
Key legacy file hashes remained:

- `AudioAssets/audio-manifest.json`: `d464464e965bd41ac472509d13c615342da33610b7bb8489eaa1eec7f5fbd3f9`
- Swift catalog: `2a56fc0e2becccd86912abf5d5213b2a19facf2ba9de59f5255d9f38c305b618`
- Cloudflare catalog: `3b6f85cd5d326c73edd0654f77680748eeeab5408869b5c3d1d65a1f9bf59628`
- Source checksum list: `b382d0b49baa65a60377c1c213e30dff035b1549fa489c6acaf7ad8f3d67c970`
- Traditional media index: `26b71c8d45464c126525c791f694db2f39ec313a6d019b1a9ad74248abef0095`
- Simplified media index: `74eab3c75045d6d84143283d65a66dfc75f2e0bf13a4dbf573ca1dc2d3a78a01`

`./verify.sh audio-catalog` additionally hashes every source M4A and checks all
11 Apple manifests, the Cloudflare route catalog, and generated outputs. The
independent contract validator checks platform/provider compatibility,
rendition availability, stable volume mappings, content-addressed keys, rights
state, and exact legacy projection parity.

## Remaining Release Gates

The repository identifies the performer but contains no written authorization
for reuse in new products or delivery channels. Audio reuse therefore remains
blocked outside the current legacy product context. Android also requires a
range-capable primary host, target-region network evidence, codec/device
benchmark, and approved cache/network policy before its delivery state can move
from `planned`.
