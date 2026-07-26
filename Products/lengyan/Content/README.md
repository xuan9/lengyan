# Lengyan Migration Content

The JSON files in this directory are deterministic migration artifacts generated
from the existing files under `lengyan/data/`. They are not a replacement for
the current iOS runtime corpus and they are not a newly certified scripture
edition.

Generated files:

- `content-zh-Hant.json`: structured traditional Chinese migration package.
- `content-zh-Hans.json`: structurally identical simplified Chinese package.
- `legacy-path-map.json`: complete mapping for all existing hierarchy nodes,
  including the root and the 1,155 persisted leaf paths.

Do not edit these files directly. Regenerate them with:

```bash
node scripts/generate-lengyan-content.mjs
```

Verify checked-in output and all source/hash/identity constraints with:

```bash
./verify.sh contracts
```

The importer preserves paragraph order and visible text, with only CRLF line
endings normalized to LF. The production chapter map directly resolves 1,133
leaf paths. For each of the other 22 paths, the generator assigns a volume only
when the nearest mapped leaf before and after it are in the same volume. It does
not use the unreliable legacy volume hint; 21 of those hints disagree with the
bounded assignment. The old paths, hints, and neighbor evidence remain in the
generated report for review.

This deterministic structural assignment prevents runtime omission, but it
does not certify the edition or remove the human source/text review Gate.

See `docs/content/LENGYAN_MIGRATION_REPORT_2026-07-26.md` for the evidence and
known limits.
