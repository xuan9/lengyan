# ADR 0017: Persistent Responsive Daily-Verse Widget

Status: accepted

Date: 2026-07-27

## Context

Every scripture product needs a daily-reading Widget without copying product
text or platform logic into each app module. Glance renders through
`RemoteViews`, receives launcher-dependent dimensions, and cannot reuse the
in-app Compose reader. The Widget must also remain useful when product assets or
persistence temporarily fail.

The first implementation selected a verse again on every update. Because the
selection policy excludes the current reading paragraph, tapping the Widget and
saving progress could immediately replace that day's verse. Replacing valid
content with a generic error on a later load failure also violated the planned
snapshot contract.

## Decision

- Keep shared selection, presentation, snapshot, and click-parameter logic in
  `:libraries:widget`. A product app supplies only its `AppContainer`, explicit
  launch component, receiver metadata, strings, and generated content assets.
- Add optional `featuredParagraphIDs` to the product manifest. Contract loading
  validates every ID against every supported locale. Favorites may augment the
  candidate pool, but no scripture body is copied into Kotlin or Widget state.
- On the first update for a local day, use the shared deterministic policy over
  featured and favorite stable IDs while avoiding the current reading paragraph
  when alternatives exist. Persist the chosen ID keyed by product ID, content
  version, and local date. Reading or favorite changes cannot replace it during
  that day as long as the paragraph still exists.
- Persist the last successfully built `DailyVerseWidgetContent` in a separate,
  schema-versioned Preferences DataStore snapshot. A live asset/persistence
  failure displays that snapshot. A generic localized state is used only when no
  valid snapshot exists, and remains clickable into the explicit app activity.
- Use Glance `SizeMode.Responsive` and four internal layout breakpoints for
  launcher frames. Body text remains left aligned at 17-19sp and is clipped on a
  sentence or phrase boundary without splitting Unicode code points. Internal
  breakpoints are layout behavior, not user-selectable Widget styles.
- Pass a stable paragraph action parameter to an explicit component. The app's
  existing typed route resolves it and opens the exact paragraph. No implicit
  intent or product-specific route parsing lives in the Widget library.
- Observe only theme and locale preference changes, and issue updates only when
  at least one Widget is installed. Reading scroll and favorite writes do not
  rebuild `RemoteViews`; system/provider updates handle the date boundary.

## Consequences

All products can reuse one Widget implementation while retaining isolated app
packages and DataStore files. A transient failure intentionally shows the last
valid passage rather than erasing useful content. The stored snapshot contains
display text, but it is only a local fallback derived from the packaged,
validated product asset and is replaced after the next successful load.

The current Widget offers one daily-reading interaction. Pin guidance, reminder
controls, or future actions require separate product and launcher evidence; they
must not be represented as a fictitious third Widget style.

## Verification

JVM tests cover semantic clipping, supplementary Unicode characters, responsive
breakpoints, minimum body sizes, and accessibility punctuation. API 35
instrumentation verifies provider metadata, packaged candidates, same-day
selection after reading-progress changes, snapshot round-trip, explicit exact
paragraph navigation, and real `RemoteViews` composition at 180x110, 196x240,
and 320x320dp.

An API 36 AOSP Launcher3 emulator was also used to add the actual 3x2 Widget.
The launcher reported an approximately 196x240dp host frame; light and dark
rendering remained left aligned and readable, and tapping opened the displayed
volume-nine paragraph. API 26, API 33, Samsung and target mainland OEM
launchers, physical TalkBack/Switch Access, and the settings pin/fallback flow
remain Gate F work.

## Reconsider When

Revisit the state format when one app package hosts multiple simultaneous
products, when users can request a new verse during the same day, or when a
Widget action writes favorites. Revisit the layout breakpoints after measured
launcher frames demonstrate clipping or unusable whitespace on supported OEMs.
