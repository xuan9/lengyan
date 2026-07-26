# Scripture Source Baseline - 2026-07-26

This document records evidence gathered for Foundation 2. It is not a content
approval, rights approval, or instruction to replace the production Lengyan
text.

## Production Lengyan Snapshot

The current traditional runtime corpus at reference commit
`bf3d7905c254a7c8d7c19d762a8518a29e44906f` contains:

- 1,155 hierarchy paths.
- 1,262 text entries, all currently tagged `sutra`.
- 76,049 JSON string characters in the traditional content file.
- Existing persisted identities shaped like `/A1/B1/...`.

Its ten traditional/simplified JSON resources are recorded with exact byte
counts and SHA-256 values in `Products/lengyan/source-manifest.json`. Repository
search did not find an edition identifier, transcription source, rights basis,
or completed line-by-line review for those files. They are therefore a locked
production-behavior snapshot with status `legacy-unverified`, not a newly
certified canonical edition.

No Foundation 2 work changes the files under `lengyan/data/` or existing iOS
runtime loading. A future canonical migration must first produce a complete
legacy-path map and an independently reviewed text diff.

## CBETA Reference Snapshot

The official `cbeta-org/xml-p5` repository was pinned at commit
`2b8ab8d5e4fe957a9b94f2cde01cb0d2e2dcd2b9` (`CBETA 2026.R1`) on 2026-07-26.
Each candidate XML parsed successfully with `xmllint --noout` after download
from its commit-pinned raw URL.

| Product | CBETA ID | Source-header attribution | Bytes | SHA-256 |
|---|---|---|---:|---|
| 金剛經 | T0235 | 後秦 鳩摩羅什譯 | 60,229 | `6852f861a314809c935de6e676994226d5a9021f63b88a7e18a6af60768285e9` |
| 圓覺經 | T0842 | 唐 佛陀多羅譯 | 108,117 | `fbf31ed1ac3656d0ecf61f26bc6e4bacc7bd8319be677e7a897ecc20896cbb53` |
| 楞嚴經 | T0945 | 唐 般剌蜜帝譯 | 727,586 | `892d529546811d1be1d6975aaab1a1f8f9045c19e85fa30f92908b2c4bc72967` |
| 六祖壇經 | T2008 | 元 宗寶編 | 343,630 | `af0b463d3f1685972bf22d78ee21da35746c5eacb025ec207ee092cdf4785b9f` |

Attributions above are explicitly labels copied from the XML source headers;
they are not independent historical-authorship determinations.

CBETA's published copyright terms make the database available by default for
noncommercial use and require prior permission for commercial use. The four
snapshots are therefore registered only as `collation-reference`, with
`restricted-noncommercial` rights and `releaseEligibility: blocked`. The XML
files are not committed or imported into canonical app content.

Reference links:

- CBETA XML repository: <https://github.com/cbeta-org/xml-p5>
- CBETA copyright terms: <https://www.cbeta-org-tw.cbeta.org/copyright.htm>
- CBETA XML format notes: <https://archive2.cbeta.org/format/xml.php>

## Required Path To Release

A future product needs one of the following before canonical import:

1. Written permission covering the intended commercial products, platforms,
   territories, updates, and redistribution; or
2. An independently transcribed public-domain scan with immutable scan
   identifiers and page-level source locators, using CBETA only for collation.

After that, a human text reviewer must approve the edition, transcription,
punctuation/segmentation policy, deterministic simplified conversion, and full
diff. Codex may prepare tooling and evidence but may not grant either approval.
