# E-SUGID Approved Performance Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the approved audit's safe cleanup, selective reconciliation and performance fixes while preserving E-SUGID's features and Firebase contracts.

**Architecture:** Retain root as the working target and preserve the nested source copy. Reuse existing services/widgets and isolate lifecycle/state work at current feature boundaries. Avoid broad architecture or public API changes.

**Tech Stack:** Flutter/Dart Android; vanilla JavaScript/CSS with esbuild/Playwright; Firebase Functions Node 22 and security rules.

**Spec:** User's four-phase request and `output/workspace-audit-2026-10-17/README.md`, approved by the October 17 `proceed` message.

## Global constraints

- Preserve all Firestore/Storage paths, statuses, public interfaces, function exports, roles and security boundaries.
- Keep `esugid/` intact. Do not retire compatibility/feature APIs or delete assets that may have persisted references.
- Do not add/upgrade application dependencies or edit lockfiles without necessity.
- No Git initialization, branches, commits, pushes or PRs: both downloaded Git metadata directories are empty and user disallows unrequested Git writes.
- Preserve original touched source in a local review baseline; review patches against that baseline rather than unavailable Git history.
- Test behavior changes using meaningful regressions; configuration/mechanical private-code removal uses existing checks and smoke tests.
- Every web edit requires build, staging, Firebase Hosting deployment and verification of `/` redirect and `/admin` HTTP 200 before ending.
- Do not alter Windows security/Developer Mode settings or production signing to bypass environment limitations.

## Review focus

1. Stream retry/reconnect/account changes: cached streams must refresh when identity/input changes and after terminal errors.
2. Async completion after disposal: no setState/controller mutation after unmount or clearing a newer user draft.
3. Query bounds: preserve complete search/history/management semantics; paginated/live queries must not silently hide records.
4. Safe errors: preserve useful domain validation while suppressing internal error details.
5. Web ordering: early theme selection, globals/inline handlers and Firebase initialization must continue to work after bundling/defer changes.

## Task 1: Flutter lifecycle and nested reconciliation

**Files:** `lib/core/errors/user_facing_error.dart`; selected Bayanihan/marketplace conversation widgets and services; notification inbox; existing targeted tests plus `test/user_facing_error_test.dart`.

**Interfaces:** Preserve existing service method signatures and stream/model types. Adopt nested changes selectively rather than copying whole files. Keep account changes and retry behavior.

- [ ] Read root/nested diffs and current callers/tests.
- [ ] Add focused behavior tests that expose safe-error and stream-recreation/draft-loss defects; run failing tests first where environment allows.
- [ ] Adopt mapper/async/listener fixes with proper initState/didUpdateWidget/dispose/retry behavior.
- [ ] Run targeted Flutter tests and analysis; report actual environmental blockers without claiming a pass.
- [ ] Review the task patch against the baseline and resolve review findings.

## Task 2: Flutter screen/image/query performance

**Files:** `lib/home_screen.dart`; selected current service/page/widget hotspots identified by source inspection; their existing focused tests; `lib/emergency_alert_service.dart`.

**Interfaces:** Preserve navigation, notification, image and query contracts. Reuse current caches and lazy list structures.

- [ ] Inspect build-time work, list construction, images, Firestore streams and owned controller disposal.
- [ ] Write behavioral regressions for concrete changed state/query/lifecycle logic; avoid source-text tests.
- [ ] Fix repeated reads/computation/listener creation and image decode sizing where demonstrated; add const only when semantically appropriate.
- [ ] Fix the unawaited try-block Future and deprecation findings without changing failure behavior.
- [ ] Keep live/management queries complete unless proper pagination is implemented and tested.
- [ ] Run relevant tests and static analysis, then review the task patch.

## Task 3: Web and Firebase cleanup/performance

**Files:** `admin_web/app.js`; `admin_web/scripts/build-admin.mjs`; `admin_web/index.html` only if ordering improvement is justified; `functions/index.js`; affected existing helper/Playwright tests.

**Interfaces:** Preserve all 85 exported Firebase handlers and inline/global web callbacks. Keep theme initialization before first render.

- [ ] Revalidate the audit's exact unused declarations/imports/values and duplicate helper contracts against current source.
- [ ] Add real behavior coverage before changing duplicate helper or query behavior; preserve the later hoisted contract if consolidating.
- [ ] Remove only proven private dead declarations/imports and configure production bundle minification.
- [ ] Inspect initial dashboard listener/query setup and modular Firebase imports; implement only concrete reductions that preserve data visibility and authorization.
- [ ] Run Functions syntax/unit checks and relevant web smoke/layout checks; review generated output and source patch.
- [ ] Root controller runs the mandatory full build/stage/deploy/live-verification pipeline after integration and fixes.

## Task 4: Android host/build settings, integration and delivery

**Files:** `android/gradle.properties`; local ignored `android/local.properties`; audit implementation report.

**Interfaces:** Keep AGP/Kotlin/plugin versions, app identity and signing configuration. Use the actual detected SDK paths and a memory budget compatible with a 16 GiB host.

- [ ] Verify installed Android/Flutter/Java and Firebase CLI prerequisites and make a review baseline.
- [ ] Replace oversized JVM reservation with 4 GiB heap / 1 GiB metaspace; enable daemon, parallel execution and build cache; remove the explicit VFS watcher disable.
- [ ] Correct local SDK paths without putting machine-specific paths into tracked configuration.
- [ ] Attempt available Flutter test/build checks without altering OS security settings; record exact failures and commands to rerun.
- [ ] Run full applicable Functions and Flutter suites once after integration, broaden only for new concerns.
- [ ] Fresh review of all source changes against baseline, including deferred findings and protected contract export/path checks.
- [ ] Build admin, stage hosting, deploy using the available Firebase CLI (isolated npm execution if CLI is missing), verify root redirect and admin 200; report failure honestly if credentials/network block it.
- [ ] Update the implementation report with changed files, measurements, test evidence, remaining blockers and required actions.

## Execution record

The user has already approved execution. Do not request another plan approval. The task-specific reports and local baseline replace unavailable Git commits/diff packages. All independent source areas have explicit ownership to avoid overlapping edits. Reviewer findings require resolution before completion; no source copy or baseline is deleted.
