# Multi-Product Feedback Contract

Status: implemented and locally verified; production migration, deployment,
privacy approval, and new-product activation remain human gates

Date: 2026-07-27

## Purpose

The feedback endpoint began as a Lengyan-only service. A shared endpoint cannot
infer product ownership from App version text, feedback content, bundle ID, an
Origin header, or administrator assumptions. Every current client must send a
stable product ID, and the service must reject explicit IDs that have not been
activated through code review.

## Public Submission Contract

The JSON body contains exactly the data the current client intends to retain:

```json
{
  "productID": "lengyan",
  "appVersion": "2.1",
  "content": "User-entered feedback"
}
```

- `productID` follows the shared product-contract pattern and is at most 64
  ASCII characters. It identifies the App, not the user.
- `appVersion` is the public marketing version, capped at 50 characters.
- `content` is trimmed, limited to 2,000 Unicode grapheme clusters and 64 KiB
  UTF-8, and is the only user-authored field retained.
- Device identifiers, model, OS version, build number, reading state and other
  diagnostics are ignored and structurally absent from the final D1 schema.
- A successful response returns only `ok` and a random 32-hex reference.

The iOS success screen retains that reference for the view lifetime, displays
it as two readable 16-character lines and provides an explicit copy action. It
does not persist the reference automatically. This makes the documented early
deletion request possible without expanding server-side identity collection.

The active Worker registry contains only `lengyan`. A schema-shaped but inactive
ID such as `jingang` receives HTTP 400 and is not written. Activating a future
product is a reviewed service release, not a client-controlled operation.

## Legacy Compatibility

Previously released Lengyan clients and the existing support form omit
`productID`. Because this endpoint historically served exactly one product, an
absent field is classified as `lengyan`. An explicit malformed, blank, null or
inactive value is rejected; it never falls back.

The Worker records this policy as `ACCEPT_LEGACY_MISSING_PRODUCT_ID`; disabling
it requires an approved support window proving old App and web submissions no
longer depend on the compatibility path.

This compatibility rule is temporary legacy behavior, not a template for new
products. Every new client must send its approved product ID from its thin app
configuration before launch.

## Storage And Administration

Migration `0006_add_feedback_product_id.sql` additively creates a constrained,
non-null `product_id` column with a `lengyan` default and a product/read/time
index. It preserves existing rows and remains compatible with the prior Worker
during a migration-first rollout. Executable Node tests apply migrations
`0000` through `0006`, preserve a pre-migration row, exercise constraints, and
compare the resulting columns and indexes with `server/schema.sql`.

The Worker always writes `product_id` explicitly. Authenticated list responses
include `productID`; the administrator page labels each row and can issue a
parameterized allowlisted product filter. Random-reference lookup remains
global because references are unique.

Retention remains unchanged: active rows are deleted after 21 days, with the
documented D1 recovery-history margin keeping the public maximum below 30 days
under the currently approved infrastructure assumptions.

## Platform State

- Lengyan iOS reads `ClassicProductID=lengyan` from its own Info.plist, validates
  it against the shared ID shape, and explicitly includes it in every new
  feedback request. Missing or invalid local configuration fails closed.
- Android still has no feedback implementation and declares no `INTERNET`
  permission. This contract does not authorize adding either one without the
  Android privacy, network-security, UI and Data safety work.

## Production Sequence

The repository changes do not migrate or deploy production. During a separately
approved window, operators must first publish the approved privacy disclosures,
then bookmark D1, confirm `0006` is the only pending migration, apply and inspect
it, deploy the matching Worker and create only one labelled test row. The prior
Worker can be restored without removing the additive column. Detailed commands
and rollback controls live in `server/README.md`.

Before another product is activated, approve its permanent product ID, add it
to the Worker registry and admin labels, ship an explicit client payload,
update privacy disclosures, and run Node plus affected platform gates. Product
identity, privacy compliance and production deployment remain human approvals.

## Verification Record

- Node 22.17.1: 18 Worker/schema/migration tests passed.
- Wrangler 4.114.0: migrations `0000` through `0006` applied to a fresh local
  D1; `product_id` was non-null with the expected default and index.
- Wrangler dry run bundled the Worker with D1 and all four rate-limit bindings;
  no deployment occurred.
- Xcode 26.6/iOS 26.5 Simulator: 116 unit tests executed, one real hosted-asset
  environment test skipped as expected, zero failures.
