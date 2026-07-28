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
- The design is draft and implementation is blocked pending user sign-off.

## Validation

- Design structure check: required headings ordered, draft status present, and
  no template markers.
- VS Code Markdown diagnostics: no errors.
- Planned implementation checks: focused Pester tests, PSScriptAnalyzer, full
  Sampler build, and visual comparison at 100%, 150%, and 200% scaling.
