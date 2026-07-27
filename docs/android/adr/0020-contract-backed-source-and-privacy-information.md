# ADR 0020: Contract-Backed Source and Privacy Information

Status: accepted

Date: 2026-07-27

## Context

The Android settings screen needed source and privacy information before it
could serve as a trustworthy multi-product shell. Copying the existing iOS
acknowledgment text would be incorrect: the shared Lengyan source manifest says
the current runtime JSON has unverified provenance and rights, while CBETA
T0945 is registered only as a noncommercial collation reference. It is not the
declared source of the current runtime text.

The shared UI also cannot own product URLs, package versions, or Android Intent
handling. At the same time, contract URLs must not become an unrestricted URL
launch surface, and public privacy text must distinguish the current offline
Android implementation from iOS feedback and audio delivery.

## Decision

- Add a pure Kotlin `SourceManifest` domain with typed review, release,
  approval, source-role, format, rights, commercial-use and redistribution
  values. Parse with strict kotlinx serialization and reject unknown fields or
  enum values.
- Make `BookRepository.sourceManifest()` part of the shared repository contract.
  The data implementation caches it, checks product/book/edition identity, and
  rejects content whose source references are absent from the manifest.
- Load the source manifest with the product, book and localized content. The
  settings source page renders that object directly; it contains no copied
  product provenance. A blocked manifest remains visibly pending and an
  eligible label is possible only after the contract's human approvals pass.
- Show source roles explicitly. In particular, label a collation reference as
  "not the current text source". Do not promote CBETA or any other reference to
  a canonical/runtime source through UI copy.
- Give Settings its own Navigation 3 back stack with stable serializable root,
  source and privacy keys. Reselecting the Settings bottom destination returns
  to the settings root, matching the other top-level destinations.
- Keep source/privacy screens and navigation in `:libraries:ui`. The thin app
  module supplies its installed version, optional approved locale-specific
  privacy URLs and the platform external-URI callback. The current Lengyan host
  withholds its external policy URL because the live pages predate the complete
  cross-platform data-flow inventory; the accurate in-app summary remains
  available while publication awaits human approval.
- Permit external navigation only for normalized absolute HTTPS URLs with a
  host and no user information. The app host opens them through a browsable
  `ACTION_VIEW` Intent and treats missing browsers or device restrictions as a
  no-crash condition. Repository-local `repo://` source records remain visible
  as data but are never clickable.
- Describe the current Android behavior in-app: local reading/settings data,
  no ads/analytics/tracking, system-mediated sharing and browser access, no
  cloud backup, and uninstall removal. Maintain the cross-platform technical
  inventory in `docs/privacy/LENGYAN_DATA_FLOW_2026-07-27.md`.
- Defer feedback and open-source license rows until their complete contracts
  exist. This was the boundary when this ADR was accepted; follow-up ADR 0021
  now implements generated runtime notices without changing the source/rights
  meaning of this page.

## Consequences

Every Android scripture product can reuse the navigation and screens while its
manifest and app composition root supply the facts. A source manifest marked
blocked is no longer hidden by legacy acknowledgment prose, but displaying it
does not grant source, rights or privacy approval. Those remain human release
gates.

Loading localized content now also loads the small source manifest and verifies
its referenced source IDs. This is intentional fail-closed behavior for
packaged contract errors. External pages leave the app, so browser/provider
privacy applies after the explicit user action.

## Verification

Core/data unit tests reject unknown enum values, incomplete eligible approvals,
cross-product source manifests, undocumented content references and repeated
manifest reads. Packaged-contract instrumentation reads the generated Lengyan
asset and all four registered product source manifests remain parseable.

API 35 app instrumentation navigates from real Settings, distinguishes current
runtime input from the collation reference, verifies privacy copy, top-bar back
and Settings reselect-to-root behavior. Compose tests cover both information
screens at 200% system font. Accessibility checks include the source records
and verify that the current product does not expose an unapproved policy link.
The reusable privacy screen and its HTTPS action are covered at 200% font and
by four reviewed host-rendered source/privacy references across
compact/phone/tablet layouts at 100%, 130% and 200%, bringing the screenshot
matrix to 26 references.

## Reconsider When

Revisit this ADR when source schema v2 changes approval semantics, Android gains
audio or feedback, or a product needs a product-specific source presentation.
Any new URL scheme or in-app browser requires a separate security and privacy
review. Runtime software notices remain governed by ADR 0021.
