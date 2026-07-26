# ADR 0011: Legacy Deep-Link Navigation

Status: accepted

Date: 2026-07-26

## Context

The production iOS app and its Widget already publish links in the form
`lengyan://verse?path=...`. Android must accept that contract during both cold
and warm launches without treating an untrusted URL, a legacy hierarchy path,
or a rendered page number as a native navigation destination.

## Decision

- Keep the product scheme and `verse` host in the thin Lengyan app module. The
  shared UI layer receives a typed `ScriptureDeepLink`; it does not parse an
  Android `Intent` or assume a product namespace.
- Parse URLs with the existing shared behavior adapter and reject a different
  scheme, host, product, missing path, or malformed encoding before navigation.
- Resolve the accepted legacy path through `BookRepository` using the generated
  legacy location map. Open only a paragraph that still exists in the loaded
  edition and has a current volume.
- Convert the resolved target to the same stable `paragraphID + code-point
  offset` route and progress record used by search, favorites, and resume.
- Treat the link as an explicit navigation request: switch to the reading root,
  replace any older reader route, assign a newer request timestamp, and consume
  the request once whether it resolves or is rejected.
- Use a `singleTop` Activity so a link received while the app is visible reaches
  `onNewIntent` instead of creating a second task-local copy of the app shell.

## Consequences

Existing Widget and external links remain compatible while Android navigation
stays independent of legacy hierarchy internals. Content revisions can update
the generated legacy map without changing the Activity or Compose routes. Each
future scripture app must declare and parse only its own scheme.

This decision does not introduce a public HTTPS link domain. Adding verified
App Links requires a permanent host and `assetlinks.json`, which remain release
infrastructure decisions rather than assumptions in the client.

## Verification

- The shared deep-link fixture covers accepted, missing, foreign-host, and
  foreign-product URLs through the production parser.
- Kotlin compilation verifies the typed app/UI boundary and the merged manifest
  contains the browsable product intent filter.
- The API 35 managed-device test sends an implicit `ACTION_VIEW` Intent to an
  already running app and verifies that the generated legacy map resolves and
  persists the exact paragraph before the reader appears.
- A separate cold-launch test advances to a newer stable paragraph, recreates
  the Activity, and verifies that the original launch link is not replayed.
