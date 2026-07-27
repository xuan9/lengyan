# Third-Party Runtime Notices

This directory is the repository authority for third-party software shipped in
the current Lengyan iOS and Android application binaries. It is an engineering
inventory, not legal approval for scripture, audio, images, fonts, store copy,
or any future product.

## Scope

- Android coverage is every coordinate in
  `android/apps/lengyan/gradle.lockfile` assigned to
  `releaseRuntimeClasspath`: currently 147 locked modules in eight notice
  groups.
- iOS coverage is the vendored `lengyan/Util/RATreeView` source tree: currently
  31 files derived from RATreeView 2.1.2 at upstream revision
  `f5370e2df6725e82c5c8de52ffa166bc7810382a`, with local compatibility changes.
  Its notice retains the 2013 top-level license copyright and the 2014/2015
  copyright statements present in the upstream source tree.
- Apple system frameworks and build/test-only tools are outside this runtime
  notice inventory because they are not bundled third-party runtime code.
- Product content and media rights remain governed by product source and audio
  manifests plus human release approval.

This gate currently covers the existing Lengyan app targets only. Before a new
product target ships, its exact release runtime graph must either match an
already covered graph byte-for-byte or be added as a product-specific generator
input and platform output. A new product must not silently inherit Lengyan's
notice asset merely because it reuses the shared UI library.

`runtime-notices.json` records component ownership, matching rules, upstream
projects, versions or revisions, notices, and SPDX license identifiers. Full
license texts live in `LicenseTexts/`.

## Generated Files

Run:

```bash
node scripts/generate-third-party-notices.mjs --write
```

The generator writes:

- `ThirdParty/runtime-inventory.generated.json`: exact Android coordinates and
  iOS vendored-file hashes for review and CI auditing.
- `android/libraries/ui/src/main/assets/third-party-notices.json`: the Android
  in-app notice document.
- `lengyan/Resources/third-party-notices.json`: the iOS in-app notice document.

Do not edit generated files directly. `./verify.sh contracts` runs the
generator in `--check` mode and fails when a runtime coordinate is unknown,
matches more than one component, a vendored source file changes, a license text
changes, or a generated output is stale.

## Updating Dependencies

1. Update the dependency lockfile or vendored source in a dedicated dependency
   change.
2. Verify the exact version and license against the official upstream project.
3. Update `runtime-notices.json` and license text only when the upstream terms
   require it.
4. Run the generator with `--write`, then inspect the exact generated inventory
   diff.
5. Run `./verify.sh contracts`, Android verification, and iOS verification for
   every affected platform.

Adding a manifest prefix solely to make the gate pass is not sufficient. The
component identity, official upstream URL, license, bundled version, copyright
notice, and platform scope must all be reviewable.

## Current Upstreams

- [AndroidX](https://github.com/androidx/androidx)
- [Kotlin](https://github.com/JetBrains/kotlin)
- [kotlinx.coroutines](https://github.com/Kotlin/kotlinx.coroutines)
- [kotlinx.serialization](https://github.com/Kotlin/kotlinx.serialization)
- [Okio](https://github.com/square/okio)
- [Guava](https://github.com/google/guava)
- [JetBrains Annotations](https://github.com/JetBrains/java-annotations)
- [JSpecify](https://github.com/jspecify/jspecify)
- [RATreeView](https://github.com/Augustyniak/RATreeView)

The canonical license texts are [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0.txt)
and [MIT](https://opensource.org/license/mit).
