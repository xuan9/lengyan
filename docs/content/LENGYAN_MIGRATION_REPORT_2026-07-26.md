# Lengyan Reversible Migration Report - 2026-07-26

## Scope

This migration creates a platform-neutral, generated copy of the production
Lengyan JSON corpus. It does not change `lengyan/data/`, the iOS loading path,
the visible reading experience, persisted outline paths, audio IDs, Widgets, or
deep links. The generated packages remain `legacy-migration` and release blocked
because the repository has no verified edition source or recorded rights basis.

## Deterministic Result

| Item | Result |
|---|---:|
| Hierarchy nodes, including root | 1,669 |
| Leaf content paths | 1,155 |
| Paragraphs per locale | 1,262 |
| Paths resolved directly by production chapter map | 1,133 |
| Paths assigned by bounded same-volume neighbors | 22 |
| Paths with unresolved volume | 0 |
| CRLF sequences changed to LF per locale | 288 |

Generated artifact byte sizes and file hashes:

| Artifact | Bytes | File SHA-256 |
|---|---:|---|
| `content-zh-Hant.json` | 1,639,547 | `2d3c88cb4355c6bc67b0e8172eaf98744e2beb91cae63a9c01135965b62e91c9` |
| `content-zh-Hans.json` | 1,671,898 | `cd7a08114b8015a8f64737a76089a067aa090d8837fdd98ad8b96bed9bbf9050` |
| `legacy-path-map.json` | 611,525 | `d48e7a2c3d856b451c43b859e5269f95f4f8b9aa171b3cc2e6c5f5ee5e7cb201` |

Canonical object hashes embedded in the artifacts:

- Traditional package: `1b2fe086bc8cc0a7a577e59cf2c721d83e3fbf14d55fc0ef0cf9f1d4923c948a`
- Simplified package: `294c679ba78c2f3b389ae987dde1575372c93baeab540a9f3e221f4742789c21`
- Legacy path map: `3f8b7c959ff28f0636fbe84811127db7ccecfba75ee812cc8baf4c79edb9cd0f`

Every traditional and simplified paragraph is checked against its corresponding
source entry after only `CRLF -> LF`. Tests also require both locales to have
identical stable section, paragraph, volume, order, and legacy-path structure.
The complete path map covers all 1,669 hierarchy nodes and records direct and
descendant paragraph identities so old navigation can be translated without
discarding the old key.

## Bounded Volume Assignments

The following leaf paths are absent from `lengyanjing-chapter-map.json`. The
generator does not trust `legacyVolumeHint`. It assigns a volume only when the
nearest directly mapped leaf before the path and the nearest directly mapped
leaf after it have the same volume. If either bound is missing or the volumes
differ, generation retains `volumeID: null` and reports the path as unresolved.
All 22 current paths satisfy the bounded rule; 21 old hints disagree.

| Legacy path | Assigned volume | Untrusted hint |
|---|---:|---:|
| `/A2/B1/C2/D1/E2/F2/G3` | 4 | 4 |
| `/A2/B1/C2/D1/E3/F1/G3/H1` | 6 | 4 |
| `/A2/B1/C2/D1/E3/F1/G3/H2` | 6 | 4 |
| `/A2/B1/C2/D2/E1` | 8 | 1 |
| `/A2/B1/C2/D2/E2/F1` | 8 | 1 |
| `/A2/B1/C2/D2/E2/F2` | 8 | 1 |
| `/A2/B1/C2/D2/E2/F3` | 8 | 1 |
| `/A2/B1/C2/D2/E2/F4` | 8 | 1 |
| `/A2/B1/C2/D2/E2/F5` | 8 | 1 |
| `/A2/B1/C2/D2/E2/F6` | 8 | 1 |
| `/A2/B1/C3/D1` | 8 | 1 |
| `/A2/B1/C3/D2` | 8 | 1 |
| `/A2/B1/C3/D3` | 8 | 1 |
| `/A2/B2/C1/D2/E2/F2/G6/H1/I3/J1` | 9 | 8 |
| `/A2/B2/C1/D2/E2/F2/G6/H1/I3/J2/K1` | 9 | 8 |
| `/A2/B2/C1/D2/E2/F2/G6/H1/I3/J2/K2` | 9 | 8 |
| `/A2/B2/C1/D2/E2/F2/G6/H1/I3/J2/K3` | 9 | 8 |
| `/A2/B2/C1/D2/E2/F2/G6/H1/I3/J2/K4` | 9 | 8 |
| `/A2/B2/C1/D2/E2/F2/G6/H1/I3/J3` | 9 | 8 |
| `/A2/B2/C1/D2/E2/F2/G6/H1/I3/J4` | 9 | 8 |
| `/A2/B2/C1/D2/E2/F2/G6/H1/I3/J5` | 9 | 8 |
| `/A2/B2/C1/D2/E4` | 9 | 8 |

The generated report records the exact preceding and following mapped paths for
every assignment. Contract tests require the 1/2/10/9 distribution across
volumes 4/6/8/9, zero unresolved paragraphs, unchanged paragraph text, and
byte-for-byte regeneration.

## Verification And Promotion

`scripts/generate-lengyan-content.mjs --check` reproduces all three files in
memory and compares exact bytes. The independent contract validator then checks
schema, source hashes, stable IDs, locale parity, complete path coverage,
paragraph ancestry, content hashes, and the release gate. Negative tests prove
that a path cannot be removed and hidden behind a recomputed valid map hash.

This migration remains `in-progress`: the iOS app intentionally continues to
read its legacy files. The bounded assignments prevent Android runtime omission
but are not an authoritative edition review. Promotion still requires an
authoritative source/rights review, a reviewed text diff, human review of the
assignment evidence, and native compatibility tests before canonical status.
