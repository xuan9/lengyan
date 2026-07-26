# ADR 0003: Generate Product-Specific Android Assets

- Status: Accepted
- Date: 2026-07-26

## Context

Android and iOS must consume the same product, book, content, source, legacy-map,
and audio artifact contracts. Copying those files into an Android source set
would create a second editable scripture corpus and allow platform releases to
drift. Packaging every product into every app would also violate the separate
single-scripture product model.

## Decision

Each Android app applies `classics.android.product-assets` and identifies one
directory under the repository-level `Products/` tree. The cacheable
`stageProductAssets` task parses `product.json` and `book-manifest.json`, follows
only runtime references, and writes a product-specific asset tree under the
app's `build/generated/` directory. Android's Variant API wires that directory
into every APK; generated assets are never checked in.

The shared data library uses strict Kotlin serialization DTOs and exposes a
`BookRepository` domain boundary. It recomputes the canonical content SHA-256,
validates stable IDs and cross-manifest identity, performs file IO on an
injected dispatcher, and caches parsed contracts by locale. It does not read
Swift catalogs or package Apple delivery and repository build-input files.

JVM contract tests read `Products/lengyan` directly. Managed-device tests load
the generated assets through the production `Application` container. The Node
schema validator remains the cross-product source and rights Gate; successful
Android parsing does not promote the current `legacy-migration` corpus to an
authoritative edition.

## Consequences

- A scripture has one reviewable content source for both platforms.
- Each standalone APK contains only its own runtime contracts and content.
- Future app modules configure a product ID and directory instead of copying a
  staging task, parser, repository, or scripture files.
- Contract changes must pass Node validation, Android JVM tests, APK assembly,
  and the managed-device asset test.
