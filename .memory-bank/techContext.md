---
status: current
last-verified: 2026-07-28
owner: active-agent
source: repository evidence
---

# Tech context

## Stack

- PowerShell module with WPF and Windows Shell integration.
- Sampler, ModuleBuilder, Pester 5, PSScriptAnalyzer, and GitVersion.

## Environment

- Windows 10 x64, Windows 11 x64/ARM64, and Windows Server desktop environments.
- Windows PowerShell 5.1 and PowerShell 7 x64/ARM64.

## Constraints

- Runtime is Windows-only, standard-user, FullLanguage, and offline.
- Deployment supports PSGallery, GPO, and self-contained file copy.
- Generated launcher commands require `-ExecutionPolicy Bypass`; application
  control policy still governs FullLanguage access.
- Managed source content and administrator JSON remain read-only to the module.
- The Design Concept is signed off and the specification package is accepted.
- Start Entries activate opaque Entry IDs through a validated Launcher Host.
- The dedicated event log grants Interactive Users read/write, not clear, and
  requires a non-elevated read/write probe before Start Entry commit.
- PowerShell 7 supports policy-enabled long paths; Windows PowerShell 5.1
  reports and excludes only content beyond its effective host limit.

## Validation

- Design structure check: signed-off status and required headings present.
- Specification checks: contiguous `FR`, `QR`, `CR`, `AS`, `ADR`, and `OI`
  namespaces; local links and issue records validated.
- VS Code Markdown diagnostics: no errors.
- Planned implementation checks: focused Pester tests, PSScriptAnalyzer, full
  Sampler build, and visual comparison at 100%, 150%, and 200% scaling.
