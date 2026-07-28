---
id: ADR-0003
status: accepted
date: 2026-07-28
last-verified: 2026-07-28
owner: developer-and-release-owner
source: signed Design Concept
---

# ADR-0003: Delegate Launch Item invocation to Windows Shell

## Context

`.lnk` files may contain arguments, working directories, show states,
environment variables, indirect targets, and elevation behavior. Reconstructing
those semantics in PowerShell is incomplete and error-prone.

## Decision

Ask Windows Shell to open each selected Launch Item file itself. Accept `.lnk`
and `.url` in version 1, but expose `.url` only for `http` and `https` schemes.
Do not log successful use, arguments, or URL query strings.

## Consequences

- Native shortcut semantics are preserved.
- Windows remains responsible for target security and elevation prompts.
- UNC paths, mapped drives, and remote targets behave like ordinary shortcuts.
- Launch failures are reported without attempting an alternate invocation.

## Requirements

- `FR-007`, `FR-008`, `FR-018`, `FR-019`, `FR-026`
- `QR-012` through `QR-014`

## Alternatives considered

- Resolve and invoke target fields directly: rejected because it loses Shell
  behavior.
- Permit every registered `.url` scheme: rejected because version 1 requires a
  narrow protocol boundary.
