---
id: ADR-0009
status: accepted
date: 2026-07-28
last-verified: 2026-07-28
owner: developer-and-release-owner
source: independent reader review and Microsoft Event Log contracts
---

# ADR-0009: Grant explicit standard-user access to the diagnostic event log

## Context

The standard-user Launcher must write invocation, cache, and performance
failures to a dedicated custom log. Custom logs can restrict read, write, and
clear rights through `CustomSD`, while source creation requires elevation.
Windows PowerShell event-log cmdlets are not a cross-edition runtime API.

## Decision

Elevated Reconciliation registers the source and configures a valid `CustomSD`:
Local System and built-in administrators receive `0x7`; Interactive Users
receive read and write `0x3` but not clear. Reconciliation checks global source
uniqueness and proves standard-user write/read access before committing Start
Entries.

The pre-commit check combines an access check for the Interactive Users SID
with a non-elevated probe process launched through the selected Launcher Host
using the elevated account's linked standard-user token. The probe refuses an
administrator token and writes/reads a nonce-bearing event before
Reconciliation commits Start Entries. A context without a linked token must
pre-provision and externally validate diagnostics before using the explicit
skip switch.

Use `System.Diagnostics.EventLog.WriteEntry` across supported PowerShell
editions. Read through a cross-edition .NET API or `Get-WinEvent`. Treat event
records as diagnostic input, not security-audit evidence, because log-level
write access cannot authenticate an application source.

## Consequences

- Launcher failures do not silently disappear for lack of elevation.
- Interactive users can submit records to registered sources in the log, so
  consumers must treat event text as untrusted diagnostics.
- Registration and removal require elevation; runtime use does not.
- Event access must be tested on every supported Windows family.

## Requirements

- `FR-026`, `FR-029`, `FR-031`, `FR-033`
- `CR-010`, `CR-012`
- `QR-011`, `QR-012`, `QR-021`
- `AS-013`

## References

- [Microsoft Eventlog key](https://learn.microsoft.com/en-us/windows/win32/eventlog/eventlog-key)
- [Microsoft EventLog class](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.eventlog)
