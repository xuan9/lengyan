# Repository Instructions

This file is the authoritative operating guide for coding agents and human
contributors. Read it before changing code, content, build configuration, or
release infrastructure.

## Product Model

- This is one monorepo for multiple independent scripture apps.
- Each scripture remains a separate iOS and Android app with its own identity,
  data, Widget, store listing, release cadence, and user storage namespace.
- Platform implementations are native. Share schemas, stable IDs, source data,
  generated artifacts, and behavior fixtures across platforms; do not force UI
  or media runtime code to be cross-platform.
- The current production reference is the Lengyan iOS app. Stabilize and
  preserve its behavior while extracting reusable boundaries incrementally.
- Planned product order is Jingang, Yuanjue, then Tanjing after Lengyan reaches
  the relevant quality gates.

## Authority Order

When documents disagree, use this order:

1. Executable schemas, accepted ADRs, tests, generators, and current code.
2. This `AGENTS.md` file.
3. `.planning/AI_MULTI_PRODUCT_ENGINEERING_PLAN.md` for shared engineering and
   `.planning/ANDROID_MULTI_PRODUCT_PORTING_PLAN.md` for Android details.
4. `.planning/MAHAYANA_PRODUCT_PLANS.md` for product order and scope.
5. Historical reports and notes.

`CLAUDE.md`, `REQUIREMENTS.md`, and planning reports are not build
configuration. Update them when implementation makes a claim stale.

## Required Verification

Run commands from the repository root:

```bash
./verify.sh contracts     # Shared product/content contracts and source hashes
./verify.sh node          # Contracts, audio catalogs, and feedback Worker
./verify.sh ios-unit      # All iOS unit tests
./verify.sh ios-build     # App, Widget, and downloader extension
./verify.sh ios-ui-smoke  # High-risk iPad/theme workflows
./verify.sh ios-archive   # Production archive and dual audio-stack checks
./verify.sh all           # Normal clean-clone gate for the current platform
```

`./verify.sh all` is the public clean-clone contract. Keep CI as a thin caller
of these commands so local and hosted verification cannot drift.

GitLab is the source host: `.gitlab-ci.yml` runs the portable Node gate on
every branch and merge request, and exposes non-blocking manual macOS build and
archive evidence when the project has an eligible hosted macOS runner. The
GitHub workflow runs the full iOS unit, build, UI smoke, and archive matrix when
the repository is mirrored there. A checked-in workflow is not evidence until
its hosted run has completed successfully.

Requirements:

- Node is pinned by `.node-version`; local Node may be newer but must be 22+.
- Product contracts use their own lockfile under `tools/content-validator/`;
  its test and validation commands must need neither Xcode, Gradle, nor network
  access after dependencies have been installed.
- iOS builds require Xcode 26+ because the asset downloader extension targets
  iOS 26 while the host app remains compatible with iOS 15+.
- Set `IOS_DESTINATION` for unit tests or `IOS_UI_DESTINATION` for UI smoke to
  override automatic iPhone/iPad simulator selection.
- Production archive verification requires the tracked source audio and builds
  generated `.aar` files under ignored artifact directories.

Never report a placeholder, echo statement, or unexecuted command as evidence.
Preserve the command, environment, result, and any skipped hardware-only check.

## Scripture And Source Integrity

Canonical scripture is protected data, not ordinary copy:

- Do not generate, paraphrase, silently normalize, or "correct" scripture with
  an AI model.
- Do not add a new scripture corpus until its exact edition, source URI or
  archival identifier, retrieval date, checksum, rights basis, and review
  status are recorded in the source manifest.
- Preserve source variants, punctuation, headings, and omissions explicitly.
  Any editorial transformation needs a deterministic rule and reviewable diff.
- Traditional text is canonical unless a product source decision says
  otherwise. Simplified output must be generated deterministically with a
  reviewed exception map; it is not an independently edited corpus.
- Stable paragraph and structural IDs must survive display-only revisions.
  Migrations must map legacy IDs before old content is removed.
- A schema-valid corpus is not automatically authoritative. Human source and
  rights approval remains a release gate.

## Engineering Boundaries

- Prefer existing UIKit/SwiftUI behavior and provider abstractions over broad
  rewrites. Move code only with regression coverage.
- New domain code must not introduce additional direct dependencies on
  `Book.shared`, `Prefers.shared`, or `AudioManager.shared`; use injectable
  repositories/protocols at new boundaries.
- Keep product differences in typed product/content manifests only when they
  are stable configuration. Product-specific experiences belong in thin app
  modules, not in a universal flag matrix.
- Cross-platform behavior changes must update `Contracts/BehaviorFixtures/`
  and keep both native adapters reading those JSON files directly. Do not copy
  fixture cases into Swift or Kotlin test source.
- Lengyan audio identity lives in `Products/lengyan/audio-artifacts.json`;
  platform routing and repository source paths live in its `Platform/` and
  `Tooling/` contracts. Run the generator in `--check` mode and never edit
  `AudioAssets/audio-manifest.json` or generated Swift, Node, checksum, media,
  or Apple manifest outputs directly.
- Large audio artifacts do not belong in new Git history. Artifact manifests
  carry hashes and rights metadata; platform delivery configuration chooses the
  host and download mechanism.
- Never commit secrets, signing material, provisioning profiles, production
  credentials, `.env` files, Wrangler state, or generated build artifacts.

## Change Discipline

- Inspect the worktree before editing. Do not discard changes you did not make.
- Keep behavior fixes, infrastructure, schema migrations, and content imports
  in separate commits whenever they can be reviewed independently.
- Update tests with behavior changes and validators with contract changes.
- Before committing, run `git diff --check`, inspect the diff, and execute the
  narrowest relevant verification plus the affected gate.
- A release-affecting content or audio change requires source/hash validation,
  both language variants, upgrade/migration checks, and platform-specific
  playback or rendering evidence.

## Current Non-Delegable Gates

Humans retain final approval for scripture/translation accuracy, rights and
licenses, permanent app/package identities, signing keys, privacy and regional
compliance, production infrastructure, and store submission. Agents may prepare
and verify these artifacts but must not fabricate approval or publication.
