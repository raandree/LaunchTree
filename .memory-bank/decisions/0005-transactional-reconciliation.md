---
id: ADR-0005
status: accepted
date: 2026-07-28
last-verified: 2026-07-28
owner: developer-and-release-owner
source: signed Design Concept
---

# ADR-0005: Reconcile Generated State transactionally

## Context

Deployment automation changes Entry Roots independently of the module. Partial
Start Entry updates would leave users with missing or stale launch targets, and
the module must not alter unrelated Start content.

## Decision

Make Reconciliation explicit and deployment-triggered. Stage all changes,
track module ownership, reject collisions with unowned shortcuts, and commit as
one transaction. Restore prior Generated State after any failed step.

Removal deletes only Generated State. Administrator-authored configuration and
all source content remain untouched. Support one previous major Generated State
schema and compatible downgrade.

## Consequences

- Reconciliation is idempotent and reversible.
- Ownership metadata becomes a critical but reproducible module artifact.
- One collision prevents the whole transaction instead of producing partial
  state.
- State-changing commands require administrator rights and `ShouldProcess`.

## Requirements

- `FR-022` through `FR-025`
- `QR-011`, `QR-015` through `QR-017`
- `CR-007`, `CR-008`

## Alternatives considered

- Best-effort per-entry updates: rejected because rollback would be ambiguous.
- Delete and recreate all matching shortcuts: rejected because ownership cannot
  be inferred safely by name.
- Runtime Reconciliation: rejected because deployment owns change timing.
