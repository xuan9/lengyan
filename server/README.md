# Feedback Worker deployment

Run commands from this directory. The lockfile pins the tested Wrangler 4.112.0;
the Worker requires at least 4.36.0 for native Rate Limiting bindings.

```sh
npm ci
npm test
npm run check
npm exec wrangler d1 migrations list lengyan-feedback-db --remote
npm run deploy:dry-run
```

Then follow “Routine production deployment and health check” below. Do not
clear data or apply a pending migration as an incidental deployment step.

The following commands are for first-time setup or an intentional credential
rotation only, not routine deployment. Wrangler prompts securely for each value:

```sh
npm exec wrangler secret put ADMIN_PASSWORD
npm exec wrangler secret put ADMIN_SESSION_SECRET
```

Use a new `ADMIN_PASSWORD` of at least 16 characters rather than reusing the
value from the legacy Worker, which placed that value directly in its
administrator cookie. The Worker fails closed when this minimum is not met.
`ADMIN_SESSION_SECRET` must contain at least 32 characters and be independent
of the password. The Worker also rejects a configuration in which the two
values are identical. The session secret signs short-lived administrator
sessions and domain-separated rate-limit keys; it is not a second login
password. Generate both values with a password manager or cryptographically
secure random generator; the minimum lengths are validation floors, not a
substitute for entropy.

`POST /` is intentionally public and has no API key. A key embedded in an App
or static website is extractable and must not be treated as authentication.
Abuse protection instead comes from the two submit rate limiters. Browser
CORS authorization is granted only to `https://xuan9.github.io` for `POST /`;
this is a browser boundary, not authentication. Native requests without an
`Origin` header continue to work. No `/admin` or `/api` response carries CORS
authorization.

Before deployment,
confirm that rate-limit namespace IDs `716202601` through `716202604` are not
used by another Worker in the same Cloudflare account; replace them with unused
positive integers if necessary. Bindings are fail-closed: submissions and
logins return HTTP 503 if a required rate limiter is absent or unavailable.

## Pre-production data-protection checks

Before enabling real submissions, run
`npm exec wrangler d1 info lengyan-feedback-db` and record the database identity
and jurisdiction shown by the CLI. Separately confirm in the Cloudflare
Dashboard that the account is still on Workers Free, and verify the current D1
Time Travel duration against the linked D1 documentation; `wrangler d1 info`
does not report either of those two values. D1 defaults to an automatically
selected location. An
`eu` jurisdiction restricts where the database runs and persists data, but it
can only be chosen when the database is created; it cannot be retrofitted to
this existing database. A location hint is not a jurisdiction guarantee, and a
D1 jurisdiction alone does not restrict the global regions from which the
Worker processes requests.

Confirm that the selected setup is appropriate for the App's users and public
privacy statements. Where applicable, accept and retain the current Cloudflare
Data Processing Addendum, review its transfer safeguards and subprocessors,
and record the controller/processor assessment. If an EU-restricted D1 database
or Regional Services is required, create and validate that architecture before
launch, migrate through a strictly access-controlled temporary export, update
the binding, and securely delete the export after validation. Do not describe
the service as EU-only unless both the configured products and agreement
actually support that claim.

Each endpoint has two limits: a route-wide ceiling and a per-connection-address
ceiling. The Worker immediately HMACs `CF-Connecting-IP` with the server-only
session secret and passes only that route-scoped digest to Cloudflare's
short-lived counter. It never writes the raw address or digest to D1 or custom
logs. Shared mobile networks and privacy relays can share an address, so the
per-address limits are deliberately higher than normal human use. Limits are
per Cloudflare location and eventually consistent: they reduce abuse but are
not billing-grade accounting. Automatic invocation logs are disabled because
they can contain request and network metadata. Workers Observability retains
only the code's explicit generic custom errors and scheduled cleanup failures;
configure alerts for those failures without logging request bodies or headers.

Migrations are ordered so all deployment histories converge on the minimal
schema with no diagnostic columns:

- A fresh database applies `0000` through `0005` in order.
- A database that already recorded `0001` applies the harmless
  `CREATE TABLE IF NOT EXISTS` baseline in `0000`, then the remaining migrations.
- A database that already recorded an earlier draft of `0002` applies `0003`,
  which rebuilds the stricter schema; `0004` clears any remaining diagnostics,
  and `0005` removes those columns entirely.

## Routine production deployment and health check

> **Never clear the feedback table as part of a routine deployment.** It now
> contains real user submissions. The destructive legacy cutover was completed
> once on 2026-07-18 and must not be replayed.

1. Run `npm ci`, `npm test`, `npm run check`, and `npm run deploy:dry-run`.
2. Run `npm exec wrangler secret list` and
   `npm exec wrangler d1 migrations list lengyan-feedback-db --remote`. Confirm
   the two administrator secret names exist without printing their values. If a
   migration is pending, review its SQL and data-retention effect, record a
   current Time Travel bookmark, and use a separately approved migration plan;
   never apply a destructive migration merely because it appears in the list.
3. Confirm the rate-limit namespace IDs, database jurisdiction, Workers Free
   plan, 7-day Time Travel window, hourly Cron trigger, and generic
   cleanup-failure alert still match this service's assumptions.
4. Deploy with `npm exec wrangler deploy`, then verify `GET /privacy` returns
   HTTP 302 with `Cache-Control: no-store` and redirects to
   `https://xuan9.github.io/lengyan/privacy.html`. Repeat with
   `Accept-Language: zh-Hant` and confirm the destination is
   `https://xuan9.github.io/lengyan/privacy-hant.html`.
5. Verify an `OPTIONS /` preflight from `https://xuan9.github.io` authorizes
   only `POST` and `Content-Type`, while an untrusted origin and `/admin` or
   `/api` receive no CORS headers. Confirm unauthenticated `/api/list` remains
   HTTP 401.
6. Log in to `/admin` and perform read-only list checks. Create a clearly
   labelled test submission only when the submission path changed; delete only
   that known test row by its returned reference. Never bulk-delete or assume
   existing rows are test data.
7. Inspect the remote schema and retention boundary without printing feedback
   content, for example:

   ```sh
   npm exec wrangler d1 execute lengyan-feedback-db --remote --command \
     "PRAGMA table_info(feedback); SELECT MIN(created_at), COUNT(*) FROM feedback;"
   ```

   Confirm there is no `type`, `device_id`, `device`, `device_family`, `os`,
   `os_version`, or `build` column, and that the oldest active row is newer than
   the configured 21-day cleanup boundary.
8. Review HTTP 429/5xx behavior and the most recent scheduled cleanup result.
   `ADMIN_PASSWORD` and `ADMIN_SESSION_SECRET` must remain separate server-only
   secrets and must never be reused as a submission key.

If a future release needs an incompatible schema change, use a staged additive
migration and a Worker that can dual-read/write both schemas before any later
destructive cleanup. Treat that as a separately approved data migration, not a
normal deployment step.

## Historical one-time cutover (completed; do not rerun)

On 2026-07-18, before real submissions were enabled, the confirmed test rows
were cleared once, migrations `0000` through `0005` were recorded, the minimized
Worker replaced the unused legacy endpoint, the support site was published, and
the obsolete `FEEDBACK_API_KEY` secret was removed. This paragraph is a release
record only. In particular, do not clear current rows, delete secrets, or replay
the legacy migration sequence from it.

Migrations `0002` and `0003` retain their historical 58-day migration cutoff
while assigning random references and clearing legacy device, OS, version, and
build metadata. Migration `0005` reduced that historical boundary to 57 days
and removed the diagnostic columns entirely. The current 21-day boundary is
enforced by the Worker's scheduled cleanup, not by another migration. `0003`
also hardens constraints for deployments that may already have recorded an
earlier draft of `0002`. If a temporary production export is required before
migration, encrypt it or otherwise strictly limit access, use it only to
validate the migration, and securely delete it immediately afterward. Do not
retain migration exports as indefinite backups. Migration `0005` preserves only
feedback content, the public App version, reference, read state, and creation
time, making diagnostic storage structurally impossible in the final table.

The rebuilding migrations preserve an already-valid ISO 8601 timestamp and
normalize other SQLite-readable legacy timestamps to UTC ISO 8601. Rows with an
unparseable timestamp are excluded by the retention predicate instead of
blocking the whole migration.

Cleanup runs hourly with a 21-day cutoff. Under normal scheduling, active rows
are removed shortly after 21 days. Cloudflare D1 Time Travel on the Workers Free
plan may retain the pre-deletion state for up to 7 more days, so recoverable
copies expire before 29 days and retain more than one day of margin below the
public 30-day maximum. Time Travel is always on and requires no paid feature.
Verify that the database remains on the Free plan, the hourly Cron trigger is
active, and cleanup-failure alerting works before publishing that maximum. A
move to Workers Paid can extend Time Travel to 30 days and therefore requires a
fresh retention review before the plan changes. Cleanup failures reject the
scheduled event; alert on the generic `Feedback retention cleanup failed`
custom error.

The one-time pre-launch clear can remain in recovery history for up to 7 days
after the cutover. It contained only confirmed test data and must not be restored
over the current database. New submissions are governed by the Worker's 21-day
scheduled cleanup. In all future operations, remember that deleting an active
row does not make its prior recovery history disappear immediately.

`GET /privacy` is public, requires no administrator session, and is retained as
a language-aware compatibility redirect. The canonical App Store and in-App
privacy-policy URLs are:

- <https://xuan9.github.io/lengyan/privacy.html>
- <https://xuan9.github.io/lengyan/privacy-hant.html>

References:

- <https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/>
- <https://developers.cloudflare.com/fundamentals/reference/http-headers/#cf-connecting-ip>
- <https://developers.cloudflare.com/d1/reference/migrations/>
- <https://developers.cloudflare.com/d1/reference/time-travel/>
- <https://developers.cloudflare.com/d1/configuration/data-location/>
- <https://www.cloudflare.com/cloudflare-customer-dpa/>
- <https://developers.cloudflare.com/workers/configuration/cron-triggers/>
- <https://developers.cloudflare.com/workers/observability/logs/workers-logs/>
