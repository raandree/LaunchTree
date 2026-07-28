---
id: ADR-0008
status: accepted
date: 2026-07-28
last-verified: 2026-07-28
owner: developer-and-release-owner
source: independent reader review
---

# ADR-0008: Activate Start Entries through opaque Entry IDs

## Context

Entry Root names are arbitrary Unicode and may contain shell or PowerShell
metacharacters. Embedding a name or source path in `-Command` would create an
injection and quoting boundary. GPO and file-copy targets always provide inbox
Windows PowerShell, but may not provide PowerShell 7.

## Decision

Store a GUID Entry ID in the ownership record and pass only that identifier to
a fixed `-File` bootstrap. By default a Start Entry targets the fully qualified
inbox `powershell.exe`. Administrators may select a registered, architecture-
matched PowerShell 7 host for long-path support. The host uses `-STA`,
`-NoProfile`, `-NonInteractive`, the required `-ExecutionPolicy Bypass`, and
hidden window style. Paths are separate quoted arguments and are rejected if
they cannot be represented safely.

The bootstrap verifies the Entry ID and Managed Root against the ownership
record. A `Local\` mutex and current-user-only named pipe scope the single
Launcher to one interactive logon session.

## Consequences

- Entry Root names never become executable PowerShell text.
- The default Start Entry works after offline file copy without PowerShell 7.
- Long-path deployments can select a validated PowerShell 7 host.
- Reconciliation must update module paths after version or location changes.
- Separate sessions have independent Launcher processes.
- The bootstrap becomes part of the packaged runtime and compatibility tests.

## Requirements

- `FR-003`, `FR-010`, `FR-032`
- `CR-007`, `CR-011`
- `AS-010`, `AS-014`

## Alternatives considered

- `-Command` with an interpolated Entry Root name: rejected as unsafe.
- Require `pwsh`: rejected because clean Windows and GPO targets may not have it.
- One global process across sessions: rejected because it crosses desktop and
  user boundaries.
