# Barangay complaint tracking

This feature records resident complaints, official review, hearing appointments
and conclusions. Officials use the existing official summons form, print/PDF
preview and resident notice form. Physical service, signed agreements and other
legal documents are handled outside the app. Hearing numbers are tracking numbers;
they do not establish legal stages or eligibility for a Certificate to File Action.

## Workflow

- Filed → Under Review. An official can request specific information or mark an
  intake complaint invalid with a reason. Resident revisions retain the reference,
  original submission and previous details, and return to Under Review.
- Under Review → Hearing Scheduled. The official records the date, time, venue,
  optional assigned official and notes. All appointment times use Philippine time.
- Ordinary appointment editing requires a reason and preserves the old schedule.
  It locks at midnight on the original hearing date, enforced on the server.
- After scheduling, use Generate Official Summons to complete the existing form.
  Its date, time and venue must match the current appointment. Save & Print opens
  the original summons and officer's return, with existing print and PDF actions.
  Generating a summons does not count as a completed hearing or confirm delivery.
- Use Notify Reporter in the preview, or Notify Complainant / Tanod Handoff in
  complaint details. Confirm actual handoff to the assigned tanod before sending
  that notice. The server saves the handoff and resident notification together;
  matching retries do not duplicate it. Handoff does not establish service to the
  respondent. Existing hearing-reminder and mediation notice templates remain.
- A changed hearing supersedes the current summons. Generate a matching form
  before sending another handoff notice. Previous documents remain printable;
  completed or closed hearings cannot send a new summons notice.
- A result can be recorded at or after the scheduled start. Both parties must be
  present for a completed hearing; a conclusion or agreement summary is required.
- Agreement → Resolved. No agreement after hearing 1 or 2 → Awaiting Next Schedule.
  No agreement after hearing 3 → Closed — Unsettled. There is no normal fourth hearing.
- If a party is absent or the session cannot take place, use Hearing Not Held
  on or after the hearing date. Record attendance and a reason. The appointment
  remains in history; a replacement uses the same hearing number.
- A confirmed withdrawal or an agreement outside a hearing finishes the record
  with a required reason and cancels any active appointment without inventing a
  completed hearing. Invalid, withdrawn and unsettled cases are not counted as resolved.
- Passing the appointment time never closes a complaint. Result Pending is an
  attention label until an official records what happened.
- External Update records an event that actually occurred outside the app,
  including its date, notes and optional reference. It can be added after closure.
  Recording or closing a complaint never creates or automatically issues a CFA.

## Dashboard and resident view

Dashboard filters are Needs Action, Scheduled Hearings, Record Results, Finished
and All. Needs Action includes review, scheduling, missing summons, pending tanod
handoff notices and overdue results, with overdue results listed first. A case
can appear in both Needs Action and Scheduled Hearings. Complaints waiting for
the resident are available under All and do not count as work for the official.
Each row has a reference link and one main action for its next task. Scheduling,
summons preparation, resident notices and results open directly from that button.
Details show a five-step guide and a What to do next panel. The original summons
form and print/PDF preview are reused. Common actions such as Edit Schedule and
Hearing Not Held stay beside the main action. Withdrawal, outside agreements,
reissuing a summons and outside updates are under Other actions. Hearing and
activity histories are expandable. The result form has explicit Yes/No agreement
choices, attendance confirmations and a required conclusion; no outcome is
selected by default. Save buttons describe the action they perform.
Residents see the same status, appointments,
attendance, conclusions and external updates. Notifications open the complaint.

## Data and authorization

Records stay in `submissions` with `kind: complaint` and private visibility.
`complaintTrackingVersion: 1` identifies the tracking model. `workflowVersion`
increments for every official mutation and resident revision. `hearings` records
scheduled, completed, not-held and cancelled appointments; only completed
hearings consume the three-hearing allowance. `closureOutcome` distinguishes
`settled` (displayed as Resolved), `unsettled`, `invalid` and `withdrawn`.

`advanceComplaintWorkflow` is the only official mutation endpoint. It checks
approved office access, own barangay or existing municipal oversight, expected
version, server time and allowed transitions inside a Firestore transaction.
Operation receipts in `submissions/{id}/tracking_operations/{operationId}` make
identical retries return their original result without duplicate history,
notifications or audit entries. Receipt reuse with different data is rejected.
Clients cannot read receipts or directly update/delete complaint records.
Generic concern mutation endpoints reject complaints.

Residents use `submitComplaint` for filing and requested revisions. Revisions
check ownership, waiting status, original barangay and expected version; their
notification is saved in the same transaction. Existing evidence is retained
unless explicitly removed or replaced. Upload failures leave the form open.

Previous records remain readable. An active old record with a schedule, summons
or prior hearing stage requires an official to confirm the completed hearing
count from offline records. Summons counts are never converted to hearing counts.
The old position is preserved in `legacyTrackingSnapshot`. A confirmed current
appointment may be imported, including a past appointment awaiting its result.
If three hearings already occurred, confirmation requires the actual final
outcome and conclusion. No historical attendance or hearing events are invented.

## Verification

From `functions`:

```sh
npm run lint
npm test
```

From `admin_web`:

```sh
npm run build
npx playwright test tests/complaint-table.spec.js
```

From the application root:

```sh
flutter analyze lib/submission_service.dart lib/pages/complaint_form_page.dart lib/pages/concern_center_page.dart lib/features/complaints/complaint_tracking_view.dart lib/features/complaints/complaint_service.dart lib/main.dart lib/home_screen.dart test/complaint_tracking_test.dart
flutter test test/complaint_flow_test.dart test/complaint_tracking_test.dart test/concern_submission_test.dart test/concern_revision_test.dart
firebase emulators:exec --only firestore --project e-sugid "node --test --test-name-pattern=\"complaint tracking authorization\" rules_tests/firestore.rules.test.mjs && node --test functions/complaint_tracking.integration.test.js"
```

Use a compatible Java installation for the Firestore emulator. On Windows, if
Java reports an invalid loopback connection while opening its selector, setting
`JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:/Windows/Temp` for that test process
can avoid an excessively long temporary socket path. No system settings need to change.

## Release

The dashboard, functions, rules and resident app belong to the same release.
Deploy the updated callables and rules before publishing the dashboard:

```sh
firebase deploy --only functions:submitComplaint,functions:advanceComplaintWorkflow,functions:reviewConcern,functions:issueConcernSummons,functions:forwardConcern,functions:createConcernSubmissionNotification,firestore:rules
firebase deploy --only hosting
```

Build and distribute the updated Flutter app through the project's normal release
process. Older resident app versions cannot submit requested complaint revisions
with the new version guard. Confirm existing active complaints individually when
the dashboard requests it; a bulk migration is not required.

## Known verification limitation

The broader `resident concerns and notifications` rules suite has four existing
failures: routed concern visibility, IT administrator oversight, barangay case
management, and non-recipient access. The same four tests fail against the
pre-change rules snapshot. Complaint-specific access, query and mutation checks
are verified separately. Review those broader concern rules before a production
rules release; this change does not redesign concern authorization.
