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
  `LaunchTree Demo` Entry Root, and runs Reconciliation. It reports
  `NotElevated`/`ModuleUnavailable` instead of failing.
- 2026-07-28: Closed OI-009. `CreateProcessWithTokenW` with the UAC-linked
  token fails from an interactive elevated admin because that token is only
  `Identification`-level and raising it needs `SeTcbPrivilege`, so the
  standard-user Event Log probe cannot work there. Made it best-effort:
  `Invoke-LaunchTreeStandardUserEventProbe` returns a structured result through
  a mockable `Invoke-LaunchTreeUnelevatedProcess` seam instead of throwing,
  `Register-LaunchTreeEventLog` warns and emits event `1603` without aborting,
  and `Test-LaunchTree` raises `StandardUserEventAccessUnverified`.
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
  section to `docs/getting-started.md`, a README pointer, and a troubleshooting
  section for the script-path failure modes.
- 2026-08-17: Answered a customer complaint that `output/LaunchTree.ps1` is too
  large by adding a second generated artifact instead of shrinking the first.
  `tools/Build-LaunchTreeScript.ps1` gained `-Variant Full|Minimal`; Minimal
  embeds the AST call-graph closure of `Show-LaunchTree`, exposes only
  `-Command Show`, `-EntryName`, and `-ManagedRoot`, and strips comments and
  orphaned blank lines under a token-stream equivalence gate. On customer
  request the Event Log and every JSON reader then came out through overrides in
  `tools/MinimalVariant`, which replace same-named module functions before the
  traversal runs. Result: the full script stays at 48 functions / 5,686 lines;
  `LaunchTree.Minimal.ps1` is 24 functions / 2,695 lines / 118,750 bytes.
  Cost of the JSON removal: no machine configuration, so only defaults and
  command-line roots, and no preference file, so window geometry and sort order
  are no longer remembered.
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
  XAML `Style` that themes every state and the drop-down list.
- 2026-07-29: Added the machine-selectable Launcher Layout contract. `Grid`
  remains the default; `TabbedList` presents Menu Folders as tabs, the active
  description above them, and Launch Items as compact rows. Added tested
  projection, navigation, duplicate-search context, and icon-timer helpers;
  paired high-contrast states; hardened deterministic captures; and passed 159
  tests in both editions with an independent re-review approval.
- 2026-07-29: Made `TabbedList` the default Launcher Layout on customer
  request; `Grid` stays selectable through `LauncherLayout`. Updated the
  signed design override log, `CR-005`, `FR-011`, `FR-013`, `AS-018`, the
  example configuration, and operator docs, and renamed the Grid screenshot to
  `launcher-grid.png` so the capture tool derives each file name from its
  layout.
- 2026-07-29: Fixed the `TabbedList` tab strip rendering blank against real
  content. The strip was pinned to 44 device-independent pixels while its
  template hosted a horizontal scrollbar, so the 30 Menu Folders under
  `Programs` left about four pixels for labels. The strip now sizes to content
  and lays tabs out in one scrollable row, and the window themes its scrollbars.
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
  of falling back. `Update-LaunchTree` is excluded because an activated Start
  Entry re-resolves the root from the configuration file.
- 2026-07-29: Replaced the tall Launcher header with a single compact line
  holding Back, the title, the active description, and Close, and dropped the
  breadcrumb line in favor of a title tooltip. The header is now the drag
  handle: pressing it calls `DragMove`, and `ContentRendered` restores a
  remembered `Window.Left`/`Top` clamped to the virtual screen instead of always
  reopening near the Start button. `CR-006` already required storing those
  coordinates; the Launcher had never read them back.
- 2026-07-29: Made the `TabbedList` window width follow its tab strip and
  removed the item count from that layout. Summing `TabItem.DesiredSize` or
  reading `ScrollViewer.ExtentWidth` once both under-measure by roughly one tab,
  because the extent is exact only after the strip remeasures at the new width.
  The fit seeds from the extent and grows by the reported overflow until the
  strip stops scrolling, bounded by 80 percent of the work area and floored at
  the width the user last chose; an automatic fit is never persisted.
- 2026-07-29: Changed `TabbedList` tab selection so the tab strip survives a
  click. Selecting a tab previously navigated into it, which rebuilt the strip
  from that folder's children and hid every sibling. The Launcher now tracks a
  tab-strip owner and a selected tab separately: `SelectTab` highlights a tab
  and shows its Launch Items in place, and only a Menu Folder list row moves the
  strip one level deeper. `Back` first returns to the owning tab.
- 2026-07-29: Stopped the `TabbedList` strip from opening on an empty tab. The
  Content Snapshot already hid Menu Folders with no Launch Item beneath them,
  but the strip always rendered a tab for its own Entry Root or Menu Folder.
  `Get-LaunchTreeTabbedListContent` now reports `CurrentTabVisible` and
  redirects the selection to the first child Menu Folder when the owning folder
  holds no Launch Item of its own; the owning tab survives only when no child
  tab can replace it, so a wholly empty Entry Root still renders. Added `AS-020`
  and extended `FR-011`.
- 2026-08-06: Prepared the repository for a public release. A disclosure audit
  covering all 126 tracked files, all 34 commits on every reference, and all 13
  distinct historical screenshot blobs found no personally identifiable
  information, no secrets, and no customer or agency reference. The only
  personal data is the author identity in commit metadata, which the owner
  accepted as public. Added the MIT `LICENSE`, a `SECURITY.md`, a
  `CONTRIBUTING.md`, and a `CODEOWNERS` default owner, and replaced the
  contradictory manifest copyright with `LicenseUri` and `ProjectUri`.
- 2026-08-17: Made `.memory-bank/promptHistory.md` local-only. Rewrote all 38
  commits on `main` with `git filter-branch --index-filter` to drop it, kept the
  working copy, and ignored it. Every SHA on `main` changed; `origin/main` and
  the local `refs/original/refs/heads/main` backup still carry the old blobs
  until the owner force-pushes and drops that ref.
- 2026-08-18: Turned the Launcher's compact top line into a window title bar on
  customer request. The application icon and the Entry Root title now sit at its
  left where Back used to be, `Window.Icon` carries the same icon into the
  taskbar, and Back moved into a navigation strip at the left of the
  `TabbedList` tab strip, whose width fit accounts for it. The icon ships as
  `source/Assets/LaunchTree.ico`, embedded as base64 with a unit test comparing
  the two. A probe then measured a 10-pixel non-client inset on every side while
  the DWM visible frame started 8 pixels in at the sides and 0 at the top, so
  only the top border showed and looked five times thicker; a `WindowChrome`
  with zero caption height, glass frame, and corner radius plus a 4 DIU resize
  border makes the live window measure inset 0 on all four sides. Also fixed
  `Grid` folder activation, which assigned to a breadcrumb control removed on
  2026-07-29 and therefore threw.
- 2026-08-18: Fixed internet shortcut (`.url`) Launch Items rendering the
  generic file icon. `IShellItemImageFactory` returned the correct browser icon
  synchronously on the Launcher's STA thread but the generic document icon from
  `Task.Run`, because the internet shortcut icon handler answers only in an STA
  and the shell substitutes a fallback instead of failing. `NativeIcon.GetAsync`
  now dispatches to one background STA thread running a WPF `Dispatcher`, which
  keeps the existing `Task<BitmapSource>` contract, supplies the queue, and
  bounds thread count at the 1,000-object scale. Supplying
  `-ReferencedAssemblies` replaces the PowerShell 7 default reference set, so
  `Initialize-LaunchTreeWpf` adds `$PSHOME\ref\System.Threading.Thread.dll` and
  `System.Threading.dll` when present; Windows PowerShell needs neither. The
  icon cache key moved to `v2` because the fallback icon had already been
  persisted. Suite green: 190 passed, 0 failed, 1 intentional skip.
- 2026-08-18: Moved the selected description out of the title bar into its own
  field between the title bar and the navigation strip on customer request, who
  supplied three in-house apps as the reference pattern. `rootGrid` gained a
  sixth row for it, and the block wraps instead of ellipsising so an `Auto` row
  sizes itself to the text; a 108 DIU cap keeps a long `description.txt` from
  squeezing the item list, and the full text stays in the tooltip. Captures of
  the same fixture confirm one line for `Some more items`, three lines for a
  paragraph with the tab strip pushed down, and no gap at all when the folder
  has no `description.txt`. `FR-011` follows the field.

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
