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

- 2026-07-28: Baselined the project in git history: canonical Memory Bank,
  requirements interview, signed Design Concept with 33 functional, 22 quality,
  and 12 configuration requirements, 17 acceptance scenarios, ten ADRs, a
  glossary, and nine issues; implemented all seven public commands; passed both
  editions with 131 tests and an independent `APPROVE`.
- 2026-07-28: Added and validated the canonical operator getting-started path
  from module installation through first Launcher use and cleanup, including
  `Show-LaunchTree` console use, direct import of the built module, and the
  recognized/EntryId/STA failures no operator document had covered.
- 2026-07-28: Renamed the product from `StartMenuFolders` to `LaunchTree`
  across the module, commands, paths, Event Log identity, type names, tests,
  specifications, and Memory Bank while the module is still unreleased.
- 2026-07-28: Added `tools/Initialize-QuickStart.ps1`, a `ShouldProcess`-aware
  setup script that writes a default machine configuration, creates the sample
  `LaunchTree Demo` Entry Root of always-present Windows Launch Items, and runs
  Reconciliation. It imports an installed or built module, reports
  `NotElevated`/`ModuleUnavailable` instead of failing, and accepts
  `-SkipReconciliation`.
- 2026-07-28: Closed OI-009. `[LaunchTree.UnelevatedProcess]::Run` calls
  `CreateProcessWithTokenW` with the UAC-linked token, which returns as an
  `Identification`-level impersonation token and is rejected with
  `ERROR_ACCESS_DENIED` (5); raising it needs `SeTcbPrivilege` (SYSTEM only), so
  the standard-user Event Log probe cannot work from an interactive elevated
  admin. Fixed as a best-effort probe:
  `Invoke-LaunchTreeStandardUserEventProbe` returns a structured
  `LaunchTree.EventProbeResult` through a mockable
  `Invoke-LaunchTreeUnelevatedProcess` seam instead of throwing,
  `Register-LaunchTreeEventLog` warns and emits event `1603` without aborting,
  `Update-LaunchTree` persists `StandardUserEventProbeVerified`, and
  `Test-LaunchTree` raises the `StandardUserEventAccessUnverified` Warning
  finding. Full suite green: 136 passed, 0 failed, 1 intentional skip.
- 2026-07-28: Added a second delivery form: `output/LaunchTree.ps1`, a generated
  self-contained script holding all 45 functions. New private
  `Get-LaunchTreeRuntimeContext` abstracts ModuleBase/version/launcher/probe
  paths so one source serves both hosts, and `tools/Build-LaunchTreeScript.ps1`
  plus the `Build_Single_File_Script` task generate it during `build`. Verified
  with no module reachable: 45 commands loaded, Reconciliation added 1 Start
  Entry, health `Healthy`; suite 143 passed, 0 failed, 1 intentional skip.
- 2026-07-29: Closed the operator-documentation gap for the single-file
  delivery. `docs/deployment.md` already covered it; the quick start, README,
  and troubleshooting guide did not. Added a `Use the single-file script`
  section to `docs/getting-started.md` (stable path copy, dot-sourcing,
  `-Command` dispatch, and `Initialize-QuickStart.ps1 -SkipReconciliation`
  because that script reconciles only through an installed or built module),
  a README pointer, and a troubleshooting section for the script-path failure
  modes. `tools/Test-Documentation.ps1` passed.
- 2026-08-17: Answered a customer complaint that `output/LaunchTree.ps1` is too
  large by adding a second generated artifact instead of shrinking the first.
  `tools/Build-LaunchTreeScript.ps1` gained `-Variant Full|Minimal`; Minimal
  embeds the AST call-graph closure of `Show-LaunchTree`, exposes only
  `-Command Show`, `-EntryName`, and `-ManagedRoot`, and strips comments and
  orphaned blank lines under a token-stream equivalence gate. On customer
  request the Event Log and every JSON reader then came out through overrides in
  `tools/MinimalVariant`, which replace same-named module functions before the
  traversal runs so whatever only the replaced bodies reached drops out by
  itself. Result: the full script stays at 48 functions / 5,686 lines;
  `LaunchTree.Minimal.ps1` is 24 functions / 2,695 lines / 118,750 bytes, down
  from 5,686 / 223,197. Every headless STA capture of
  `-EntryName Programs -ManagedRoot D:\temp\` across all three reductions
  produced a byte-identical 86,994-byte frame. Cost of the JSON removal: no
  machine configuration, so only defaults and command-line roots, and no
  preference file, so window geometry and sort order are no longer remembered.
- 2026-07-29: Fixed the `Event source 'LaunchTree' is owned by log
  'Application'` Reconciliation failure. `[Diagnostics.EventLog]::WriteEntry`
  auto-registers an unknown source in the `Application` log when the caller is
  elevated, so an elevated run that emitted a diagnostic event before the
  dedicated log existed bound the source to `Application` and blocked
  registration forever. `Invoke-LaunchTreeEventLogWrite` now takes `LogName` and
  verifies the registration through `LogNameFromSourceName` before writing, and
  `Register-LaunchTreeEventLog` reports the `DeleteEventSource` remediation.
- 2026-07-29: Restyled the Launcher sort selector. The `ComboBox` still used the
  Windows system theme template, so it rendered as a light-gray classic control
  inside the dark Fluent window. `Show-LaunchTreeWindow` now applies a parsed
  XAML `Style` that themes the closed control, chevron, hover, open, and
  keyboard focus states, and the drop-down list.
- 2026-07-29: Added the machine-selectable Launcher Layout contract. `Grid`
  remains the default; `TabbedList` presents Menu Folders as tabs, the active
  description above them, and Launch Items as compact rows. Added tested
  projection, navigation, duplicate-search context, and icon-timer helpers;
  paired high-contrast states; hardened deterministic captures; rendered both
  layouts; and passed 159 tests in PowerShell 7 plus 159 tests with one
  intentional skip in Windows PowerShell 5.1, with an independent re-review
  approval and no Blocker or Major findings.
- 2026-07-29: Made `TabbedList` the default Launcher Layout on customer
  request; `Grid` stays selectable through `LauncherLayout`. Updated the
  signed design override log, `CR-005`, `FR-011`, `FR-013`, `AS-018`, the
  example configuration, and operator docs, and renamed the Grid screenshot to
  `launcher-grid.png` so the capture tool derives each file name from its
  layout.
- 2026-07-29: Fixed the `TabbedList` tab strip rendering blank against real
  content. The strip was pinned to 44 device-independent pixels while its
  template hosted a horizontal scrollbar, so the 30 Menu Folders under
  `Programs` left about four pixels for labels. The strip now sizes to
  content and lays tabs out in one scrollable row, the window themes its
  scrollbars, and the capture fixture gained Menu Folders so the checked-in
  screenshot exercises tab overflow.
- 2026-07-29: Hid Menu Folders whose subtree holds no Launch Item, removed the
  sort selector and search box from the tabbed layout, and fixed tab
  navigation. A live UI Automation click proved the old handler entered the
  wrong folder because it rebuilt the tab collection from shared selection
  state; each tab now carries its own folder and navigates from its own click,
  verified by clicking `Canon Utilities` and reading back its four subfolders.
- 2026-07-29: Added `CR-013` root override parameters on customer request.
  `ManagedRoot` and `PersonalRoot` now override the machine configuration for a
  single call to `Get-LaunchTreeConfiguration`, `Show-LaunchTree`,
  `Test-LaunchTree`, and `Export-LaunchTreeSupportBundle`; an override is
  environment-expanded and must be absolute, and a relative value throws instead
  of falling back to an unintended root. `Update-LaunchTree` is deliberately
  excluded because an activated Start Entry re-resolves the root from the
  configuration file. The single-file script now also rejects a parameter the
  selected `-Command` cannot use instead of discarding it silently.
- 2026-07-29: Replaced the tall Launcher header with a single compact line
  holding Back, the title, the active description, and Close, and dropped the
  breadcrumb line in favor of a title tooltip. The header is now the drag
  handle: pressing it calls `DragMove`, and `ContentRendered` restores a
  remembered `Window.Left`/`Top` clamped to the virtual screen instead of always
  reopening near the Start button. `CR-006` already required storing those
  coordinates; the Launcher had never read them back. Verified by seeding a
  preference at 200,150 and reading it back on close. The capture tool's
  pixel-diversity guard now samples 60x48 and requires 20 (`TabbedList`) and 30
  (`Grid`) colors. A follow-up pass measured a 32 DIU header over a 34 DIU tab
  strip, down from about 116 DIU of stacked chrome.
- 2026-07-29: Made the `TabbedList` window width follow its tab strip and
  removed the item count from that layout. Summing `TabItem.DesiredSize` or
  reading `ScrollViewer.ExtentWidth` once both under-measure by roughly one tab,
  because the extent is exact only after the strip remeasures at the new width.
  The fit seeds from the extent and grows by the reported
  `ExtentWidth - ViewportWidth` overflow until the strip stops scrolling,
  bounded by 80 percent of the work area and floored at the width the user last
  chose; an automatic fit is tracked separately so it is never persisted as a
  user dimension.
- 2026-07-29: Changed `TabbedList` tab selection so the tab strip survives a
  click. Selecting a tab previously navigated into it, which rebuilt the strip
  from that folder's children and hid every sibling. The Launcher now tracks a
  tab-strip owner and a selected tab separately: `SelectTab` highlights a tab
  and shows its Launch Items in place, a Menu Folder below the selected tab
  appears as a list row, and only that row moves the strip one level deeper.
  `Back` first returns to the owning tab, then leaves the level.
- 2026-07-29: Stopped the `TabbedList` strip from opening on an empty tab. The
  Content Snapshot already hid Menu Folders with no Launch Item beneath them,
  but the strip always rendered a tab for its own Entry Root or Menu Folder, so
  `Show -EntryName x1 -ManagedRoot C:\temp` opened on an `x1` tab with nothing
  in it. `Get-LaunchTreeTabbedListContent` now reports `CurrentTabVisible` and
  redirects the selection to the first child Menu Folder when the owning folder
  holds no Launch Item of its own; the owning tab survives only when no child
  tab can replace it, so a wholly empty Entry Root still renders. Added `AS-020`
  and extended `FR-011`. Full workflows under PowerShell 7 and Windows
  PowerShell 5.1 are green: 173 passed, 1 intentional skip, 0 failed in each.
- 2026-08-06: Prepared the repository for a public release. A disclosure audit
  covering all 126 tracked files, all 34 commits on every reference, and all 13
  distinct historical screenshot blobs found no personally identifiable
  information in file content, no secrets, and no customer or agency reference;
  placeholders are `Contoso`, `example.test`, and `company.local`, and every
  screenshot is generated from a temporary fixture. The only personal data is
  the author identity in commit metadata, which the owner accepted as public.
  Added the MIT `LICENSE`, a `SECURITY.md` derived from the signed Design
  Concept, a `CONTRIBUTING.md`, and a `CODEOWNERS` default owner, and replaced
  the contradictory manifest copyright with `LicenseUri` and `ProjectUri`.
- 2026-08-17: Made `.memory-bank/promptHistory.md` local-only. Rewrote all 38
  commits on `main` with `git filter-branch --index-filter` to drop it, kept the
  working copy, and ignored it. Every SHA on `main` changed; `origin/main` and
  the local `refs/original/refs/heads/main` backup still carry the old blobs
  until the owner force-pushes and drops that ref.

- 2026-08-18: Turned the Launcher's compact top line into a window title bar on
  customer request. The application icon and the Entry Root title now sit at its
  left where Back used to be, `Window.Icon` carries the same icon into the
  taskbar, and Back moved into a new navigation strip at the left of the
  `TabbedList` tab strip, whose width fit now accounts for it. The icon ships as
  `source/Assets/LaunchTree.ico` and is embedded as base64 in
  `Get-LaunchTreeApplicationIcon`, so both single-file deliveries stay
  self-contained; a unit test compares the embedded bytes against the asset.
  Also fixed `Grid` folder activation, which assigned to a breadcrumb control
  removed on 2026-07-29 and therefore threw; both layouts now expose the current
  path through the title tooltip. Suite green: 189 passed, 0 failed, 1
  intentional skip, with both layout captures re-rendered.

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
