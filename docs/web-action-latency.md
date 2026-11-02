# Web action response time

The save path has two separate goals: acknowledge the click immediately, and confirm success only after the server commits the actual record. Neither a spinner nor optimistic success makes an unsaved record safe.

## Findings and changes

- Web callables already use Singapore (`asia-southeast1`). No region migration is needed.
- Concern review previously waited for a supplemental co-reporter query, notification writes, device-token queries, FCM delivery and invalid-token cleanup after committing the concern. Complaint tracking and verification decisions also waited for FCM after the transaction.
- These three operations now write a `web_notification_outbox` job inside the same transaction as the action, audit log and primary in-app notification. A separate Firestore worker delivers push and, for concerns, adds any legacy co-reporters. Success still requires the database commit. Normal duplicate events are suppressed; leases recover interrupted workers and retry failures up to eight attempts. Failed jobs remain inspectable. As with other FCM delivery, a crash between send and acknowledgement can repeat a phone push.
- Deploy `deliverWebActionNotification` before deploying its three producers. The collection has no client read/write rule and is server-only. Monitor worker failures and `failed` outbox jobs; these changes do not introduce a paid always-on instance.
- Resident verification reuses the already authenticated caller instead of fetching the same profile twice. Permission checks remain fresh and unchanged.
- Announcement covers larger than 384 KB are encoded as WebP at up to 2048 pixels on their longest side, only when this reduces bytes by at least 10%. Transparency remains intact; small/unsupported images keep their original bytes. Proof/identity documents are not changed. Uploads show progress and the composer suppresses overlapping draft/publish submissions.
- Shared busy buttons show immediate activity, and complaint saves show Saving with duplicate suppression, error recovery and the same operation ID on retry.
- Callable timings are available locally in the browser Performance panel as `esugid:call:<function>:<sequence>` (last 100 requests, outcome only, no payloads). Server commit and worker delivery durations are logged separately. This allows later p50/p95 measurements without recording form contents.

## Limits and follow-up

There is no production p50/p95 benchmark from an authenticated user submission in this change; tests use synthetic data and controlled delays to avoid changing resident records. Network latency, upload bandwidth, Firestore work and cold starts still affect confirmation time. Warm minimum instances can reduce cold starts but incur standing costs, so none were enabled. Do not claim all actions finish instantly. Remaining account, emergency, organization and other callables retain their existing delivery behavior pending measurement and a separately scoped migration.

Validation covers backend queue retries/leases, atomic commit before response, failure recovery, duplicate submits, large-image byte reduction, existing complaint/summons/CFA and verification behavior. Deploy and verify Hosting after the web change. Keep the existing signed APK.
