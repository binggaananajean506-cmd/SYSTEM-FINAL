# E-SUGID

E-SUGID is a Flutter and Firebase community-services application for the
Municipality of Barili, Cebu. Residents can receive targeted announcements,
report concerns and emergencies, request documents, and access local services.
Barangay officials, partner organizations, and LGU administrators receive
role-specific publishing and management tools.

## Working project

Use `D:/Downloads/esugid` as the single working project for Flutter, the admin
console, Cloud Functions, and deployment. Run project commands from this folder.

The former nested `esugid/` copy was reconciled on October 17, 2026. Its complete
historical contents are preserved at
`D:/Downloads/esugid-archive-2026-10-17/nested-original`; that folder is an archive,
not another working project. The reconciliation decisions and verification are
recorded in `output/source-reconciliation-2026-10-17/README.md`.

## Applications

- `lib/` contains the Android Flutter application.
- `admin_web/` contains the static Firebase Hosting administration client.
- Both clients use the `e-sugid` Firebase project.

The Flutter application currently includes only an Android platform project.

## Web appearance

The staff console offers Light, Dark, and System from the palette button on
the sign-in screen and in the workspace header. Light is the default, even on
devices set to dark mode; System follows the device's color scheme. The preference is stored on that browser
under `esugid_theme`, survives sign-in/sign-out and refreshes, and synchronizes
between tabs. If browser storage is unavailable, theme switching still works
for the current page.

`admin_web/theme.js` resolves the preference before rendering.
`admin_web/theme.css` owns the semantic palette, including backgrounds,
surfaces, text, borders, inputs, green accents, interaction states, and status
colors. Existing components use CSS `light-dark()` to retain their original
light styling and select semantic dark colors; new components should use the
semantic variables directly. Use `--onAccent` with solid action backgrounds
and the status foreground/surface pairs for badges. Fixed colors are reserved
for the appearance preview illustrations and paper exports. Logos, uploaded
images, and geographic imagery retain their original colors.

`admin_web/theme-charts.mjs` applies the same palette to Chart.js axes,
legends, series, titles, and tooltips, and updates existing charts when the theme
changes. Print uses the light palette without changing the saved preference.
The console requires a current browser supporting CSS `light-dark()`.

Run web verification from `admin_web`:

```sh
npm run test:layout
```

Theme regression tests cover all available staff navigation destinations in
both modes for six roles at 390, 768, and 1440 pixels, authentication screens,
generated dialogs, publishing steps, contrast, keyboard focus, persistence,
system changes, cross-tab synchronization, and chart updates. These tests use
local fixture sessions and do not modify production records.

## Android release signing

Debug builds work without local signing files. Release builds intentionally do
not fall back to the debug key. Create `android/key.properties` locally with
`storeFile`, `storePassword`, `keyAlias`, and `keyPassword` values that point to
the approved release keystore. Both the properties file and keystore extensions
are ignored by source control.

The Android application ID is `com.esugid.barili`, registered in the
checked-in Firebase Android configuration. A release build without
`android/key.properties` stops with an error instead of signing with the debug
key. `targetSdk` follows the Flutter SDK default.

## Main architecture

- `lib/main.dart` initializes Firebase, configures themes, and routes users by
  authentication state and role.
- `lib/home_screen.dart` provides the shared resident, barangay, and partner
  dashboard.
- `admin_web/` is the canonical staff console. LGU IT administrators receive
  the complete municipal workspace. Other LGU departments, barangay officials,
  and verified service organizations receive scoped views of the same system.
- Files ending in `_service.dart` contain Firestore-backed models and data
  operations.
- `lib/pages/` contains feature screens.

Firestore collections currently used by the clients include `users`, `posts`,
`announcement_feeds`, `alerts`, `submissions`, `notifications`, `organizations`, `audit_logs`,
`document_requests`, `emergency_reports`, `helpdesk_tickets`, `civic_points`,
`lgu_departments`, `access_policies`, `emergency_dispatches`, `emergency_contacts`,
`concern_recipients`, `staff_account_requests`, `jobs`,
`marketplace`, and `system`.

## Admin workflows

The staff console uses eight plain-language areas: Dashboard, Emergencies,
Concerns, Requests, Announcements, People, Reports, and Settings. The dashboard
shows one prioritized work list, while creation and record details open in
focused views so the main queues remain readable. Navigation and visible pages
are filtered by the approved staff role described below.

- Concerns display four statuses: Active, In Progress, Awaiting Information,
  and Resolved. Legacy status values are normalized into these stages. A
  request for information returns to In Progress when the resident responds.
  Public updates reach the resident notification feed; internal notes are
  limited to the receiving staff team.
- Approved barangay and organization staff publish directly. Barangay
  announcements are locked to the official's assigned barangay. Organization
  announcements are limited to the service area approved by the LGU, with a
  separate municipality-wide permission.
- LGU announcements may target all Barili or selected barangays. Verified
  organizations are limited to their configured publishing scope, while
  barangay officials are limited to their own barangay. Emergency threats stay
  in the separate Alerts workflow.
- Cloud Functions publish scheduled announcements, expire time-bound content,
  mirror approved posts into municipality/barangay audience feeds, and deliver
  optional Firebase Cloud Messaging topic notifications. The Android client
  subscribes residents to the municipality topic and their current barangay.
  Emergency alerts use the high-importance `esugid_emergency_v1` Android
  notification channel, its bundled alert tone, and a distinct vibration
  pattern; regular announcements continue to use normal notification delivery.
- LGU departments are managed records rather than free-text account fields.
  Each department has a stable ID and public publisher name (for example,
  `LGU Tourism Department`). Department staff see only their department's
  accounts, announcements, account requests, and assigned concerns.
- Verification, concern, user-status, and moderation actions create immutable
  `audit_logs` records. The LGU IT System Logs list excludes concern audit
  entries; the receiving team's case timeline contains the concern history.
- Existing records using legacy statuses such as `Pending` and `Under Review`
  are normalized by both clients when displayed.
- LGU IT can set each department, organization, or barangay permission to its
  role default, Allow, or Deny from Structure. Overrides apply to all current
  and future members of that entity. Resident-verification grants to a
  department or organization require an explicit barangay list; a barangay
  grant never expands beyond its own residents. IT administration and staff
  request approval cannot be delegated.
- Verified organizations can send private emergency requests to another
  verified organization. Only the sender, recipient, and LGU IT can view the
  request; the recipient acknowledges and tracks its response. This workflow
  does not broadcast to residents. The Emergency page also shows clickable
  hotlines, which LGU IT maintains, and an opt-in sound for new incoming
  requests while the admin tab is open. Browser sound is not a substitute for
  calling emergency services.

### Staff access matrix

| Capability | LGU IT Administrator | LGU Department | Captain | Vice Captain | Secretary | Councilor | Organization |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Concerns | Only those sent to LGU IT Department | Assigned department | Sent to own barangay | Sent to own barangay | Sent to own barangay | No | Assigned organization |
| Emergency reports | All | No | Own barangay | Own barangay | Own barangay | Own barangay | Routed agency only |
| Announcements | Department identity; any audience | Department identity; any audience | Own barangay | Own barangay | Own barangay | Kagawad only; own barangay | Approved service area |
| Resident verification | Municipality oversight | No | Own barangay; may delegate | Own barangay when authorized | Own barangay when authorized | Only when delegated | No |
| Request staff accounts (IT approval required) | Creates directly | Same department | Own barangay | Own barangay | Own barangay | No | Same organization |
| Approve staff requests | Yes | No | No | No | No | No | No |
| Private organization emergency dispatch | Oversight | No | No | No | No | No | Send and receive |
| Manage departments, organizations, recipients, settings | Full | No | No | No | No | No | Organization profile only |

The table shows role defaults. IT can override concerns, announcements, staff
requests, public emergency broadcasting, local resident verification, and
private emergency sending/receiving. Private dispatch applies only to
organizations. All overrides retain the existing department, organization,
and barangay boundaries.

The `super_admin` role represents the LGU IT administrator. Other staff roles
are `lgu`, `barangay_captain`, `barangay_vice_captain`,
`barangay_secretary`, `barangay_councilor`, and `organization`. Existing
`barangay` and `partner` profiles remain compatible as Captain and Organization
Staff respectively. LGU IT creates barangay and organization accounts directly.
An LGU department user may request another account only for the same department;
the new account remains pending until LGU IT approves it. Staff accounts are
created by trusted Cloud Functions; the public client can create resident
profiles only.

All staff roles must have an `approved` Firestore profile. Interface visibility
is only a usability layer; Firestore and Storage rules independently enforce
the same role, barangay, organization, and emergency-routing boundaries.

## Local setup

1. Install Flutter with a Dart SDK compatible with `pubspec.yaml`.
2. Configure an Android emulator or connected device.
3. Ensure `android/app/google-services.json` and `lib/firebase_options.dart`
   refer to the intended Firebase environment.
4. Install dependencies and run the application:

   ```sh
   flutter pub get
   flutter run
   ```

Google sign-in additionally requires the Android signing certificate hashes to
be registered in Firebase Authentication.

## Verification

Run the standard checks before submitting changes:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Firebase authorization is covered by emulator regression tests for the mobile
app and web administrator workflows:

```sh
npm install --prefix rules_tests
firebase emulators:exec --only firestore,storage "npm --prefix rules_tests test"
```

The rules tests verify administrator bootstrap and dashboard listeners,
resident-owned data, publishing roles, responder-scoped emergencies, service
requests, marketplace and job ownership, and protected file uploads.

## Firebase deployment

Firebase Hosting serves `admin_web/`. Cloud Functions live in `functions/`.
Firestore rules, indexes, and Storage rules are tracked in `firestore.rules`,
`firestore.indexes.json`, and `storage.rules`. Install function dependencies,
review the target project, then deploy the backend before the clients/rules:

The in-app E-SUGID Assistant uses `gemini-3.5-flash-lite` through the callable Cloud Function
`askESugidAssistant`. Create a Gemini API key in Google AI Studio, then store it
as a Firebase Functions secret. Never place this key in Flutter source,
`pubspec.yaml`, an asset, or the Android application:

```sh
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions:askESugidAssistant
```

The callable function requires an authenticated E-SUGID account, limits input
and response sizes, and applies a per-user request limit. The three built-in
quick questions are answered locally and do not consume Gemini quota. The
assistant follows the user's language and supports simple Cebuano/Bisaya and
Bisaya-English questions.

```sh
npm install --prefix functions
firebase deploy --only functions
firebase deploy --only firestore,storage,hosting
```

Delegated verification reviewers open proof documents through the
`getVerificationDocumentUrl` callable, which issues a five-minute signed link
after checking the current policy and resident barangay. The Functions runtime
service account needs Cloud Storage object-read access and permission to sign
blobs (`iam.serviceAccounts.signBlob`) for this to work in production. Verify
that IAM configuration before enabling delegated review.

Approved municipal, barangay, and organization staff profiles can use the web console.
Each role receives only its authorized queries and actions. Client-side role
checks complement, but do not replace, the deployed Firebase rules.

## Android appearance

Profile → App Preferences → Theme offers **Light**, **Dark**, and **System
Default**. The choice updates immediately and is stored on the device using
SharedPreferences (`esugid_theme_mode`); it survives logout and app restarts.
Existing `esugid_dark_mode` preferences are supported and migrated on selection.
New installations open in Light, even when the phone uses dark mode. Preferences load before Flutter
renders its first frame, and the native launch screen uses E-SUGID green.

`lib/app/theme/esugid_clay_theme.dart` owns Material component themes and
ColorScheme. `semantic_colors.dart` provides `context.colors` for custom UI.
Use `background` for pages, `surface`/`surfaceAlt` for panels, and semantic text,
input, border, disabled, and status colors. Pair `primaryGreen` with `onPrimary`,
solid brand/status backgrounds with `onAccent`, and status foregrounds with their
matching status surfaces. Let Material buttons inherit foreground colors so
disabled states remain readable. Logos, photos, and illustration assets retain
their original colors; the street map has a separate dark style.
Native lock-screen emergency alerts and background overlays read the same saved
choice, observe system changes, and use matching Android semantic resources.

Theme regression checks:
`flutter test test/app_theme_test.dart test/theme_components_test.dart`.

Action messages use `AppSnackBar` and `showAppSnackBar` from
`lib/core/widgets/app_feedback.dart`. Choose an explicit success, error, warning,
or information status; keep any action and actionable error text. New results
replace stale messages, and every message can be dismissed. Complaint and
concern validation also stays visible beside the form action and reveals the
first invalid field without clearing entered information.

## Release limitations

Create the protected release keystore and `android/key.properties` (see
Android release signing above) before building a release.
