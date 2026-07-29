---
status: current
last-verified: 2026-07-29
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
- `tools/Test-Documentation.ps1`: Memory Bank, specifications, links, issue
  records, and signed design pass.
- Single-file script: generated during `build`, parse-checked by the generator,
  and verified with no reachable module (45 commands, Reconciliation, health).
- Full detached Sampler workflow: 159 tests pass under PowerShell 7.
- Full detached Sampler workflow: 159 tests pass under Windows PowerShell 5.1
  with one intentional host-dependent skip.
- Recursive PSScriptAnalyzer: zero production-source findings.
- `tools/New-LauncherScreenshot.ps1`: nonblank default `TabbedList` frame at
  `1204x1060` with 33 sampled colors and `Grid` frame at `1120x866` with 120
  sampled colors; the tool rejects stale builds, a short `TabbedList` frame, and
  a tall `Grid` frame.
- `tools/Test-OfflineLifecycle.ps1`: copied module version `0.2.0`, health
  `Healthy`, WPF capture, successful removal, and zero runtime dependencies.
- External visual-scale/theme, Windows Server, ARM64, AppLocker/WDAC, and live
  elevated Event Log matrix evidence remains tracked in `docs/open-issues.md`.
