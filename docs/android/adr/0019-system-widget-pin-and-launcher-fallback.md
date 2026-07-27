# ADR 0019: System Widget Pin and Launcher Fallback

Status: accepted

Date: 2026-07-27

## Context

The daily-reading Widget already has shared Glance rendering, stable paragraph
selection, persistence, and navigation. Users still had to discover it through
their launcher, and the settings screen had no Android-native installation
entry. A copied iOS guide or three selectable "styles" would be incorrect:
launcher dimensions control the small, medium, and large layouts, while the app
registers one daily-reading Widget.

Android launchers may support `requestPinAppWidget`, reject a request, or omit
the API entirely. A reusable product host therefore needs one explicit policy
for the system flow, fallback copy, and installed-state refresh.

## Decision

- Keep launcher capability and pin requests in `:libraries:widget`. Every app
  host supplies the explicit Widget receiver component alongside its existing
  container and launch component. Reject a receiver from another package before
  calling system services.
- Expose exactly one settings entry named "今日读经" for the one registered
  Widget. Small, medium, and large launcher frames remain responsive layouts,
  not user-selectable styles. Do not add a third "经文卡片" option.
- Query both the receiver's real `appWidgetIds` and
  `isRequestPinAppWidgetSupported`. When supported, call
  `requestPinAppWidget` and let the launcher own confirmation and placement.
  An existing instance does not disable the row because Android supports adding
  another instance.
- Show the in-app fallback guide only when the launcher does not support pinning,
  returns `false`, or rejects the request with a platform argument/security
  exception. A successfully accepted request that the user later cancels is not
  treated as an error.
- Keep the fallback to three product-localized steps: long-press an empty home
  area, open the system Widget list, then find the product's actual "今日读经"
  Widget and drag it home. Do not claim launcher-specific labels, dimensions, or
  gestures that have not been verified.
- Do not rely on a success `PendingIntent`. Refresh installed state from
  `AppWidgetManager` on Activity resume and when the launcher-owned window gives
  focus back to the app. The displayed state is therefore derived from actual
  host IDs rather than an optimistic callback.

## Consequences

All scripture apps can share the pin policy and settings UI while retaining
their own package, receiver, label, content, and Widget instances. The system
sheet provides the launcher's real preview and placement behavior when
available; unsupported launchers still receive short, truthful instructions.

The installed label means at least one current instance exists. It cannot
identify which home screen contains the instance, and the app cannot know that
an accepted request was later cancelled until launcher state is queried again.
These are platform constraints and do not justify launcher-specific implicit
intents or hidden polling.

## Verification

API 35 instrumentation compares the shared installer's state with the real
`AppWidgetManager`, verifies the product receiver component, and rejects a
cross-package receiver. Compose instrumentation covers the supported,
unsupported, request-failure, already-installed, Traditional/Simplified, and
200% system-font paths; the fallback contains no fictitious "经文卡片" entry.
The real app shell and accessibility checks scroll to the new setting. Two
host-rendered references cover the row at 393dp/100% and 320dp/200% without
clipping or overlap.

On an API 36 AOSP Launcher3 emulator, the setting opened the real system 3x2
preview sheet. Confirming it added the Widget, changed the in-app status to
"已加入，可再次加入", and rendered the installed Widget in the app's Traditional
Chinese preference. API 26, API 33, Samsung and target mainland OEM launchers,
and physical TalkBack/Switch Access remain Gate F work.

## Reconsider When

Revisit the fallback only after verified launchers need materially different
steps, or if Android adds a standard launcher-agnostic Widget-management intent.
Revisit the settings entry if one product intentionally registers multiple
semantically distinct Widgets; responsive sizes alone are not distinct Widgets.
