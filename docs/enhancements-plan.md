# ThoughtStash enhancement plan

## Cross-device note sync

### Recommended architecture

- Keep the local `notes.json` store as an offline-first cache so capturing and editing never waits on a network request.
- Add stable per-record metadata: `updatedAt`, `deletedAt` tombstones, and a monotonically increasing server revision. Give sections the same sync metadata as notes.
- Run a small self-hosted API (PostgreSQL plus a lightweight service) behind HTTPS. Authenticate each user/device with short-lived access tokens and revocable refresh tokens stored in Keychain.
- Expose a revision cursor protocol: push local mutations in batches, then pull all changes after the last acknowledged revision. The server assigns revisions transactionally and makes mutation IDs idempotent.
- Resolve independent edits with last-write-wins initially, but never silently discard concurrent note-body edits: preserve the losing body as a conflict copy. Section moves and completion state can use field-level last-write-wins.
- Trigger sync after local saves, on app activation, and periodically with exponential backoff. Surface a compact status: synced, syncing, offline, or action required.

### Delivery phases

1. Evolve the local schema and add a migration with sync metadata and tombstones.
2. Define and test the API contract (`/devices`, `/sync/push`, `/sync/pull`) and deploy PostgreSQL-backed service with TLS, backups, rate limits, and structured logs.
3. Add Keychain-backed sign-in/device registration and the client sync engine. Test retry, duplicate mutation, offline editing, and clock-skew cases.
4. Add conflict-copy UX, sync status, manual “Sync now,” and device revocation.
5. Pilot with two devices, simulate network loss and concurrent edits, then enable automatic sync by default after restore-from-backup is exercised.

### Server operations checklist

- Daily encrypted database backups with a documented restore drill.
- HTTPS certificates with automatic renewal; firewall exposes only HTTPS and administration access.
- Health checks and alerts for failed syncs, high error rates, disk pressure, and stale backups.
- Database migrations are backward-compatible for at least one released client version.

## Larger distraction-free editor

Start with a focused editor scene rather than changing the existing modal. It should use nearly the full window, cap the text column at a readable width, hide section controls and metadata while typing, and reveal a small top bar on pointer movement or keyboard focus. Keep Save, Cancel, section selection, character count, and sync state accessible through shortcuts and the revealed bar.

Four iterations are now runnable in the storybook — see [`focus-mode-iterations.md`](focus-mode-iterations.md) (`swift run ThoughtStash --zen-lab`). The two originally proposed here are variants 1 (Curtain) and 2 (Desk):

1. A full-window overlay entered from the current editor, with a centered 680–760 pt writing column and an explicit exit shortcut.
2. A separate resizable editor window that can remain open beside other apps.

Evaluate both with long notes, small laptop screens, VoiceOver, keyboard-only navigation, and unsaved-change recovery. Choose the overlay if the goal is a short capture-to-edit flow; choose the separate window if users commonly keep a note open for extended writing.
