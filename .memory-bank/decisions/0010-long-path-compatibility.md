---
id: ADR-0010
status: accepted
date: 2026-07-28
last-verified: 2026-07-28
owner: developer-and-release-owner
source: independent reader review
---

# ADR-0010: Degrade explicitly for long paths on Windows PowerShell 5.1

## Context

Windows long-path policy enables long-path-aware processes. PowerShell 7 is
long-path aware, but the Windows PowerShell 5.1 .NET Framework host cannot gain
the required process manifest from an imported module.

## Decision

Support paths beyond legacy `MAX_PATH` under PowerShell 7 when Windows policy
enables them. Under Windows PowerShell 5.1, catch path-limit failures, emit an
actionable Health Finding, exclude only inaccessible content, and preserve
healthy siblings. Do not claim transparent long-path access under 5.1. The
managed `LauncherHost` setting selects PowerShell 7 when Launcher content needs
long-path access; its default remains universal inbox Windows PowerShell.

## Consequences

- The PowerShell 5.1 compatibility claim remains honest and testable.
- Long-path deployments should use PowerShell 7 for full content visibility.
- Health and support evidence distinguish invalid content from host limits.
- Operators with long-path content must install and select a supported native
  PowerShell 7 runtime before Reconciliation.

## Requirements

- `FR-005`, `FR-008`
- `QR-002`, `QR-022`
- `AS-011`

## Alternatives considered

- Modify the inbox `powershell.exe` manifest: rejected as unsafe and outside
  module ownership.
- Bundle a PowerShell 7 runtime: rejected by the small offline artifact scope.
- Silently omit over-limit content: rejected because it hides configuration
  defects.
