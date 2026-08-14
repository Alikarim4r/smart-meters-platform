# Technical debt

Items deliberately deferred, with the reason and what closing them would cost.

## Platform owner email is hard-coded in source and migrations

`packages/smart_meters_core/lib/security/platform_owner.dart` holds a personal
email address in `kPlatformOwnerEmails`, and migrations `005`, `052` and `056`
reference the same address to grant and protect the owner role.

Deferred because this is authorisation logic, not text. Changing it touches
authentication and RLS behaviour on a live system, and a mistake could lock the
owner out of the platform.

Closing it properly means moving the allowlist into configuration (an
environment variable read at build time, or a dedicated table row) with its own
migration and tests, as a standalone piece of work.

## Real facility data was public before sanitisation

Operational readings, the source workbook and the client-named import package
were committed to this public repository between 2026-07-26 and the
sanitisation commit, and were reachable by anyone during that window.

The current tree is clean. Git history is not: the files remain in the initial
commit `7be9859` and in every commit reachable from it. Removing them from
history requires a rewrite (`git-filter-repo`) and a coordinated force-push, or
publishing from a fresh repository. That decision is open.

Note that neither option recovers copies already taken. Rewriting reduces
future access; it does not undo past exposure.
