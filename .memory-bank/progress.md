---
status: current
last-verified: 2026-07-29
owner: active-agent
source: repository evidence
---

# Progress

## Current status

The Windows-only Sampler PowerShell module is implemented, independently
reviewed, and green under PowerShell 7 and Windows PowerShell 5.1. Production
release remains gated by external environment evidence.

## Recent milestones

- Canonical Memory Bank base initialized.
- 2026-07-28: Completed the adversarial requirements interview and created the
  draft Design Concept.
- 2026-07-28: Signed off the Design Concept; documented 33 functional, 22
  quality, and 12 configuration requirements, 17 acceptance scenarios, ten
  ADRs, a canonical glossary, and nine managed issues.
- 2026-07-28: Independent security re-review closed every Blocker and Major and
  returned `READY FOR IMPLEMENTATION`.
- 2026-07-28: Implemented all seven public commands, recursive Content Snapshot
  discovery, transactional Reconciliation, the session-local WPF Launcher,
  Shell-native invocation, operational diagnostics, cache/preferences, health,
  Support Bundle export, and ownership-only removal.
- 2026-07-28: Full Sampler workflows passed in both supported PowerShell
  editions with 131 tests; isolated file-copy deployment passed with zero
  runtime dependencies; independent final re-review returned `APPROVE`.
- 2026-07-28: Added and validated the canonical operator getting-started path
  from module installation through first Launcher use and cleanup.
- 2026-07-28: Renamed the product from `StartMenuFolders` to `LaunchTree`
  across the module, commands, paths, Event Log identity, type names, tests,
  specifications, and Memory Bank while the module is still unreleased.
- 2026-07-28: Added `tools/Initialize-QuickStart.ps1`, a `ShouldProcess`-aware
  setup script that writes a default machine configuration and a sample Entry
  Root of always-present Windows Launch Items; the generated configuration is
  valid with zero Health Findings.
- 2026-07-28: Made the getting-started Entry Root sample self-contained and
  fail-fast after it failed with a cascading null-variable error; the extracted
  block was executed against a redirected `ProgramData` fixture.
- 2026-07-28: Documented `Show-LaunchTree` console use, direct import of the
  built module, and the recognized/EntryId/STA failures that were previously
  absent from every operator document.
- 2026-07-28: Extended the setup script to run Reconciliation so the sample
  Entry Root reaches the Windows Start menu; it imports an installed or built
  module, reports `NotElevated`/`ModuleUnavailable` instead of failing, and
  accepts `-SkipReconciliation`. The elevated success path is unverified
  locally because the agent session is not elevated.
- 2026-07-28: Renamed the sample Entry Root to `LaunchTree Demo` because
  `Windows tools` collides with the built-in Windows Tools Start menu entry.
- 2026-07-28: Reproduced the OI-009 elevated standard-user Event Log probe on a
  UAC-split interactive admin session; it fails. `Initialize-QuickStart.ps1`
  reports `StartEntryAction=Failed` because `[LaunchTree.UnelevatedProcess]::Run`
  calls `CreateProcessWithTokenW` with the UAC-linked token, which returns as an
  `Identification`-level impersonation token and is rejected with
  `ERROR_ACCESS_DENIED` (5). Raising it needs `SeTcbPrivilege` (SYSTEM only), so
  the technique cannot work from an interactive elevated admin. Defect, not
  environment.
- 2026-07-28: Fixed the defect (option 1, best-effort probe).
  `Invoke-LaunchTreeStandardUserEventProbe` now returns a structured
  `LaunchTree.EventProbeResult` through a mockable
  `Invoke-LaunchTreeUnelevatedProcess` seam instead of throwing;
  `Register-LaunchTreeEventLog` warns and emits event `1603` without aborting;
  `Update-LaunchTree` persists `StandardUserEventProbeVerified` and surfaces the
  probe on its result; `Test-LaunchTree` raises the
  `StandardUserEventAccessUnverified` Warning finding. QuickStart now returns
  `StartEntryAction=Reconciled`, `StartEntryCount=1`, and `Degraded` health.
  Full suite green: 136 passed, 0 failed, 1 intentional skip.
- 2026-07-28: Added a second delivery form: `output/LaunchTree.ps1`, a generated
  self-contained script holding all 45 functions. New private
  `Get-LaunchTreeRuntimeContext` abstracts ModuleBase/version/launcher/probe
  paths so one source serves both hosts; the probe body moved to
  `Invoke-LaunchTreeEventLogAccessProbe` and the packaged probe script is now a
  thin wrapper. `tools/Build-LaunchTreeScript.ps1` plus the
  `Build_Single_File_Script` task generate it during `build`. Verified with no
  module reachable: 45 commands loaded, Reconciliation added 1 Start Entry
  targeting the script with `-Command "Show"`, health `Healthy`. Module delivery
  and behavior unchanged; full suite 143 passed, 0 failed, 1 intentional skip.
- 2026-07-29: Closed the operator-documentation gap for the single-file
  delivery. `docs/deployment.md` already covered it; the quick start, README,
  and troubleshooting guide did not. Added a `Use the single-file script`
  section to `docs/getting-started.md` (stable path copy, dot-sourcing,
  `-Command` dispatch, and `Initialize-QuickStart.ps1 -SkipReconciliation`
  because that script reconciles only through an installed or built module),
  a README pointer, and a troubleshooting section for the script-path failure
  modes. `tools/Test-Documentation.ps1` passed.
- 2026-07-29: Fixed the `Event source 'LaunchTree' is owned by log
  'Application'` Reconciliation failure. `[Diagnostics.EventLog]::WriteEntry`
  auto-registers an unknown source in the `Application` log when the caller is
  elevated, so an elevated run that emitted a diagnostic event before the
  dedicated log existed (an elevated test run writing configuration finding
  `1001`) bound the source to `Application` and blocked registration forever.
  `Invoke-LaunchTreeEventLogWrite` now takes `LogName` and verifies the
  registration through `LogNameFromSourceName` before writing;
  `Write-LaunchTreeEvent` still swallows the failure as a non-fatal diagnostic
  loss, and `Register-LaunchTreeEventLog` reports the `DeleteEventSource`
  remediation. Full suite green: 145 passed, 0 failed.
- 2026-07-29: Restyled the Launcher sort selector. The `ComboBox` still used the
  Windows system theme template, so it rendered as a light-gray classic control
  inside the dark Fluent window. `Show-LaunchTreeWindow` now applies a parsed
  XAML `Style` that themes the closed control, chevron, hover, open, and
  keyboard focus states, and the drop-down list. Verified by rendering the
  Launcher and the open popup; full suite green: 145 passed, 0 failed.
- 2026-07-29: Added the machine-selectable Launcher Layout contract. `Grid`
  remains the default; `TabbedList` presents Menu Folders as tabs, the active
  description above them, and Launch Items as compact rows. Added tested
  projection, navigation, duplicate-search context, and icon-timer helpers;
  paired high-contrast states; hardened deterministic captures; rendered both
  layouts; and passed 159 tests in PowerShell 7 plus 159 tests with one
  intentional skip in Windows PowerShell 5.1. Independent re-review approved
  with no Blocker or Major findings.
- 2026-07-29: Made `TabbedList` the default Launcher Layout on customer
  request; `Grid` stays selectable through `LauncherLayout`. Updated the
  signed design override log, `CR-005`, `FR-011`, `FR-013`, `AS-018`, the
  example configuration, and operator docs, and renamed the Grid screenshot to
  `launcher-grid.png` so the capture tool derives each file name from its
  layout.

## Stable capabilities

- Managed and Personal Content Sources merge into immutable Content Snapshots.
- Native Start Entries carry opaque Entry IDs into a session-local Launcher.
- Reconciliation is ownership-aware, idempotent, and rollback-protected.
- WPF rendering, high-resolution Shell icons, cache, preferences, search,
  navigation, input suppression, and capture validation are implemented.
- Event Log ACL validation, linked standard-user probing, structured event
  emission, health, and redacted Support Bundles are implemented.

## Open work

- Close High-priority compatibility and validation issues before production
  release.
- Implement Generated State schema migration before introducing schema 2.
