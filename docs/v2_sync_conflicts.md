# V2 Sync Conflict Strategy

The V2 sync layer uses a pragmatic strategy designed for understandable behavior rather than perfect distributed merge semantics.

## Metadata

Each synced record carries:

- `version`
- `updatedAt`
- `deletedAt`

`deletedAt` is a soft-delete tombstone. A non-empty value means the record is logically deleted and should be hidden from normal UI flows while still being propagated during sync.

## Conflict Resolution

The chosen strategy is:

1. Compare `version` first.
2. If versions differ, the higher `version` wins.
3. If versions are equal, compare `updatedAt`.
4. If versions are equal and the incoming `updatedAt` is newer, last-write-wins.
5. If the remote record is newer, the backend rejects the stale write with `409 Conflict`.

On Flutter V2 push:

- a `409` does not abort the whole sync batch
- the client keeps the remote record as source of truth for that resource
- a reconciliation pull runs after push so local storage receives the current server versions/tombstones

## Deletions

- Deletes are soft deletes for synced V2 resources
- the app writes `deletedAt` instead of silently removing the record from sync payloads
- tombstones remain exportable and syncable
- user-facing lists should filter out records where `deletedAt` is set

## Scope

This is intentionally simple:

- no per-field merge
- no CRDT
- no offline conflict UI yet

The goal is to avoid silent overwrite, keep behavior predictable, and make future evolution possible without breaking stored JSON.
