# SuiSakhi Smart Assist

**Status:** Local implementation on `codex/smart-assist-backend`; not deployed.
The attached Smart Assist architecture is the approved target. The branch
implements that design locally; staging deployment and emulator integration
validation remain prerequisites.

## Runtime design

```text
Flutter
  ├─ Dress Fit Assistant and measurement checks: local deterministic logic
  └─ Fabric / instruction guidance: authenticated Firebase callable
        ├─ Firebase Authentication + App Check
        ├─ input allowlist and sanitization
        ├─ per-user request limits and timeout
        ├─ server-side Anthropic secret
        └─ validated structured result → customer review → explicit apply
```

The callable returns `feature`, `suggestions`, `explanations`, `warnings`,
`clarificationQuestions`, and `requestId`. The Flutter client presents these
fields as guidance. The provider response is never applied automatically.

## Data boundaries

- `Dress Fit Assistant` and camera measurement guidance run locally. No body
  measurements or measurement-derived data are sent to an external provider.
- Fabric suggestions receive only garment, occasion, fit, fabric, design title,
  accent colour, preference, and budget fields that are present.
- Improved instructions receive sanitized notes and garment/fit context.
  Customer notes are filtered on the client and again on the server. Contact
  information, address details, identity labels, age/DOB, and lines containing
  explicit body measurement values are excluded. If any line is excluded, the response includes a warning;
  an approved rewrite keeps those original lines unchanged in the local order.
- Tailor checklists omit order ID, customer name, kids-flow metadata, and exact
  measurements. Delivery guidance omits customer identity, contact/address,
  payment, order value, order ID, and free-form notes. Price guidance omits
  measurements and customer notes. Outfit ideas use only season and garment
  category.
- Provider failures return a safe unavailable response. Order creation does not
  call or wait for Smart Assist.
- Function logs contain request ID, feature, and sanitized error categories only;
  they do not contain prompts, notes, provider output, or credentials.

## Credential migration

The existing Firestore `config/api` document and its fields are intentionally
retained. The Flutter code no longer reads them. The local Firestore rules deny
client reads of `config/api`; the server callable reads `ANTHROPIC_API_KEY` from
Firebase Secret Manager. No live Firestore field or rule has been changed.

Other Anthropic consumers found in the repository were migrated: measurement fit
advice is local, while pricing, tailor checklist, delivery brief, and outfit
idea calls use the callable with the data restrictions above. A repository-wide
search should continue to show provider credentials and the Anthropic endpoint
only in the server function.

## Limits and App Check

- One user can make at most 8 requests per 10 minutes and 40 per UTC day.
- The counter document ID is a SHA-256 hash of the Firebase UID. The document
  contains counters and timestamps only and is client-inaccessible by rules.
- The callable is in `us-central1`, requires Firebase Authentication, and has
  App Check enforcement enabled.
- Callable inputs are allowlisted, capped at 12 KB total, and bounded by field;
  customer notes are limited to 1,200 characters. Structured provider output is
  validated before it reaches Flutter.
- Normal Android builds use Play Integrity; Apple builds use App Attest with
  Device Check fallback. Web requires a reCAPTCHA v3 key provided at build time
  as `FIREBASE_APP_CHECK_RECAPTCHA_SITE_KEY`.
- For a local debug build only, `SUI_SAKHI_APP_CHECK_DEBUG_PROVIDER=true` opts
  into the Firebase App Check debug provider. Register its debug token only in
  the intended test project; never use the debug provider in release builds.

## Local validation

Backend unit tests:

```sh
cd firebase/functions
npm test
```

Flutter Smart Assist unit tests:

```sh
flutter test test/smart_assist_client_test.dart
```

The order fallback integration test uses only Firebase emulators and the demo
project ID. Start it with the integration-test define:

```sh
FIREBASE_CLI_DISABLE_UPDATE_CHECK=1 firebase emulators:exec \
  --project demo-suisakhi-smart-assist \
  --only auth,firestore \
  --log-verbosity QUIET \
  "flutter test -d emulator-5554 integration_test/smart_assist_order_optional_test.dart \
    --dart-define=SUI_SAKHI_USE_FIREBASE_EMULATORS=true \
    --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2"
```

Replace `emulator-5554` with the ID of a dedicated Android virtual device.
The integration check was not completed in this environment: the web runner
does not support Flutter integration tests, and the macOS build failed during
code signing because of resource-fork metadata in the existing build output.
No real project or physical customer device should be used for this test.

## Deployment prerequisites

1. Confirm Android, Apple, and web apps are registered with App Check in the
   intended staging project. Confirm Play Integrity, App Attest/Device Check,
   and the web site key are configured before enforcing requests.
2. Provision `ANTHROPIC_API_KEY` as a Functions secret in that project through
   the approved secret-management process. Do not copy it into Firestore, app
   configuration, source control, or logs.
3. Deploy the `smartAssist` callable to `us-central1` and verify Auth, App Check,
   provider secret access, limits, timeouts, and sanitized errors in staging.
4. Release the Flutter client and validate all guidance previews, rejection and
   approval behavior, and successful order placement while the callable is
   unavailable.
5. Deploy the Firestore rule change that denies client reads of `config/api`
   only after the new client and all current consumers have been validated.
   Keep the existing Firestore fields until separately approved for removal.

No deploy, live rule update, secret change, push, or merge is part of this local
implementation.

## Rollback

If the callable or provider is unhealthy, leave Smart Assist unavailable and
keep the order flow enabled. Roll back the callable implementation or stop
invoking it from the client after review; do not reopen client access to
`config/api` and do not delete its existing fields or credentials as part of
rollback. Re-run the emulator order test and Flutter analysis before a corrected
release.
