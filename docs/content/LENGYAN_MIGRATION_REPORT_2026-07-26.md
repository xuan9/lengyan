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
| Paths resolved by production chapter map | 1,133 |
| Paths with unresolved volume | 22 |
| CRLF sequences changed to LF per locale | 288 |

Generated artifact byte sizes and file hashes:

| Artifact | Bytes | File SHA-256 |
|---|---:|---|
| `content-zh-Hant.json` | 1,639,261 | `f298b07fe30459448492e40a0872a9f51ba9afb986c9f4be1c23dd18e87a62d7` |
| `content-zh-Hans.json` | 1,671,612 | `b1422087b28d0002b76e2a1b5b1cda049261c57e41bbff52fb2440d5df8c405d` |
| `legacy-path-map.json` | 611,525 | `d48e7a2c3d856b451c43b859e5269f95f4f8b9aa171b3cc2e6c5f5ee5e7cb201` |

Canonical object hashes embedded in the artifacts:

- Traditional package: `29bbc91813ba88ab6dea6b3b3344bcc85671df2f4c1f90771f395645456a5ad0`
- Simplified package: `360f0682c7fc5818f1feec82dd2df7258616afdd8859f671643c5c7a9eb3874f`
- Legacy path map: `3f8b7c959ff28f0636fbe84811127db7ccecfba75ee812cc8baf4c79edb9cd0f`

Every traditional and simplified paragraph is checked against its corresponding
source entry after only `CRLF -> LF`. Tests also require both locales to have
identical stable section, paragraph, volume, order, and legacy-path structure.
The complete path map covers all 1,669 hierarchy nodes and records direct and
descendant paragraph identities so old navigation can be translated without
discarding the old key.

## Unresolved Volume Assignments

The following leaf paths are absent from `lengyanjing-chapter-map.json`. The
importer sets `volumeID` to `null` instead of guessing. `legacyVolumeHint` is
retained from the existing enhanced simplified file as evidence only; several
hints are implausibly `1`, so they are not promoted to assignments.

| Legacy path | Untrusted hint |
|---|---:|
| `/A2/B1/C2/D1/E2/F2/G3` | 4 |
| `/A2/B1/C2/D1/E3/F1/G3/H1` | 4 |
| `/A2/B1/C2/D1/E3/F1/G3/H2` | 4 |
| `/A2/B1/C2/D2/E1` | 1 |
| `/A2/B1/C2/D2/E2/F1` | 1 |
| `/A2/B1/C2/D2/E2/F2` | 1 |
| `/A2/B1/C2/D2/E2/F3` | 1 |
| `/A2/B1/C2/D2/E2/F4` | 1 |
| `/A2/B1/C2/D2/E2/F5` | 1 |
| `/A2/B1/C2/D2/E2/F6` | 1 |
| `/A2/B1/C3/D1` | 1 |
| `/A2/B1/C3/D2` | 1 |
| `/A2/B1/C3/D3` | 1 |
| `/A2/B2/C1/D2/E2/F2/G6/H1/I3/J1` | 8 |
| `/A2/B2/C1/D2/E2/F2/G6/H1/I3/J2/K1` | 8 |
| `/A2/B2/C1/D2/E2/F2/G6/H1/I3/J2/K2` | 8 |
| `/A2/B2/C1/D2/E2/F2/G6/H1/I3/J2/K3` | 8 |
| `/A2/B2/C1/D2/E2/F2/G6/H1/I3/J2/K4` | 8 |
| `/A2/B2/C1/D2/E2/F2/G6/H1/I3/J3` | 8 |
| `/A2/B2/C1/D2/E2/F2/G6/H1/I3/J4` | 8 |
| `/A2/B2/C1/D2/E2/F2/G6/H1/I3/J5` | 8 |
| `/A2/B2/C1/D2/E4` | 8 |

## Verification And Promotion

`scripts/generate-lengyan-content.mjs --check` reproduces all three files in
memory and compares exact bytes. The independent contract validator then checks
schema, source hashes, stable IDs, locale parity, complete path coverage,
paragraph ancestry, content hashes, and the release gate. Negative tests prove
that a path cannot be removed and hidden behind a recomputed valid map hash.

This migration remains `in-progress`: the iOS app intentionally continues to
read its legacy files. Promotion requires an authoritative source/rights review,
a reviewed text diff, decisions for the 22 unresolved volume assignments, and
native compatibility tests before any runtime adapter is enabled.
