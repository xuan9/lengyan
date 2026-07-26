# Shared Behavior Adapter - 2026-07-26

## Scope

This milestone turns migration-sensitive Lengyan behavior into executable,
cross-platform contracts. It does not replace the existing reader, player,
favorites UI, or persistence format. The current iOS implementation remains
the reference adapter; Android must produce the same outcomes from the same
JSON cases without translating Swift implementation details.

## Covered Behavior

| Fixture | Locked outcome |
|---|---|
| `audio-start-decision.json` | Same artifact resumes at a positive saved time; another artifact starts at zero |
| `share-file-name.json` | Readable localized JPEG/TXT names, pagination suffixes, no date/time, and no default `text` |
| `deep-link.json` | Existing `lengyan://verse?path=...` acceptance and rejection rules |
| `search-text.json` | Traditional/Simplified matching, original-script snippets, line-break cleanup, and source path retention |
| `daily-verse-selection.json` | Gregorian local-date selection across time zones, content-version rotation, deduplication, and last-read exclusion |
| `reading-resume.json` | Chapter bounds, offset/page normalization, exact outline path, and root rejection |
| `legacy-favorites-migration.json` | Curated-item removal from old storage, stable first-occurrence order, new-key precedence, and unresolved favorite retention |
| `legacy-location-resolution.json` | Exact old path to stable section/paragraph mapping, root rejection, and no guessing for unknown paths |

`lengyanTests/BehaviorContractTests.swift` reads every fixture from the same
checkout and invokes production Swift policies. The Node validator independently
checks deterministic outputs and verifies location fixtures against the full
1,669-entry generated legacy map.

## Daily Verse Compatibility

Previously, an unscheduled date used `timeIntervalSince1970 / 86400`. Near
local midnight, one displayed calendar date could therefore select two paths
depending on whether UTC had crossed midnight. New selections use a Gregorian
local date in an explicit time zone plus a stable FNV-1a offset derived from
product and content version. The pool still rotates one position per local day,
deduplicates entries, and avoids the last-read path when another choice exists.

The provider still checks `DailyVerseSchedule` first. A date already scheduled
by an installed app is returned unchanged, so this correction does not rewrite
an existing user's current or precomputed Widget schedule. Legacy date keys
produced by the existing platform formatter are also recognized and copied to
the canonical local-date key without changing the selected path; Widget
payload date strings retain their existing platform format for upgrade safety.

## Boundaries

- Search normalization still uses the production Foundation Hans/Hant transform;
  Android must prove equivalent fixture output with its selected converter.
- Existing iOS favorites and reading progress continue to store legacy paths.
  The stable resolver is proven before a later, separately reversible storage
  migration; unknown favorites remain recoverable instead of being dropped.
- Fixture parity proves behavior compatibility, not authoritative scripture or
  reuse rights. Those release gates remain blocked where the source manifests
  say so.

## Verification

- Node 22.17.1 `./verify.sh node`: 25 contract/migration tests passed; all 8
  fixture files, 1,669 legacy mappings, audio compatibility outputs, Cloudflare
  catalogs, and feedback Worker checks passed.
- Xcode 26.6 on iPhone 17 / iOS 26.5 Simulator: 114 tests total, 113 passed,
  1 existing real-ODR integration test skipped, and 0 failed. The 10
  `BehaviorContractTests` all passed.
- Release device build: host App, Widget, and Asset Downloader Extension built
  successfully with code signing disabled for local verification.
