# Lengyan Product Data Flow

Status: implementation record; privacy publication still requires human approval

Date: 2026-07-27

## Scope

This document records the data flows implemented by the current Lengyan iOS
and Android code. It is the engineering input to public privacy text, store data
safety forms, and release review. It does not itself constitute legal approval.

## Android

| Capability | Data | Destination | Storage and removal |
|---|---|---|---|
| Reading, search, favorites, appearance, reminders | Stable scripture IDs, Unicode code-point offsets, favorites, locale, theme, font level, reminder time | App-local DataStore and Room only | Removed when the app is uninstalled. `android:allowBackup="false"` and the extraction rules exclude cloud/device transfer. |
| Daily-reading Widget | Selected stable paragraph ID, display text, locale, theme and snapshot version | App-local Widget DataStore and Android launcher Widget host | The app retains the latest valid local snapshot; uninstall removes app-owned state. The launcher renders the supplied text. |
| Reminder notification | Product title, reminder text and a stable paragraph deep link | Android notification service | Notification lifecycle is controlled by Android and the user. The app schedules an inexact local alarm and does not upload reminder data. |
| Share image or text | User-selected scripture text and generated local files | Android Sharesheet and the recipient app selected by the user | Temporary image files live in the app cache and are exposed through a read-only `FileProvider` grant. Recipient handling is outside this app. |
| Save text | User-selected scripture text | User-selected document provider through `CreateDocument` | The selected provider controls the resulting file. |
| Copy text | User-selected scripture text | Android system clipboard | Clipboard handling is controlled by Android and the user. |
| Approved external source/privacy links | A contract-provided or product-provided HTTPS URL | User-selected browser through `ACTION_VIEW` | Browser and website policies apply after the handoff. The app rejects non-HTTPS, user-info-bearing, or malformed URLs. The current Lengyan host withholds its external privacy URL until the public pages match this inventory and receive human approval. |

The current Android app declares no `INTERNET` permission and implements no
in-app feedback or audio download. Reading, search, favorites, reminders and
Widget refresh therefore do not create a direct app network request. This must
be reviewed before Android audio, feedback, crash reporting, analytics, account,
sync or backup features are added.

## iOS

| Capability | Data | Destination | Storage and removal |
|---|---|---|---|
| Reading and preferences | Reading/listening progress, bookmarks, favorites, locale, appearance and related preferences | App-local files/UserDefaults | The app implements no account or cross-device sync. Apple device backup behavior remains controlled by the user's system settings unless a data class is explicitly excluded. |
| On-demand audio | Requested immutable audio artifact and ordinary connection metadata inherent to the request | Apple-hosted ODR/Managed Background Assets; Cloudflare HTTPS fallback only under the implemented failover policy | Apple manages hosted resources. Verified fallback files are app cache data and are eligible for cleanup after 28 days without access; uninstall also removes app-owned files. |
| Feedback | User-entered content, stable product ID and public app version; the service creates a submission time, random reference and read state | Multi-product Cloudflare Worker and D1 | Active rows are cleaned after 21 days. D1 recovery history can retain a pre-deletion state for up to 7 additional days on the current plan; the public maximum remains 30 days. Raw connection addresses are not stored in the feedback table. |
| Share and external links | User-selected content or URL | iOS share sheet, selected recipient, or browser | Recipient/browser policies apply after the handoff. |

Apple and Cloudflare necessarily receive ordinary request metadata such as a
connection address when their network services are used. The app does not use
that metadata for advertising, analytics, or cross-app tracking. Provider-side
handling and any infrastructure plan change require a fresh privacy review.

## Release Controls

- Public privacy pages, App Store privacy answers, Play Data safety answers and
  regional disclosures must be checked against this table before every release.
- A product host must not configure its optional external privacy URL until that
  exact page is synchronized with this inventory and approved. The accurate
  in-app summary remains available when the URL is withheld.
- The feedback Worker schema, cleanup schedule and D1 recovery window must be
  verified without printing feedback content.
- The repository implements explicit feedback `productID`, an additive D1
  migration, an allowlisted Worker and the Lengyan iOS payload. Production
  migration/deployment remains pending human approval. Missing IDs map only to
  the historical Lengyan endpoint; a new product must never rely on that path.
- Open-source license notices are a separate dependency inventory. Do not show
  a partial or copied acknowledgment page as if it were complete.
- Human approval remains mandatory for privacy and regional compliance.
