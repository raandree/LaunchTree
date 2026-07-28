---
id: ADR-0007
status: accepted
date: 2026-07-28
last-verified: 2026-07-28
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
- `Remove-LaunchTree`

State-changing commands support `ShouldProcess`. No exported command modifies
source content.

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
