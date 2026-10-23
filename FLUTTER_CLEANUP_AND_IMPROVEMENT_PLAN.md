# E-Sugid Flutter Cleanup and Improvement Plan

Status: Core execution completed; release identity and broad feature extraction remain staged  
Primary scope: Flutter resident/staff mobile application  
Secondary scope: Firebase contracts required by the mobile application  
Out of scope: Admin web UI redesign or unrelated admin-web refactoring  
Prepared from repository audit: August 15, 2026

## 1. Purpose

This document is the implementation handoff for cleaning, stabilizing, and incrementally refactoring the Flutter application. It is intentionally explicit so a lower-reasoning implementation model can execute it phase by phase without guessing at product rules, deleting uncertain files, or attempting a high-risk rewrite.

The work should produce a mobile codebase that:

- preserves current user-facing features unless this plan explicitly fixes broken behavior;
- has clear UI, state, service, repository, and model boundaries;
- uses Firebase through consistent, authorized data contracts;
- has predictable authentication, navigation, error handling, and cleanup;
- is responsive and readable across supported screen sizes and text scales;
- has no analyzer warnings, dead declarations, unused dependencies, or proven-unused assets;
- can be built from a clean checkout without paths from another developer's computer;
- has focused regression tests for the most important resident and staff workflows.

## 2. Execution Rules

The executor must follow these rules throughout the work.

1. Execute one phase at a time. Do not combine the Firebase contract repair, UI refactor, dependency upgrades, and release configuration into one change.
2. Before each phase, inspect the current files and call sites again. This plan records the audit state, but the repository remains the source of truth.
3. Preserve unrelated user changes. Do not reset, clean, or overwrite the workspace broadly.
4. Use existing Flutter/Firebase packages and the existing state-management approach unless a phase explicitly authorizes a dependency change.
5. Do not introduce a new state-management package merely to perform this cleanup.
6. Refactor incrementally. Do not rewrite the whole application or split files only because of line count.
7. Every data-model or status change must remain backward-compatible with existing Firestore documents until a verified migration/backfill has completed.
8. Firebase authorization must be enforced in Firestore/Storage rules or trusted Cloud Functions. Never rely on hidden buttons or client-side role checks as the security boundary.
9. Never delete a source file or asset based only on its name or a single search. Follow the deletion proof in Section 10.
10. Do not batch major package upgrades with feature or architecture changes.
11. Run the checks listed for a phase before proceeding. If a check fails, fix or document the failure before marking that phase complete.
12. Keep this file updated during execution: mark checkboxes, add the actual verification results, and record deliberate deviations in the decision log.

## 3. Product Defaults to Preserve

Use these decisions unless the product owner explicitly changes them.

- The mobile public sign-up flow is resident-only. Barangay, partner/organization, LGU, and super-admin accounts are created or approved through the admin system.
- The mobile login form accepts any syntactically valid email address. Do not restrict login to `@gmail.com`; staff accounts may use government or organization domains.
- Existing authorized staff mobile dashboards remain available. Remove duplicate wrapper files, not staff access itself.
- A new resident account being active is not the same as the resident being identity-verified. Track these as separate statuses.
- Barangay staff may only see and act on residents and concerns in their assigned barangay.
- Partner/organization staff may publish authorized announcements but may not approve resident verification.
- LGU and super-admin users retain municipality-wide access according to the existing role policy.
- Barangay and partner announcements do not require a separate post-approval step once the staff account itself is active and approved.
- Static tourism, school, church, dining, official, and hotline content remains local during the core cleanup. Changing its source is a later product decision.
- Preserve the current onboarding-on-launch behavior for now because an existing test explicitly describes it. Persist onboarding completion only after a separate product decision and test update.
- No bulk production-data deletion is part of this plan.

## 4. Audit Baseline

These figures are observations, not quality targets.

| Area | Baseline finding |
| --- | --- |
| Flutter source | 53 Dart files and approximately 30,555 lines |
| Largest file | `lib/home_screen.dart`, approximately 7,082 lines |
| Other large features | Concern center ~2,097; jobs ~2,065; carabao game ~1,663; marketplace ~1,562; onboarding ~1,150; signup ~1,112 lines |
| Static styling | Approximately 511 raw `Color(...)` literals and 468 direct `GoogleFonts` calls |
| Small text | Approximately 114 font-size declarations at or below 10.5 logical pixels |
| UI feedback | Approximately 106 direct `SnackBar` constructions |
| Direct Firebase coupling | Numerous direct Firestore/Storage calls from screens and widgets |
| Analyzer | 27 findings: unused imports/declarations, deprecated APIs, async-context warnings, and style issues |
| Tests | 38 passed and 1 failed; failure is the home-header expected extent |
| Formatting | 26 of 63 checked Dart files would be reformatted |
| Build | Debug APK build blocked by stale generated paths referencing another Windows user/workspace |
| Asset size | Approximately 56.5 MB total; images ~53.5 MB, fonts ~2.5 MB, audio ~0.5 MB |
| Generated directories | `build/` ~2.5 GB and `.dart_tool/` ~344 MB in the audited zip/workspace |

### Largest responsibility problems

- `home_screen.dart` combines the application shell, navigation, header/weather, feeds, post cards and details, announcements, emergency responder UI, notifications, services, archives, and custom painters.
- `CommunityService` combines announcements, alerts, help-desk behavior, civic points, routing, and claim-code concerns.
- Firebase clients, role logic, validation, image upload, UI state, and navigation are often mixed inside screens.
- Date fields, statuses, notifications, and user verification use inconsistent schemas across the mobile app, rules, functions, and admin web.

## 5. Priority Defects to Fix Before Cosmetic Refactoring

### P0: Security and data-integrity defects

1. **Resident verification is conflated with account activation.** New residents are created with `status: approved`, and `isVerified` treats that as identity verification. Split account status from verification status.
2. **Barangay concern access is broken.** Concern submissions omit `barangay` and `residentName`, while rules/admin scoping depends on `barangay`.
3. **Concern input is lost.** `requestedAction` is collected in UI state but is not written with the submission.
4. **Emergency status updates violate the rules contract.** The app writes `received`/`dispatched`/`resolved` without `updatedBy`; the rules expect `acknowledged`/`responding`/`resolved` and an updater identity.
5. **Client-authoritative civic points are rejected and unsafe.** Client writes are not authorized, and failure after the main record write can leave partial records or delete an image that a saved record still references.
6. **Job interest is not authorized.** The `jobs/{jobId}/interests` subcollection has no matching Firestore rule, and its notification payload uses a different schema.
7. **Concern attachment access is inconsistent.** Firestore may allow same-barangay staff to manage a concern, but Storage rules only allow the resident owner or broad admin roles to read the attachment.
8. **Staff self-registration conflicts with security rules and current product policy.** Public sign-up exposes staff roles even though `/users` owner-create rules allow a resident profile only. A failed profile write may leave an orphan Firebase Authentication user.

### P1: Reliability and user-facing defects

1. Forgot password displays success without calling Firebase Authentication.
2. Firebase initialization errors are caught and the application still starts, allowing later service access to an uninitialized Firebase instance.
3. FCM initialization commonly runs before the authenticated profile is loaded, so the first token may not be saved.
4. Foreground FCM messages are only printed and do not produce visible feedback.
5. Announcement-topic sync and clear operations run as unawaited build side effects and can race during account changes.
6. Static stream caches survive logout/user changes and can leak stale data across sessions.
7. Two navigation authorities exist: the root auth gate and manual dashboard replacement from login/sign-up.
8. Most stream UIs treat errors as empty data, hiding permissions and connectivity failures.
9. Shared concern drafts use global keys rather than user-scoped keys and can appear under another account on a shared device.
10. Multiple form screens use `BuildContext` after asynchronous gaps without mounted checks.

### P2: Maintainability, accessibility, and performance

1. Very large widgets mix unrelated responsibilities.
2. Raw colors and direct font construction make dark mode and visual consistency incomplete.
3. Fixed heights, tiny type, and `FittedBox` shrinking can cause unreadable content and overflows.
4. Duplicate image upload, location lookup, request-help, and offer-help logic increases defect risk.
5. All dashboard pages are proactively warmed, defeating lazy loading.
6. Large Firestore collections are streamed without consistent pagination or limits.
7. Full image bytes are commonly loaded into memory, and upload validation/rollback differs by feature.
8. Malformed or missing Firestore dates silently become `DateTime.now()`, masking corrupt documents.

## 6. Target Architecture

Do not move every file at once. Establish this shape feature by feature while preserving public behavior.

```text
lib/
  app/
    app.dart
    app_router.dart
    session_gate.dart
    theme/
      app_colors.dart
      app_spacing.dart
      app_typography.dart
      app_theme.dart
  core/
    errors/
    firebase/
    formatting/
    location/
    media/
    notifications/
    widgets/
  features/
    auth/
      data/
      domain/
      presentation/
    home/
    announcements/
    concerns/
    emergencies/
    verification/
    services/
    marketplace/
    jobs/
    help/
    profile/
```

This is a destination map, not permission for a bulk file move. For each feature:

- presentation widgets render state and emit user intent;
- controllers/view models coordinate a screen workflow;
- repositories define app-facing data operations;
- Firebase implementations own queries, serialization, and upload details;
- domain models own canonical values and parsing;
- rules/functions remain the authorization and privileged-write boundary.

Prefer constructor injection for repositories/services. A lightweight manual composition root is sufficient; do not add a dependency-injection framework for this cleanup.

## 7. Phased Execution Plan

### Phase 0 — Establish a reproducible baseline

Goal: make diagnostics trustworthy before changing behavior.

- [ ] Confirm the actual workspace root before deleting generated files.
- [ ] Record all existing source modifications or, if the zip has no valid Git metadata, create a dated source-file manifest with hashes before edits.
- [ ] Remove only generated local state containing stale absolute paths: `build/` and `.dart_tool/`. Use explicit, resolved workspace paths; do not recursively delete the repository root.
- [ ] Run `flutter clean` and `flutter pub get` from the Flutter root.
- [ ] Confirm no generated file still references `C:\Users\Royce Celine Marco\StudioProjects\esugid`.
- [ ] Run and save the baseline results:
  - `dart format --output=none --set-exit-if-changed lib test`
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug`
- [ ] Resolve the existing home-header test disagreement by testing the intended responsive behavior rather than preserving an arbitrary old extent. Verify no clipping at supported sizes before changing the expected value.
- [ ] Apply Dart formatting in a dedicated mechanical change, then rerun analyzer and tests. Do not mix functional edits into the formatting-only diff.

Acceptance criteria:

- Clean dependency resolution succeeds from the current path.
- No build input uses another developer's absolute path.
- The debug APK compiles, or an environment-only blocker is recorded with the exact command/output.
- Baseline test intent is accurate and all tests pass before feature refactoring begins.

### Phase 1 — Remove analyzer-confirmed dead code and lifecycle defects

Goal: make the current tree warning-free without redesigning behavior.

- [ ] Remove analyzer-confirmed unused imports:
  - `pages/chat_list_page.dart` from `home_screen.dart` if no call site exists;
  - `app_motion.dart` from churches, concern center, tourist spots, and trust-and-safety pages;
  - `trust_safety_dashboard.dart` from profile;
  - resident-map import from schools.
- [ ] Remove or integrate analyzer-confirmed unused declarations in `home_screen.dart`:
  - `_matchesCategory`
  - `_buildDashboardFilters`
  - `_buildRealisticSpiralBinding`
  - `_isPublicPost`
  - `_buildPostPriorityBadge`
  - `_buildPostStatusPill`
  - `_buildCategoryCard`
  - `_AsymmetricCardClipper`
- [ ] Remove unused `_buildFormActions` from the concern page and unused `_orange` from request help after rechecking call sites.
- [ ] Fix deprecated `scale`, form-field `value`, and switch `activeColor` usage using the APIs supported by the pinned Flutter SDK.
- [ ] Replace ambiguous underscore callback parameters reported by the analyzer.
- [ ] Add mounted checks or restructure the async flow in marketplace, offer-help, and request-help screens.
- [ ] Dispose every owned controller/focus node/listener. At minimum audit and fix:
  - forgot-password email controller;
  - chat-room message and scroll controllers;
  - every `TextEditingController`, `AnimationController`, `ScrollController`, `FocusNode`, subscription, timer, and notifier in stateful widgets.
- [ ] Run a repository-wide lifecycle audit rather than fixing only analyzer-reported examples.

Acceptance criteria:

- `flutter analyze` reports zero issues.
- Existing tests pass.
- No behavior or visual design changes are included except required API-equivalent deprecation updates.

### Phase 2 — Repair authentication, user status, and navigation

Goal: make account creation, session routing, verification labels, password reset, and logout deterministic.

- [ ] Introduce separate canonical fields in the user model:
  - `accountStatus`: active, pendingApproval, suspended, disabled;
  - `verificationStatus`: notSubmitted, pending, verified, rejected.
- [ ] Add backward-compatible parsing for legacy `status` documents. Do not reinterpret every legacy `approved` account as identity-verified without evidence.
- [ ] Define one migration/backfill strategy and test it against resident, barangay, partner, LGU, and super-admin examples.
- [ ] Update all `isActive`, `isVerified`, badges, Trust & Safety, Profile, and route guards to use the correct field.
- [ ] Make the public sign-up route resident-only and remove public barangay/partner role selection.
- [ ] Keep login domain-neutral: validate an email address, not a Gmail suffix.
- [ ] Replace the fake forgot-password delay with `FirebaseAuth.sendPasswordResetEmail`, and map user-not-found, invalid-email, throttling, offline, and generic failures to useful messages without leaking internal details.
- [ ] Make registration failure-safe. If Auth user creation succeeds but the profile write fails, delete the newly created Auth user when safe, or route registration through a trusted callable operation. Add a regression test for the partial-failure case.
- [ ] Introduce one session coordinator/root route authority. Login/sign-up should update auth state and let the session gate route; they should not independently push a second dashboard.
- [ ] Make Firebase startup fail to a dedicated retry/error screen if initialization fails. Do not start the normal Firebase-dependent app tree.
- [ ] Ensure logout awaits topic/token cleanup and Firebase sign-out, clears user-scoped caches/drafts, then lets the session gate show login.
- [ ] Remove the redundant wrapper screens only after replacing call sites:
  - `lib/barangay_official_dashboard.dart`
  - `lib/partner_organization_dashboard.dart`
  Route both roles to the shared authorized shell with role-specific capabilities.
- [ ] Add auth/session tests for resident, pending staff, active staff, suspended user, password reset, registration rollback, and logout.

Acceptance criteria:

- No public staff account can be created from the mobile sign-up flow.
- Active-account and identity-verified UI are independent.
- One authentication state change causes one navigation transition.
- Password reset calls Firebase and reports real success/failure.
- Logout clears user-specific state and cannot reveal data from the previous account.

### Phase 3 — Align mobile, Firebase, and admin data contracts

Goal: fix currently broken authorization and schema mismatches before large UI extraction.

This phase is cross-system by necessity. Keep admin web UI out of scope, but update shared Firebase rules/functions and any admin data mappers required to preserve compatibility.

#### Concerns

- [ ] Define one versioned concern schema and constants/converters for its statuses.
- [ ] Write `residentId`, `residentName`, `barangay`, `requestedAction`, timestamps, and attachment metadata for every new concern.
- [ ] Store concern drafts under a versioned, per-user SharedPreferences key and migrate or discard legacy global drafts safely.
- [ ] Validate the submitted barangay against the authenticated resident profile in trusted code/rules rather than trusting a freely supplied client value.
- [ ] Update Firestore rules so residents manage their own submissions, barangay staff can read/act only on their barangay, and LGU/super-admin retain authorized scope.
- [ ] Move new attachments to a path that includes resident and submission identity. Update Storage rules so the resident and authorized concern handlers share the same scope.
- [ ] Retain safe legacy attachment reads during migration; do not break old records abruptly.

#### Emergencies

- [ ] Standardize emergency statuses to the existing admin/rules vocabulary: `submitted`, `acknowledged`, `responding`, `resolved` (plus `closed` only if the existing product distinguishes it).
- [ ] Replace mobile `received` and `dispatched` writes and displays with canonical values.
- [ ] Include `updatedBy`, `updatedAt`, and any role/assignment fields required by the rules.
- [ ] Centralize transition validation so invalid backwards transitions cannot be requested by UI.
- [ ] Add rules-emulator tests for resident creation and authorized/unauthorized responder transitions.

#### Notifications

- [ ] Define one notification schema using `userId`, `title`, `message`, `type`, related entity ID, `read`, `createdAt`, and optional navigation data.
- [ ] Migrate job-interest code away from `recipientId`/`body` or support legacy parsing until old documents expire.
- [ ] Generate staff/system notifications through trusted Cloud Functions when the action crosses user boundaries.
- [ ] Display snapshot errors rather than silently reporting an empty notification list.

#### Civic points and job interests

- [ ] Remove client authority to grant civic points.
- [ ] Award points through an idempotent trusted function/trigger after a qualifying state transition. Store an idempotency key/event record so retries cannot award twice.
- [ ] Ensure marketplace/job/help completion and point award cannot produce misleading partial-failure UI.
- [ ] Implement job-interest creation through a secure callable/transaction or add precise subcollection rules that validate participant identity and immutable fields.
- [ ] Generate the job owner's notification in trusted code using the canonical schema.

#### Dates and status parsing

- [ ] Use Firestore `Timestamp` for persisted timestamps and server timestamps for authoritative creation/update times.
- [ ] Replace ad hoc string casing with enums or centralized wire-value constants.
- [ ] Make malformed/missing dates nullable or explicitly invalid. Do not silently turn them into `DateTime.now()`.
- [ ] Keep legacy parsers until migrated documents have been counted and verified.

Acceptance criteria:

- Same-barangay concern access succeeds; other-barangay staff access is denied.
- Concern submissions retain every form field, including requested action.
- Every authorized emergency transition succeeds and every unauthorized transition fails in emulator tests.
- Job interest and civic points complete once, securely, without partial-record corruption.
- App, admin mapper, rules, functions, and tests use the same status and notification wire values.

### Phase 4 — Establish shared application infrastructure

Goal: create small, reusable boundaries before splitting feature screens.

- [ ] Add a manual composition root that creates repositories/services once and passes them to controllers/screens.
- [ ] Define typed application failures for auth, permissions, offline/network, validation, upload, and unknown failures.
- [ ] Add one UI error mapper and shared feedback component instead of feature-specific raw exception SnackBars.
- [ ] Add reusable loading, empty, error-with-retry, and permission-denied states.
- [ ] Create a shared media-upload service that enforces:
  - allowed content types;
  - maximum byte size;
  - normalized file names/paths;
  - optional image resizing/compression using existing capabilities;
  - upload progress;
  - consistent cleanup/rollback behavior.
- [ ] Extract shared reverse-geocoding/location behavior used by request-help and offer-help, with a timeout, cancellation/mounted handling, and a clear application user agent.
- [ ] Centralize field validators for email, Philippine mobile number, password, required text, and attachment constraints.
- [ ] Centralize routes/navigation destinations without introducing a routing dependency solely for cleanup.
- [ ] Add Firestore converters/mappers per aggregate rather than parsing maps in widgets.

Acceptance criteria:

- UI widgets no longer expose raw Firebase exception strings.
- Repositories can be replaced with fakes in tests.
- Upload and location workflows have one implementation and focused tests.

### Phase 5 — Split the application shell and `home_screen.dart`

Goal: reduce mixed responsibilities while preserving the existing navigation and visual language.

Perform these extractions one at a time and test after each:

- [ ] Extract the authenticated application shell and bottom navigation.
- [ ] Extract the home header/weather/location widget and its state.
- [ ] Extract bulletin/feed query controller and filter model.
- [ ] Extract reusable post card and post-detail presentation.
- [ ] Move announcement composer and announcement list into the announcements feature.
- [ ] Move notification list/badge behavior into the notifications feature.
- [ ] Move emergency responder widgets into the emergencies feature.
- [ ] Move service-grid and archive presentation into their respective features.
- [ ] Move custom painters only with the widget they support; delete painters proven unused.
- [ ] Remove `_warmDashboardPages()` and allow `IndexedStack` children to initialize when first visited, while preserving state for visited tabs.
- [ ] Make each extracted widget accept data/callbacks or a feature controller rather than reaching into global mutable services.

Do not target an arbitrary final line count. The extraction is complete when the shell primarily coordinates navigation and each extracted module has one clear responsibility.

Acceptance criteria:

- Home, alerts, concern, services, and profile tab state is preserved after tab changes.
- Initial dashboard startup no longer opens/listens to every tab's data source.
- No user-visible feature is lost.
- Widget tests cover navigation, loading, empty, error, and populated feed states.

### Phase 6 — Refactor feature screens by risk and duplication

Goal: move business logic out of widgets and eliminate duplicated workflows.

Recommended order:

1. **Concern center**
   - [ ] Separate draft/form state, attachment selection, submission repository, and confirmation UI.
   - [ ] Add tests for draft ownership, required fields, upload failure, write failure, and successful submission.
2. **Request help and offer help**
   - [ ] Extract a shared location/media form foundation while keeping feature-specific fields and labels explicit.
   - [ ] Prevent duplicate submissions and preserve uploaded-media consistency.
3. **Jobs and marketplace**
   - [ ] Separate browse/filter/detail/completion/interest behavior.
   - [ ] Use server-authorized civic-point and notification flows from Phase 3.
   - [ ] Add pagination/limits where collections can grow.
4. **Sign-up, login, onboarding, and profile**
   - [ ] Use shared validators and status models.
   - [ ] Keep onboarding behavior unchanged unless the product decision changes.
5. **Maps and directory pages**
   - [ ] Move hardcoded records into immutable typed data files/repositories.
   - [ ] Keep external image/map failures visible but non-fatal.
   - [ ] Consolidate common directory card/list/detail components only where fields genuinely align.
6. **Carabao game**
   - [ ] Isolate game state, rendering, audio lifecycle, and asset manifest.
   - [ ] Confirm timers, tickers, and audio resources stop when leaving the screen.

Acceptance criteria:

- No feature screen owns both complex Firebase serialization and a large widget tree.
- Duplicate location and upload code is removed.
- Every refactored feature has focused public-behavior tests.

### Phase 7 — Theme, readability, responsiveness, and accessibility

Goal: make the app consistently readable and overflow-resistant without redesigning its identity.

- [ ] Expand the current E-Sugid palette into semantic tokens: primary, surface, background, border, textPrimary, textSecondary, success, warning, danger, info, and on-colors for light/dark themes.
- [ ] Define a centralized text scale using the existing font families. Replace hundreds of ad hoc `GoogleFonts` calls gradually.
- [ ] Treat 12 logical pixels as the normal minimum for supporting text; use smaller type only for a justified compact badge and verify accessibility scaling.
- [ ] Remove `FittedBox` usage that silently shrinks important labels. Prefer flexible layout, wrapping, ellipsis for noncritical metadata, or responsive rearrangement.
- [ ] Replace hardcoded white/black/surface colors so dark theme has adequate contrast.
- [ ] Consolidate custom page headers around `ESugidPageHeader` or a small set of documented variants.
- [ ] Replace unexplained fixed heights with content-driven constraints, `Flexible`, `Expanded`, `Wrap`, and scroll boundaries where appropriate.
- [ ] Test all primary pages at widths 240, 320, 390, and 600 logical pixels and text scales 1.0, 1.3, and 2.0.
- [ ] Verify keyboard insets, safe areas, landscape where supported, and long Filipino/English labels.
- [ ] Add semantic labels and adequate touch targets to icon-only controls.
- [ ] Add golden or screenshot tests only for stable, high-value shared components; do not create a brittle screenshot suite for every screen.

Acceptance criteria:

- No Flutter overflow indicators appear in the responsive test matrix.
- Primary text and form labels remain readable without relying on highlight/selection.
- Light and dark themes pass a manual contrast review.
- Shared headers, inputs, buttons, cards, and feedback states are visually consistent.

### Phase 8 — Notifications, streams, performance, and network reliability

Goal: remove session leaks and unnecessary background work.

- [ ] Initialize notification registration after both Firebase Auth and the app user profile are available.
- [ ] Save and refresh FCM tokens for the current account, and remove/unassociate the token on logout as appropriate for the backend model.
- [ ] Move topic sync out of widget `build`; await/cancel it in session lifecycle code.
- [ ] Show foreground notifications using the existing in-app/local notification strategy.
- [ ] Clear or key static stream caches by authenticated UID and dispose subscriptions on logout.
- [ ] Replace unbounded streams with query limits/pagination for feeds, submissions, jobs, marketplace, and notifications as data volume warrants.
- [ ] Avoid reading full-resolution image bytes into memory when a streamed/file upload is available.
- [ ] Add timeouts and typed errors to reverse geocoding, weather, and other direct network calls.
- [ ] Cache only structurally safe data and define invalidation; do not add speculative caching.
- [ ] Profile startup and tab switching before and after removing eager page warming.

Acceptance criteria:

- Switching users cannot display prior-user streams, drafts, badges, or notification topics.
- Initial app startup does not create listeners for unvisited features.
- Offline and timeout states are actionable rather than appearing as empty content.

### Phase 9 — Unused code, files, assets, and dependency cleanup

Goal: remove only items whose lack of use has been proven after refactoring.

Follow the deletion protocol in Section 10 for every item.

#### Confirmed or high-confidence code candidates

- [ ] Delete the two dashboard wrapper files after Phase 2 call-site replacement:
  - `lib/barangay_official_dashboard.dart`
  - `lib/partner_organization_dashboard.dart`
- [ ] Re-evaluate public service/model members found only at their definitions or only in legacy tests:
  - `CommunityService.createAlert`
  - `CommunityService.postMatchesUser`
  - `SubmissionService.updateSubmissionStatus`
  - `DocumentRequestService.updateRequestStatus`
  - `EmergencyService.reportsForResident`
  - `AuthService.userStream`
  - `User.verificationLabel`
- [ ] Delete a member only if its product workflow is now handled elsewhere. Remove/update tests that describe the deleted legacy API.
- [ ] Remove `cupertino_icons` from `pubspec.yaml` after confirming zero imports and rerun dependency resolution/build.

#### Asset candidates with no current source reference

Resident-dashboard directory (currently included by its directory-level pubspec entry):

- [ ] `assets/images/resident_dashboard/04-08-Sta-Ana-Church-in-Barili.jpg`
- [ ] `assets/images/resident_dashboard/HALL.jpg`
- [ ] `assets/images/resident_dashboard/Mantayupan-Falls-in-Barili-Cebu2.jpg`
- [ ] `assets/images/resident_dashboard/README.md`
- [ ] `assets/images/resident_dashboard/esugid-logo.png` — **do not delete without visually confirming which official logo is canonical**.

Game assets with no current source or pubspec reference:

- [ ] `assets/images/games/forest-background-3d.png`
- [ ] `assets/images/games/tabuan-sa-mantalongon-ending-3d.png`
- [ ] `assets/images/games/forest-obstacles-chroma.png`
- [ ] `assets/images/games/farmer-chroma.png`
- [ ] `assets/images/games/carabao-chroma.png`
- [ ] `assets/images/games/farmer-chaser.png`
- [ ] `assets/images/games/carabao.png`
- [ ] `assets/images/games/market-cutscene-panorama-3d.jpg`
- [ ] `assets/images/games/tabuan-sa-mantalongon-ending-3d-mobile.jpg`
- [ ] `assets/images/games/farmer-run-1.png` through `farmer-run-6.png`
- [ ] `assets/images/games/carabao-run-1.png` through `carabao-run-6.png`

Declared assets with no literal Flutter source reference:

- [ ] `assets/images/games/forest-background-3d-mobile.jpg`
- [ ] `assets/images/games/fnllogo.png`

These require runtime/game-manifest inspection before deletion; a directory-level asset declaration can hide dynamic use.

Other candidates:

- [ ] Remove the empty `assets/images/officials/` directory and its pubspec entry if it remains empty and no upcoming code relies on the directory.
- [ ] Rename the referenced `ChatGPT Image ...` asset to a stable descriptive kebab-case name and update references; it is not unused.
- [ ] Audit actual Google Fonts family/weight use before pruning font files. Families currently used include Poppins, Outfit, Manrope, Montserrat, and Roboto Mono. Do not delete fonts just because searches do not find their filenames; `google_fonts` can resolve them indirectly.
- [ ] Inspect root `flutter_01.png`; delete it only if it is a screenshot/debug artifact and is not documentation.

#### Generated and local artifacts

These are cleanup candidates, not application assets:

- [ ] `build/`
- [ ] `.dart_tool/`
- [ ] `.idea/` workspace state
- [ ] `.flutter-plugins-dependencies`
- [ ] `firebase-debug.log`
- [ ] `firestore-debug.log`
- [ ] `.playwright-cli/`
- [ ] `tmp/` after classifying its contents
- [ ] `output/` after classifying its contents
- [ ] `node_modules/` under admin, functions, or rules-test projects when preparing a source-only archive; restore with the relevant lockfile/package manager.

Do not delete dependency directories from an active developer workspace merely to reduce a working-directory size unless the user is preparing a clean archive. Ensure generated artifacts are ignored by source control.

Acceptance criteria:

- Every deletion has written evidence from the protocol.
- `flutter analyze`, all tests, and debug build pass after deletions.
- The packaged Flutter asset size is measured before and after and the difference is recorded.
- The canonical E-Sugid logo and every dynamically loaded game/font asset remain available.

### Phase 10 — Dependency and Android release readiness

Goal: make production packaging explicit without destabilizing the core cleanup.

- [ ] After all earlier phases are green, run `flutter pub outdated` and upgrade one package family at a time.
- [ ] Upgrade FlutterFire together only after reading its migration notes and rerun auth, Firestore, Storage, messaging, and functions tests.
- [ ] Upgrade geolocation/maps, fonts, and utility packages in separate changes.
- [ ] Do not change a lockfile unless dependency constraints or resolved packages intentionally change.
- [ ] Replace `com.example.esugid` with the approved production application ID/namespace using a documented migration plan for Firebase Android configuration.
- [ ] Configure release signing through untracked properties/environment/secrets. Never commit keystore credentials.
- [ ] Remove the placeholder Google Maps API metadata if the native Google Maps SDK is not used; otherwise configure the key securely.
- [ ] Set the approved application label, icon, and package metadata.
- [ ] Verify current Play/Android target requirements at execution time rather than guessing a version from this document.
- [ ] Build and test a signed release candidate on at least one physical Android device.

Acceptance criteria:

- No production build uses debug signing, placeholder package identity, or placeholder API keys.
- Major dependency upgrades are isolated and verifiable.
- Debug and release builds pass from a clean environment.

## 8. Required Test Matrix

### Unit tests

- User account-status and verification-status legacy parsing.
- Canonical status transitions for concerns, emergencies, requests, jobs, and announcements.
- Firestore timestamp parsing, including missing/malformed values.
- Philippine mobile-number normalization and length constraints.
- Role/capability checks for resident, barangay, partner, LGU, and super-admin.
- Notification schema parsing for canonical and supported legacy documents.
- Civic-points idempotency logic in trusted backend tests.

### Widget tests

- Auth session gate for signed-out, loading, pending, active, suspended, and error states.
- Login and real password-reset success/failure.
- Sign-up resident-only behavior.
- Home navigation state and lazy tab initialization.
- Concern draft, validation, attachment, submission, retry, and confirmation.
- Stream loading, populated, empty, permission denied, offline, and retry states.
- Shared header/form/card components under large text scale and narrow screens.

### Firebase emulator/integration tests

- Resident can create/read own profile and allowed submissions but cannot assign privileged roles.
- Barangay staff can read and update only same-barangay verification/concern records.
- Partner staff cannot approve verification.
- LGU/super-admin authorized scope remains intact.
- Concern attachments follow the same authorization boundary as their Firestore records.
- Emergency transition payloads succeed only for authorized roles and valid transitions.
- Job interest creation and owner notification are authorized and consistent.
- Civic points are awarded exactly once by trusted code and cannot be written directly by clients.
- Announcements are visible only to their municipality/barangay/organization audience.

### Manual device matrix

- Small phone: 240–320 logical-pixel width.
- Typical phone: approximately 390 logical-pixel width.
- Large phone/tablet: 600+ logical-pixel width.
- Text scale: 1.0, 1.3, and 2.0.
- Light and dark theme.
- Online, offline at launch, and connection lost during submission.
- Resident, barangay staff, partner staff, LGU, and super-admin test accounts.

## 9. Commands to Run at Every Stable Milestone

Use the repository's Flutter SDK and run from the project root.

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Also run the repository's existing Firebase rules/functions test scripts whenever a schema, rules, Storage path, Cloud Function, or authorization contract changes. Do not invent a replacement command; inspect `package.json`, `firebase.json`, and the relevant test README/scripts at execution time.

For a release milestone:

```powershell
flutter build apk --release
```

Run release packaging only after signing and environment configuration are intentionally set.

## 10. Proof Required Before Deleting Any File

For every proposed deletion, record all of the following in the implementation notes:

1. Exact path and why it appears unused.
2. `rg` search for the filename, import URI, class/symbol, asset key, and normalized path.
3. Check for dynamic lookup, generated registries, reflection-like maps, route tables, platform configuration, pubspec directory declarations, tests, documentation, and build scripts.
4. Check case-insensitive references because development is on Windows while CI/build tooling may be case-sensitive.
5. For assets, run or inspect every screen that could load the asset dynamically. For fonts and game sprites, inspect manifest-building code rather than relying only on literal filename search.
6. For code, remove references first, then let analyzer/compiler confirm there is no missing symbol.
7. Run formatting, analyzer, all tests, and a debug build after the deletion batch.
8. Keep deletion batches small and grouped by responsibility so a regression can be traced.

Classification rules:

- **Confirmed unused:** no static/dynamic/config/test/doc reference and build/tests pass without it. Delete.
- **Redundant but used:** replace call sites with the canonical implementation, then delete.
- **Generated/local artifact:** ensure it can be regenerated and is ignored; remove only from the intended workspace/archive.
- **Uncertain or roadmap-related:** keep it and add a documented follow-up. Do not guess.

## 11. Known Decisions That Still Need Product Confirmation

These are not blockers for Phases 0–3 because defaults are provided in Section 3.

1. Should onboarding remain on every app launch, or be shown only until completion/version change?
2. Which staff workflows must remain available in the mobile app versus the canonical admin web?
3. Which image is the legally/currently approved E-Sugid seal/logo for all surfaces?
4. Should static municipal directory content remain bundled, move to Firestore, or be managed through the admin web?
5. What is the retention period for legacy notification, concern, and attachment schemas?

If the owner does not answer during execution, preserve current behavior and do not delete uncertain data/assets.

## 12. Completion Checklist

- [ ] All P0 defects are fixed with tests.
- [ ] All P1 reliability defects are fixed or explicitly deferred with rationale.
- [ ] `flutter analyze` reports zero findings.
- [ ] `dart format --output=none --set-exit-if-changed lib test` exits successfully.
- [ ] All Flutter tests pass.
- [ ] Firebase rules/functions tests pass.
- [ ] Debug APK builds from a clean workspace.
- [ ] Release build uses production identity/signing/configuration.
- [ ] Responsive/accessibility matrix has no known overflow or unreadable text.
- [ ] Auth, concern, emergency, announcement, verification, job-interest, civic-points, and notification flows have been manually smoke-tested with the correct roles.
- [ ] No stale-user data remains after logout/account switch.
- [ ] Every removed file/asset has deletion evidence.
- [ ] No canonical logo, font, dynamically loaded asset, or roadmap file was deleted accidentally.
- [ ] Final diff contains no admin-web redesign or unrelated changes.
- [ ] Documentation describes any migration, environment setup, and remaining product decision.

## 13. Execution Log Template

Copy this block under each completed phase.

```markdown
### Phase N execution result

- Date:
- Implementer/model:
- Files changed:
- Behavior changed:
- Migrations/backward compatibility:
- Deletions and proof:
- Commands run and results:
- Manual checks:
- Remaining risks:
- Deviations from plan and reason:
```

The executor must not mark a phase complete merely because the app compiles. The phase-specific acceptance criteria and relevant runtime workflow must also pass.

## 14. Execution Result â€” August 15, 2026

### Completed work

- Established `FLUTTER_BASELINE_MANIFEST.sha256`, cleaned generated Flutter
  state, restored dependencies, formatted the Dart tree, and reached a clean
  analyzer/test/debug-build baseline.
- Removed analyzer-confirmed dead declarations and lifecycle leaks, including
  owned controllers, subscriptions, async-context hazards, and deprecated API
  use.
- Made public sign-up resident-only, made login domain-neutral, implemented real
  Firebase password reset, added registration rollback, and established a
  single auth/session route authority with a retryable Firebase bootstrap.
- Split `accountStatus` from `verificationStatus` with legacy-safe parsing and
  documented the additive backfill in `FIREBASE_DATA_CONTRACT_MIGRATION.md`.
- Versioned concerns, preserved resident/barangay identity and requested action,
  scoped drafts by UID, aligned attachment paths/rules, and introduced an
  injectable concern repository boundary.
- Canonicalized emergency transitions and updater history; authorized job
  interests; moved cross-user notifications and civic-point awards to trusted,
  idempotent Functions; and expanded emulator regression coverage.
- Made notification initialization profile-aware, made foreground messages
  visible, removed device tokens before logout, cancelled stale initialization,
  cleared user-scoped caches/topics, and removed eager dashboard page warming.
- Extracted the authenticated bottom navigation/painter from `home_screen.dart`,
  added role-aware semantics, and added narrow/large-text regression tests.
- Consolidated request/offer location behavior with permission guidance,
  network timeouts, deterministic parsing, and tests. Their image uploads now
  stream from files and roll back orphan uploads when the Firestore write fails.
- Added semantic palette/spacing tokens, safe async error UI, deterministic
  Firestore date fallbacks, collection limits, and a required 12px supporting
  text minimum outside the intentionally compact game HUD.
- Removed the redundant staff dashboard wrappers, unused client-authoritative
  service APIs, `cupertino_icons`, the empty officials asset declaration, 27
  proven-unused images/docs, and renamed the generated brand image to
  `esugid-community-mark.png`. Assets decreased from the audited ~56.5 MB to
  41.44 MB.
- Removed the placeholder native Google Maps key, used the Flutter-managed
  Android target SDK, stopped release builds from using debug signing, and
  documented local keystore setup.

### Verification recorded

- `dart format --output=none --set-exit-if-changed lib test`: 71 files,
  zero changes required
- `flutter analyze`: zero findings
- `flutter test`: 56/56 tests passed
- `flutter build apk --debug`: produced
  `build/app/outputs/flutter-apk/app-debug.apk`
- Firebase emulator suite: 37/37 Firestore and Storage tests passing
- `npm run lint --prefix functions`: passed
- `npm run build --prefix admin_web`: passed and regenerated `app.bundle.js`

### Deliberately staged items

- The Android application ID remains `com.example.esugid` until the owner chooses
  the permanent ID and registers its matching Firebase Android app. Changing it
  independently would break Firebase initialization.
- A signed release candidate requires the owner's untracked production
  keystore and a physical Android device. No debug key is used for release.
- The plan's destination feature tree is being adopted incrementally. The
  bottom navigation and concern/location boundaries were extracted, but a bulk
  move of every home/feed/directory/game widget was intentionally avoided; such
  a rewrite would exceed the plan's smallest-coherent-change and
  behavior-preservation rules.
- Full authenticated manual role/device/offline smoke testing requires test
  accounts and a physical/emulated Android session. Automated responsive tests
  cover the shared header, status strip, floating tabs, auth screens, and bottom
  navigation at the supported narrow widths and enlarged text.
