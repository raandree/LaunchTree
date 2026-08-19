---
id: ADR-0007
status: accepted
date: 2026-07-28
last-verified: 2026-08-19
owner: developer-and-release-owner
source: functional specification
---

# ADR-0007: Keep the public command surface small and read-mostly

## Context

Content automation owns Menu Folders and Launch Items. The module needs public
operations for reading configuration, health, Reconciliation, Launcher use,
support evidence, and Generated State removal without becoming a content editor.

## Decision

Export exactly these version 1 commands:

- `Get-LaunchTreeConfiguration`
- `Test-LaunchTree`
- `Update-LaunchTree`
- `Show-LaunchTree`
- `Get-LaunchTreeDiagnostic`
- `Export-LaunchTreeSupportBundle`
- `Clear-LaunchTreeCache`
- `Remove-LaunchTree`

State-changing commands support `ShouldProcess`. No exported command modifies
source content.

## Amendments

- 2026-08-19: Added `Clear-LaunchTreeCache` on explicit user request. A cache
  key identifies the shortcut, not the icon it points at, so a repaired icon
  target could not invalidate its entry before `Cache.MaximumAgeDays` expired
  it and the only workaround was `Remove-LaunchTree`, which also deletes Start
  Entries and the event registration. The command is maintenance over
  module-owned disposable state, so the read-mostly, no-content-editing intent
  of this decision is unchanged. Specified by `FR-034`.

## Consequences

- The module API is explicit and testable.
- Automation has one Reconciliation operation and one removal operation.
- Future content-authoring commands require a separate accepted decision.
- Function exports must remain explicit in the module manifest.

## Requirements

- `FR-020` through `FR-029`
- `QR-011`, `QR-018` through `QR-020`

## Alternatives considered

- One multipurpose command: rejected because parameter-set complexity would
  obscure privileges and side effects.
- Export internal discovery functions: rejected because they would enlarge the
  compatibility contract without user value.
