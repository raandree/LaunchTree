---
id: ADR-0002
status: accepted
date: 2026-07-28
last-verified: 2026-07-28
owner: developer-and-release-owner
source: signed Design Concept
---

# ADR-0002: Use a directory model with Managed and Personal Content Sources

## Context

Deployment automation owns machine-wide content while users may add roaming
content. The model must be inspectable and deployable by plain file copy.

## Decision

Use the physical directory structure as the navigation model. Immediate child
directories of the Managed Root are Entry Roots. Matching relative paths under
the Personal Root augment those Entry Roots. Equal names remain visible with a
Content Source indicator. Reparse points are ignored.

Only Managed Entry Roots create machine-wide Start Entries. A Content Snapshot
is read per activation; no file watcher is installed.

## Consequences

- GPO and file-copy deployment require no content database.
- Administrators can reason about content with ordinary file tools.
- Personal-only Entry Roots do not appear until a managed Entry Root exists.
- Duplicate names require Content Source context in the Launcher and search.
- Content changes appear on the next activation.

## Requirements

- `FR-001` through `FR-009`
- `QR-004`
- `QR-014`

## Alternatives considered

- A manifest-defined tree: rejected because it duplicates the file structure.
- Personal content replacing managed content: rejected because managed content
  must remain visible.
- Live file watching: rejected because snapshot behavior is simpler and more
  predictable during deployment changes.
