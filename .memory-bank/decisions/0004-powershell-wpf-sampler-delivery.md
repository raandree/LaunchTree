---
id: ADR-0004
status: accepted
date: 2026-07-28
last-verified: 2026-07-28
owner: developer-and-release-owner
source: user request and signed Design Concept
---

# ADR-0004: Deliver a Sampler PowerShell module with a WPF runtime

## Context

The requested implementation language and UI framework are PowerShell and WPF.
The module must support central deployment, PSGallery, GPO, and plain file copy.

## Decision

Use the canonical Sampler module structure with PowerShell 5.1-compatible
source, WPF for the Launcher, Pester 5 for tests, PSScriptAnalyzer for static
quality, ModuleBuilder for packaging, and GitVersion for versions. The built
module has no external runtime module dependency.

The Launcher requires FullLanguage and is started with the required
`-ExecutionPolicy Bypass`. Documentation must state that this flag does not
bypass Constrained Language Mode, AppLocker, or WDAC.

PowerShell 7 supports long paths when the Windows long-path policy is enabled.
Windows PowerShell 5.1 cannot acquire that process-level capability from a
module, so it reports and excludes over-limit content without hiding healthy
siblings, as recorded in `ADR-0010`.

## Amendments

- 2026-08-19: The build tracks the latest Pester release instead of a pinned
  version, and now resolves Pester 6. Pester 6 keeps the classic `Should`
  assertions the suite uses and still supports Windows PowerShell 5.1 and
  PowerShell 7, so no test needed converting. The tooling intent of this
  decision is unchanged. Recorded in `QR-018`.

## Consequences

- One source supports Windows PowerShell 5.1 and PowerShell 7.
- Build dependencies remain separate from the offline runtime artifact.
- WPF and Windows Shell APIs make runtime Windows-only.
- Application-control deployments must allow the Launcher to run in
  FullLanguage.

## Requirements

- `QR-001` through `QR-003`
- `QR-018` through `QR-020`

## Alternatives considered

- Compiled desktop executable: rejected by the requested implementation
  boundary.
- PowerShell 7 only: rejected because inbox Windows PowerShell 5.1 is required.
- Runtime PSGallery dependencies: rejected because offline file-copy deployment
  is required.
