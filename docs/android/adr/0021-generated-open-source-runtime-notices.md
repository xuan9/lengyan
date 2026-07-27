# ADR 0021: Generated Open-Source Runtime Notices

Status: accepted

Date: 2026-07-27

## Context

The repository previously had prose acknowledgments but no complete,
machine-checked inventory of third-party runtime software. Copying dependency
names into each platform would drift as Gradle locks or vendored iOS source
changed. It would also risk presenting scripture, audio, and image provenance
as if it were the same question as software licensing.

Android has a checked-in dependency lockfile. The Lengyan release runtime
currently resolves 147 coordinates, mostly AndroidX modules. iOS has no external
package manager but vendors RATreeView source. The local tree is based on
RATreeView 2.1.2 at revision
`f5370e2df6725e82c5c8de52ffa166bc7810382a`, with compatibility changes in four
files, so claiming an unmodified upstream release would be inaccurate.

## Decision

- Keep one authoritative `ThirdParty/runtime-notices.json` manifest and
  checked-in Apache-2.0 and MIT license texts.
- Parse every `releaseRuntimeClasspath` coordinate from the Lengyan Gradle
  lockfile. Every coordinate must match exactly one declared component group,
  and every declared Android group must match at least one coordinate.
- Preserve every exact coordinate and version in
  `runtime-inventory.generated.json` even though the user-facing page groups
  related modules for readability.
- Record RATreeView as `2.1.2+local`, retain the full upstream revision, and
  hash every regular file in the vendored source tree. Any local source drift
  requires regenerating and reviewing the inventory.
- Generate compact platform JSON documents from the same manifest. Android
  packages its document as a library asset; iOS copies its document into the
  app bundle.
- Add the generator's `--check` mode to `./verify.sh contracts`. Unknown,
  multiply matched, removed, or changed runtime inputs and stale outputs fail
  the public contract gate.
- Expose a separate Open Source Software route under Android Settings. Show
  component versions, module counts, notices, official HTTPS links, and each
  full license text. Keep the page usable at 200% system font.
- Add an explicitly separated open-source software section to the existing iOS
  acknowledgments view, backed by the generated bundle resource and Dynamic
  Type text styles.
- State on both platforms that software notices do not approve scripture,
  audio, or image source and rights claims.
- Introduce no license-display dependency merely to display license data.

## Consequences

A dependency upgrade now produces an auditable lockfile-to-notice diff rather
than relying on memory. Android's 147 runtime modules can be grouped into a
usable page without losing their exact identities, and the iOS local fork is
detectable at file granularity.

The manifest still requires a correct upstream and license classification.
Automation detects omissions and drift but does not provide legal advice or
human release approval. Build/test-only tools, first-party code, content,
media, fonts, and artwork remain separate inventories and release gates.

The current Android input is the Lengyan release lockfile. A future product may
reuse this platform document only when its exact release runtime coordinate set
is identical. Otherwise the generator and app injection boundary must produce
and verify a product-specific notice document before that target can ship.

## Verification

The Node generator validates exact manifest keys, SPDX-shaped identifiers,
HTTPS upstreams, license-text hashes, unique Android mappings, Gradle coordinate
syntax, iOS file hashes, and byte-for-byte generated outputs.

Android tests decode the packaged asset, require eight groups and 147 runtime
modules, navigate the real Settings route, reach the Apache-2.0 text, and cover
the screen at 200% font and through automated accessibility checks. iOS unit
tests load the resource from the built app bundle and verify the RATreeView
version, MIT license, and copyright notice.

## Reconsider When

Revisit generator inputs and platform injection whenever a new product target
is created; reuse requires an exact graph equality check. Also revisit grouping
and presentation when Android gains dynamic feature delivery, iOS adopts Swift
Package Manager, a dependency introduces NOTICE-file obligations or multiple
licenses, or legal review requires additional attribution fields. Do not weaken
the exact inventory merely because the user-facing grouping becomes large.
