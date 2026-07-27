# ADR 0018: Inexact Daily Reading Reminder

Status: accepted

Date: 2026-07-27

## Context

Every scripture product needs an optional local daily reminder without requiring
Google Play Services, exact-alarm access, copied scripture text, or a second set
of navigation rules. The reminder must follow local wall-clock time through
daylight-saving changes, survive ordinary process death and device reboot, and
respect Android 13+ notification permission. It must not request permission on
first launch.

The existing shared preference contract already stores an enabled flag, hour,
minute, locale, and a stable reading position. Android had no system scheduler,
notification channel, or settings controls consuming that contract.

## Decision

- Keep scheduling and notification delivery in the product-neutral
  `:libraries:reminder` module. A product app supplies its `AppContainer`,
  localized resources, small icon, explicit receiver component, notification
  identity, and explicit activity Intent.
- Schedule only the next local occurrence with
  `AlarmManager.setAndAllowWhileIdle`. This is a one-shot inexact alarm. After a
  trigger, read the newest preferences, schedule the following occurrence, and
  then post the notification. Do not request `SCHEDULE_EXACT_ALARM` or
  `USE_EXACT_ALARM`.
- Treat the selected time as a local wall-clock preference. A nonexistent time
  during a spring daylight-saving transition moves forward by the time-zone gap
  (for example, 02:30 becomes 03:30). An overlapping autumn time fires at most
  once per local day.
- Reconcile enabled state, time, and locale from the preference Flow while the
  app is running. Also use a non-exported receiver for boot, system-time,
  time-zone, locale, and package-replacement broadcasts so the next one-shot
  alarm is rebuilt after system changes.
- On Android 13 and later, request `POST_NOTIFICATIONS` only after the user turns
  on the reminder switch. A denial leaves the persisted switch off and displays
  a short Snackbar. The UI says the reminder occurs approximately at the chosen
  time; it does not promise minute-level delivery.
- Build the notification from product-owned localized resources. Its content
  Intent is explicit and carries the newest stable paragraph ID plus Unicode
  code-point offset. The existing typed deep-link model validates the target,
  clamps the offset to current text, opens the real reader, and persists the same
  anchor. Each posted reminder also carries a request identity so a newly tapped
  notification is not mistaken for the Activity's previously consumed Intent
  when Android restores a saved task. If no progress exists, the explicit Intent
  safely opens the app root.
- Preserve the requested code-point anchor while the reader performs its initial
  layout scroll or a later font/width reflow. Only a user-originated nested scroll
  may replace persisted progress with the newly visible line anchor.
  All product apps disable App Bundle language splitting so every supported
  in-app locale remains available when it differs from the device locale.
- Keep ordinary reminders separate from the future Media3 playback notification
  and audio preference controls.

## Consequences

The shared scheduler can be reused by every single-scripture app while each
package retains isolated preferences, channels, notification identity, copy,
and navigation composition. Delivery is intentionally approximate and can be
deferred by Doze or OEM policy. Re-reading preferences at trigger time prevents
a stale alarm from notifying after the user disables or changes the reminder.

The receiver and observer handle normal lifecycle and protected system events,
but Android force-stop semantics still suppress alarms and receivers until the
user launches the app again. Notification channels are user-controlled after
creation; revoking notification access suppresses posting without silently
changing the in-app preference.

## Verification

Pure JVM tests cover same-day and next-day scheduling, exact-minute rollover,
spring daylight-saving gaps, and autumn overlap de-duplication. The API 35
managed-device suite verifies that the packaged app requests notification and
boot permissions but neither exact-alarm permission, and that the reminder
receiver is enabled and non-exported. It grants notification permission, writes
real product preferences and reading progress, posts a Traditional Chinese
notification, verifies its channel/title/body and explicit creator package, and
opens the exact saved paragraph/code-point offset through `MainActivity`.

The shared Settings screen is included in the host-rendered screenshot matrix;
API 35 shell and accessibility tests scroll to its switch/time controls under
the real app. API 26 behavior, the API 33 permission dialog, API 36, physical
devices, battery restrictions, and Samsung/target mainland OEM delivery remain
Gate F work and are not inferred from the API 35 AOSP result.

## Reconsider When

Revisit the scheduler only if measured product requirements need a server-driven
campaign, multiple reminders per day, cross-device sync, or minute-exact user
commitments. Any exact-alarm proposal requires a separate user-value, policy,
permission, battery, and store-compliance decision.
