# Resident concern revisions

When an office requests information, the concern remains Awaiting Information
until the resident successfully resubmits it. The detail screen opens an
Edit & Resubmit page with the office request and prefilled title, description,
location, and incident date. Residents can add or replace the evidence photo;
otherwise the existing evidence remains attached.

The page calls the existing `resubmitConcern` callable in `asia-southeast1`.
That function checks resident eligibility, ownership, and the current waiting
status in a transaction. It updates the same document, clears the outstanding
request, appends a resubmission history event, and sets `status: new`, which the
web displays in Active. Recipient, reference, and original submission date are
preserved. Failed saves leave the form and edits available for retry.

The callable must be deployed before using this app flow. If it is absent,
deploy it with `firebase deploy --only functions:resubmitConcern`. Client code
does not fall back to a direct Firestore write after callable errors.

## Verification

Run:

```sh
flutter analyze lib/pages/concern_revision_page.dart lib/pages/concern_center_page.dart lib/submission_service.dart test/concern_revision_test.dart
flutter test test/concern_revision_test.dart test/concern_center_ui_test.dart test/concern_form_test.dart test/concern_submission_test.dart
```

Before release, use a verified resident's waiting concern on a device. Edit its
details, select a photo, and resubmit while the keyboard is open. Confirm the
same reference appears in the web Active list with the revised fields and a
resubmission timeline entry. Also verify offline failure preserves edits, and
that a concern whose status was changed by staff cannot be resubmitted.
