# Firebase Data Contract Migration

This migration is additive and safe to deploy before any backfill. The mobile
app, admin web, Firestore rules, and Storage rules continue to recognize legacy
`status` values while new writes include the canonical fields below.

## User profiles

New and updated profiles use both fields:

- `accountStatus`: `active`, `pending_approval`, `suspended`, or `disabled`
- `verificationStatus`: `not_submitted`, `pending`, `verified`, or `rejected`

The legacy `status` field remains temporarily for older clients. A legacy
resident with `status: approved` is active, but is only identity-verified when
the document has explicit verification evidence (`identityVerified`,
`verifiedAt`, or `verificationApprovedAt`). Staff with legacy
`status: approved` remain active.

Suggested backfill order:

1. Export or otherwise back up the `users` collection.
2. Deploy the compatible rules/functions and clients first.
3. For each resident, set `accountStatus: active` unless the legacy value is
   suspended/disabled. Set `verificationStatus` from explicit verification
   evidence; do not infer verification from `approved` alone.
4. For each staff profile, map legacy `approved` to `active`, pending values to
   `pending_approval`, and rejected/disabled values to `disabled`.
5. Compare role/status counts before and after the backfill and test one account
   for every role before processing the full collection.
6. Retain `status` until all supported clients no longer depend on it.

## Concerns

New concerns use `schemaVersion: 2` and include `userId`, `residentId`,
`residentName`, `barangay`, `requestedAction`, and attachment metadata. New
attachments use `concerns/{userId}/{submissionId}/{fileName}`. The legacy flat
path remains private to the owner and municipal administrators.

Existing concern documents do not need an immediate rewrite. If they are
backfilled, derive barangay and resident name from the referenced user profile,
record the migration timestamp, and never overwrite an existing non-empty
value.

## Emergency reports and notifications

Emergency statuses are `submitted`, `acknowledged`, `responding`, and
`resolved`. Readers normalize legacy `received` and `dispatched` values.
Updates include `updatedBy`, `statusUpdatedAt`, and `statusHistory`.

Canonical notifications use `userId`, `title`, `message`, `type`,
`referenceId`, `navigation`, `read`, and `createdAt`. Cross-user job-interest
notifications and civic-point awards are created by Cloud Functions, not by
mobile clients.

## Rollback

Because the migration is additive, an application rollback can continue using
the retained legacy `status` field. Do not remove canonical fields during a
rollback. Restore rules and functions as a matched set, and restore data only
from the pre-migration backup if a verified data-corruption issue occurred.
