# ADR 0016: Delayed Paginated Share Export

Status: accepted

Date: 2026-07-26

## Context

Opening an iOS share preview previously exposed several failure modes that the
Android port must not repeat: doing long-text image work before the page appears,
blank previews for very tall images, centered scripture body text, excessive
leading or trailing whitespace, shrinking the font to fit, and opaque default
file names. A 20,000-character source also cannot safely become one unbounded
bitmap on every API 26+ device.

The Android implementation must preserve unrestricted plain-text sharing while
giving image export a deterministic memory, attachment-count, and file-size
budget. Product scripture remains in shared `Products/` content; tests must not
copy canonical passages into Kotlin fixtures.

## Decision

- Navigate with only the stable volume ID. Build a lightweight Compose text
  preview immediately and do no bitmap or full-image layout work on entry.
- Start image planning and encoding only after the user selects image sharing.
  Run it on a worker dispatcher, report page progress, support cancellation, and
  delete a partial generation after cancellation or failure.
- Use a 1080px-wide, opaque JPEG at quality 90. Cap each page at 13,500px high,
  below the 16K texture boundary used for visual compatibility checks. Render
  with `RGB_565`, so one maximum page has a 29.2 MB allocation budget rather
  than a 58.3 MB `ARGB_8888` allocation.
- Derive body font size and line height from the same five-level reader
  typography. Map the canonical 393dp reading width to 1080px, never reduce the
  selected level because the source is long, and keep body text left aligned.
- Give every page fixed compact header/footer margins. Let short and final pages
  contract to their measured content with an 810px minimum instead of padding
  them to 13,500px.
- Hold and encode only the current page bitmap. Keep successful files in the
  private cache behind `FileProvider`, retain at least the two newest exports,
  and prune expired or over-budget cache directories.
- Share one image with `ACTION_SEND` and multiple pages with
  `ACTION_SEND_MULTIPLE`. Always retain unrestricted `text/plain`, UTF-8 `.txt`
  document creation, and clipboard alternatives for receivers with attachment
  limits.
- Use scripture/volume-based visible names with padded page numbers. Dates,
  times, UUIDs, and the word `text` are excluded from user-facing names; a UUID
  may appear only in the private parent cache directory to prevent collisions.

The managed-device regression budgets are:

| Source length | Maximum pages | Maximum JPEG total |
|---:|---:|---:|
| 1,800 characters | 2 | 4 MiB |
| 9,000 characters | 9 | 18 MiB |
| 20,000 characters | 20 | 40 MiB |

These are output invariants, not performance claims for physical devices.

## Consequences

Nine thousand characters remain practical as a multi-image export without
reducing readability. Twenty thousand characters produce more attachments, but
the app remains responsive and offers complete text/file fallbacks. The total
encoded bytes scale with source length, while peak app bitmap memory stays
bounded by one page.

`RGB_565` is appropriate because the card is opaque and uses flat colors. Any
future gradients, photographs, transparency, canvas-width change, font change,
or JPEG-quality change requires new pixel inspection and budget measurements.
The app may still encounter receiver-specific attachment limits, which is why
image export cannot replace text sharing.

## Verification

On the pinned API 35 AOSP ATD arm64 compact profile, using the real Traditional
Chinese volume-nine content as the paragraph-density source:

| Source length | Pages | Total pixels | JPEG total | Export time | Peak page bitmap |
|---:|---:|---:|---:|---:|---:|
| 1,800 | 2 | 24,912,360 | 2.50 MiB | 195 ms | 27.71 MiB |
| 9,000 | 9 | 118,893,960 | 12.64 MiB | 665 ms | 27.71 MiB |
| 20,000 | 19 | 264,526,560 | 28.06 MiB | 1,303 ms | 27.71 MiB |

Instrumentation reconstructs every page range to prove no loss or overlap,
checks the shared reader font metrics, JPEG signature/dimensions, semantic
`FileProvider` display name, cache cleanup after cancellation, page counts, and
file-size budgets. An API 36 emulator also generated and decoded first, middle,
and final pages; the full pages were crisp and nonblank, and the final page
contracted to 1080 x 2487px. Compose tests and committed screenshots cover
immediate preview, all four actions, dark mode, and 200% system font scale.

API 26, API 33, named physical devices, and target OEM/receiver combinations
remain Gate F work. Emulator timings are retained as regression evidence only.
