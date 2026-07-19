# Managed Background Assets M0

This directory is an isolated smoke test for the release gate described in
`.planning/APPLE_HOSTED_AUDIO_DUAL_STACK_DESIGN_2026-07.md`. It does not package
or route any production audio.

## Fixed identifiers

- App: `org.fuxuan.lengyan`
- Downloader extension: `org.fuxuan.lengyan.asset-downloader`
- Shared App Group: `group.org.fuxuan.books`
- M0 asset pack: `org.fuxuan.lengyan.m0.smoke`
- Marker file: `M0/managed-assets-smoke.txt`
- Playback file: `M0/managed-assets-smoke.m4a` (1.5-second non-production tone)
- Expected marker: `lengyan-managed-assets-m0-ok-v1`

## 1. Package

```sh
scripts/package-m0-asset-pack.sh
```

The generated `.aar` is written to `BackgroundAssetsM0/Artifacts/` and is not
committed.

## 2. Local device test

Apple requires HTTPS and Developer Mode for the mock server. Package the asset,
then run the server with a certificate identity that the device trusts:

```sh
xcrun ba-serve \
  --host <mac-hostname-reachable-from-device> \
  BackgroundAssetsM0/Artifacts/org.fuxuan.lengyan.m0.smoke.aar
```

On the iOS 26+ device, open Settings > Developer > Development Overrides under
Background Assets Testing and select the server. Install the development build,
then open Settings > M0 Apple 托管资源包 inside the app.

Verify Download, Cancel, Retry, Verify, Play, Stop and Remove. A successful
verification must display the exact marker above, decode the M4A, and complete
playback from the URL returned by `AssetPackManager`.

## 3. Archive structure

```sh
xcodebuild \
  -project lengyan.xcodeproj \
  -scheme lengyan \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/M0/lengyan-m0.xcarchive \
  archive

scripts/verify-m0-archive.sh build/M0/lengyan-m0.xcarchive
```

The verifier proves that one archive contains a minimum-iOS-15 host, an iOS-26
downloader extension, weak `BackgroundAssets` host linkage, and exactly the 11
legacy ODR packs/tags without embedding the M4A files inside the app. For the
signed distribution archive, run the stricter form:

```sh
scripts/verify-m0-archive.sh --require-signed build/M0/lengyan-m0.xcarchive
```

The repository also contains a focused pre-iOS-26 integration test that uses
real `NSBundleResourceRequest` objects for current-track playback and next-track
prefetch:

```sh
xcodebuild \
  -project lengyan.xcodeproj \
  -scheme lengyan \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=<pre-iOS-26-device-udid>' \
  -only-testing:lengyanTests/LegacyODRM0IntegrationTests/testCurrentPlaybackStartsAndNextTrackIsPrefetched \
  test
```

## 4. Validate and TestFlight

After packaging, use an App Store Connect user or API key with Developer or
higher access:

```sh
xcrun altool --upload-asset-pack \
  BackgroundAssetsM0/Artifacts/org.fuxuan.lengyan.m0.smoke.aar \
  --apple-id <numeric-app-apple-id> \
  -u <app-store-connect-user> \
  -p <app-specific-password>
```

Upload the signed archive through Xcode Organizer or Transporter. Do not enable
the production Managed provider after upload; this build exposes only the M0
diagnostic.

Local packaging, simulator launch, or `ba-serve` do not replace this hosted
TestFlight gate. The `.aar` and signed app build must both be uploaded and tested
through App Store Connect.

Required TestFlight evidence:

| System | Required result |
|---|---|
| iOS 15 | Install/launch succeeds; existing ODR current + next behavior works |
| iOS 25 | Install/launch succeeds; existing ODR current + next behavior works |
| iOS 26.0–26.3 | M0 pack downloads, verifies, cancels/retries and removes |
| iOS 26.4+ | Same, through the `requireLatestVersion: false` API branch |
| iOS 27 | Same Managed path; no production ODR dependency |

Record device model, exact OS build, network, pack version, timestamps and the
on-screen event log. M0 passes only after App Store validation and every row
above has authoritative device/TestFlight evidence.
