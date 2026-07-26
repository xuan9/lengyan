# Shared Product Contracts

`Contracts/` is the platform-neutral boundary shared by the native iOS and
Android apps. It contains data contracts and behavioral examples only. Swift,
Kotlin, Xcode, Gradle, delivery hosts, bundle identifiers, and signing details
do not belong here.

## Version 1 Files

- `Schemas/product-manifest.schema.json`: stable product capabilities and links
  to the product's other manifests.
- `Schemas/book-manifest.schema.json`: edition, content version, locale, and
  migration state.
- `Schemas/source-manifest.schema.json`: immutable source snapshots, rights,
  accuracy review, and release eligibility.
- `Schemas/content-package.schema.json`: versioned sections, volumes, and
  paragraphs for a legacy migration or an approved release edition.
- `Schemas/legacy-map.schema.json`: complete mapping from persisted Lengyan
  outline paths to stable section and paragraph identities.
- `Schemas/audio-artifact-manifest.schema.json`: product-neutral audio identity,
  content mapping, renditions, checksums, and rights. Delivery is separate.
- `Schemas/behavior-fixture.schema.json`: cross-platform behavior examples.
- `BehaviorFixtures/`: accepted behavior that both native platforms must run.

The independent validator is in `tools/content-validator/` and runs through:

```bash
./verify.sh contracts
```

The Lengyan migration packages and path map are deterministic generated files.
`./verify.sh contracts` regenerates them in memory and rejects any checked-in
file that differs. See `Products/lengyan/Content/README.md` before changing an
input or generated artifact.

## Release Meaning

Schema-valid means structurally consistent; it does not mean authoritative or
licensed. A source can become `releaseEligibility: eligible` only after the
text-accuracy and rights approvals are recorded as approved. Candidate sources
and legacy data with unknown provenance remain blocked even when every checksum
matches.

CBETA snapshots in product source manifests are immutable collation references.
The repository does not contain those XML files or treat them as commercial
release input. CBETA's default database terms restrict commercial use unless
permission is obtained.

Manifest links in `Products/<id>/product.json` and `book-manifest.json` are
relative to that product directory. Repository artifact locators in source
manifests and legacy compatibility/delivery references are repository-root
relative. Both forms reject absolute paths, backslashes, and `..` traversal.

Feature flags describe intended stable product capabilities. A
`source-review` product may declare a future capability such as audio without
an artifact manifest; it cannot enter `development` until required backing
manifests exist and validate.

## Change Rules

1. Additive optional fields may remain schema version 1 when old consumers keep
   the same behavior.
2. A removal, reinterpretation, or new required field needs a new schema version
   and an explicit migration path.
3. Content and source changes remain separate from app code changes.
4. Never mark approvals complete on behalf of a reviewer or rights holder.
5. Never edit canonical scripture with generative AI.
