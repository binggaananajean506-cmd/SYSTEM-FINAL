# Bayanihan Messaging Data Contract

## Scope

The request collection remains `jobs`. A request is a job whose `category` is
`request`. The messaging feature does not create a second copy of the request.

New help offers are stored at:

```text
jobs/{requestId}/interests/{helperId}
```

Each offer has exactly one private conversation:

```text
bayanihan_conversations/{requestId}_{helperId}
bayanihan_conversations/{conversationId}/messages/{messageId}
```

Conversation IDs are deterministic and cannot be chosen by the client. The
requester and helper are copied into the conversation for secure participant
queries, but status transitions remain server-authoritative.

## Status contract

Offers use `pending`, `accepted`, `declined`, `completed`, `cancelled`, or
`withdrawn`. Conversations use `pending`, `active`, `declined`, `completed`,
`cancelled`, or `withdrawn`.

Only `active` conversations accept new messages. Every other status is
read-only. Terminal conversations are retained for history and audit.

## Backward compatibility

- Existing `jobs` without `helpersNeeded` are treated as needing one helper.
- Missing `acceptedHelperCount` is treated as zero.
- Existing `jobs/{jobId}/interests` documents are retained and remain readable
  to their original helper and requester. They are not deleted.
- Historical `chats` are no longer exposed or writable because they did not
  enforce a Bayanihan request/offer relationship.
- No destructive migration is required for existing requests. New offers use
  the versioned conversation contract automatically.

If historical pending interests must be restored into the new inbox, perform a
one-time privileged backfill that validates each parent request and creates the
deterministic conversation. Do not recreate them from an untrusted client.

## Multiple helpers

New request documents write `helpersNeeded` and default to one. Accepted offers
update `acceptedHelperCount` and `acceptedHelperIds` transactionally. Each
helper receives a separate private conversation; group chat is intentionally
not supported.

## Optional future enhancement

Post-completion appreciation tags are staged. Civic credit is already awarded
once per accepted helper through the trusted completion Function. Public star
ratings are intentionally excluded.
