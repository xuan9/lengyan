# Lengyan Reference Baseline - 2026-07-26

## Scope

- Clean pre-foundation checkpoint: `bf3d790` (`plan updates`).
- Migration-critical behavior lock: `a687fb8` (`test: lock migration-critical app behavior`).
- Branch: `mutiple-products`.
- Worktree was clean before the behavior-lock change.

The behavior-lock commit makes these migration assumptions executable:

- Outline disclosure state persists across a new `Prefers` instance and a
  collapse remains removed after restart.
- Empty, root, and duplicate outline expansion records do not create invalid
  state.
- CDN fallback files expire after more than 28 days without access, while a
  protected current/pending asset and a 27-day file remain available.
- Cold playback resumes only when the requested audio ID matches the saved ID.
- The AVPlayer callback at time zero cannot overwrite a protected resume seek.

## Local Evidence

Environment:

```text
macOS host
Xcode 26.6 (17F113)
iOS 26.5 Simulator
iPhone 17 Pro
```

Focused regression command:

```bash
xcodebuild test \
  -project lengyan.xcodeproj \
  -scheme lengyan \
  -destination 'platform=iOS Simulator,id=3C157C44-1935-4652-BD1A-8620405D6C31' \
  -derivedDataPath /tmp/lengyan-f0-derived \
  -only-testing:lengyanTests/ReadingResumeStateTests/testExpandedOutlinePathsPersistAcrossRestartAndCollapse \
  -only-testing:lengyanTests/ReadingResumeStateTests/testExpandedOutlinePathsIgnoreRootEmptyAndDuplicateRecords \
  -only-testing:lengyanTests/AudioAssetCoordinatorTests/testFallbackCacheExpiresOnlyUnprotectedFilesUnusedForFourWeeks \
  -only-testing:lengyanTests/lengyanTests/testColdPlaybackResumesOnlyTheSavedAsset \
  -only-testing:lengyanTests/lengyanTests/testColdPlaybackSeekIgnoresInitialZeroProgressCallback
```

Result: 5 executed, 0 failures.

Full unit command used the same project, scheme, destination, and DerivedData
path with `-only-testing:lengyanTests`.

Result: 104 executed, 1 expected Legacy ODR integration skip on iOS 26.5,
0 failures. The test session completed in 62.876 seconds; test execution took
39.214 seconds.

## Foundation 1 Verification Candidate

The repository verification layer built on `a687fb8` was exercised locally
before commit with these public commands:

- `./verify.sh node`: 17 generated audio outputs and 11 source mappings
  matched; 3 fallback catalog tests and 14 feedback Worker tests passed;
  `npm audit --audit-level=high` found 0 vulnerabilities; syntax and Wrangler
  deployment dry-run passed with Wrangler 4.114.0.
- `./verify.sh ios-unit`: 104 tests executed, 1 expected Legacy ODR skip,
  0 failures on iPhone 17 / iOS 26.5.
- `./verify.sh ios-build`: unsigned Release build succeeded for the host App,
  Widget, and iOS 26 asset downloader extension.
- `./verify.sh ios-ui-smoke`: 3 high-risk iPad favorites/layout/theme workflows
  passed on iPad (A16) / iOS 26.5.
- `./verify.sh ios-archive`: all 11 Managed Background Assets packages were
  regenerated; the unsigned production archive and source hashes passed the
  iOS 15-25 ODR / iOS 26+ Managed dual-stack verifier.

The aggregate `./verify.sh all` command then passed from start to finish on the
final candidate worktree. Its unit phase executed the same 104 tests with the
single expected skip, followed by a successful unsigned Release build.

The local host used Node 24.18.0 and Xcode 26.6. The Node gate was also rerun
successfully with the checksum-verified official Node 22.17.1 Darwin archive,
which is the version pinned in hosted CI. Checked-in GitLab and GitHub workflows
have not yet produced a hosted success record for this candidate, so Gate F1
remains open until that evidence and required-check settings exist.

## Release Blockers And Accepted Risks

The simulator result does not close these checks:

- Signed App Store archive validation and association of all 11 Apple-hosted
  packs with a processed build.
- TestFlight and physical-device coverage on both an iOS 15 route and an iOS
  26+ Managed Background Assets route.
- Cancellation, restart, update, low-storage, and CDN failover on physical
  devices in target network regions.
- Cloudflare fallback availability and performance in mainland China; the
  current `workers.dev` endpoint has no regional SLA.
- Privacy text that fully names the Apple/Cloudflare audio request path and the
  feedback Worker data flow.
- Canonical source/provenance manifests for the existing Lengyan corpus and all
  future scriptures. Schema validity alone cannot approve scripture accuracy.

These are release gates or explicitly accepted human risks. Unit tests must not
be used as a substitute for them.
