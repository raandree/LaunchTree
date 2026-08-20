---
status: current
last-verified: 2026-08-19
owner: active-agent
source: repository evidence
---

# Progress

## Current status

The Windows-only Sampler PowerShell module is implemented, independently
reviewed, and green under PowerShell 7 and Windows PowerShell 5.1. Production
release remains gated by external environment evidence.

## Recent milestones

- 2026-08-20: Turned the continuous integration test legs green. Both legs
  failed on the same single test, the deny-ACL Health Finding regression test,
  which expected `DescriptionUnavailable` beside `ContentPathInaccessible` and
  saw only the latter. The module was right and the fixture was wrong: it denied
  the Menu Folder with an inheritable ACE, but `description.txt` already existed
  and carried explicit `Allow` entries copied from the parent, which an access
  check grants before it ever reaches the inherited `Deny`. Measured the ordered
  DACL on both objects to prove it, then denied the description file explicitly
  and confirmed the probe now throws on both editions. `CHANGELOG.md` carries
  the entry the Sampler changelog gate requires. Verified with the CI sequence
  locally: one build, then the test workflow under PowerShell 7 and Windows
  PowerShell 5.1, 261 passed, 0 failed, 2 intentional non-STA skips each.

- 2026-08-20: Added GitHub Actions continuous integration in
  `.github/workflows/ci.yml`, modelled on the ShellPilot pipeline but Windows
  only: a build job packs on `windows-latest`, two test legs replay the Sampler
  test workflow from that artifact under PowerShell 7 and Windows PowerShell
  5.1, and a deploy job publishes from the upstream repository on `main` or a
  `v*` tag. `build.yaml` gained `Publish_Release_To_GitHub` and the
  `GitHubConfig` identity `Create_ChangeLog_GitHub_PR` commits with. Verified by
  parsing both YAML files and running `build.ps1 -Tasks publish` with no tokens,
  which skipped both publish tasks and proved the task references resolve.
  GitHub rejected the first push: a step-level `shell` key cannot read the
  `matrix` context, so the host selection moved to the job's `defaults.run`,
  which the context-availability table does allow. The test legs stay red until
  the known deny-ACL failure is fixed.
- 2026-08-19: Added a compiled executable delivery for both single-file scripts.
  `tools/Build-LaunchTreeExecutable.ps1` embeds script and bootstrap as managed
  resources in the C# host under `tools/StandaloneHost`, compiles it with the
  in-box `csc.exe`, and smoke-runs the result; two Sampler tasks emit
  `LaunchTree.exe` (console, hides a console it owns) and
  `LaunchTree.Minimal.exe` (windows subsystem). Two findings shaped it:
  splatting binds by position only, so the bootstrap resolves parameter names
  against the embedded script's own `ParamBlock`; and a custom `PSHost` is what
  makes `exit` observable. A compiled delivery is its own Launcher Host, so
  `Get-LaunchTreeRuntimeContext` gained `LauncherIsExecutable` and the Start
  Entry, wizard, and probe drop the PowerShell prefix.
- 2026-08-19: Moved the Pester build dependency from the pinned `5.7.1` to
  `latest`, which resolves Pester 6.1.0. No test needed converting: the suite
  uses only the classic `Should` assertions and `Should -Invoke`, which Pester 6
  keeps, and it contains none of the removed constructs (`Assert-MockCalled`,
  `Assert-VerifiableMock`, `-Focus`, `Set-ItResult -Pending`, mock fall-through,
  duplicate setup blocks, empty `-ForEach`). PowerShell 7 and Windows
  PowerShell 5.1 both report 243 passed, 2 intentional non-STA skips. One
  failure remains and is pre-existing rather than version-related: the
  `Get-LaunchTreeContentSnapshot` deny-ACL test expects both
  `DescriptionUnavailable` and `ContentPathInaccessible` but sees only
  `ContentPathInaccessible`, and it fails identically when Pester 5.7.1 is
  imported explicitly.
- 2026-08-19: Fixed a customer report that the Launcher showed a red error after
  an item had started fine. `Invoke-LaunchTreeLaunchItem` asked `Start-Process`
  for a process object it discarded, and Windows Shell returns none when it hands
  the request to a running instance, an elevated process, or a protocol handler,
  so every `.url` link and every shortcut opening a folder or a running
  application was reported as failed. Reproduced all three, removed `-PassThru`,
  and confirmed a broken shortcut target still reports failure. The status line
  now wraps so the Windows reason stays readable. 232 tests pass.
- 2026-08-19: Added a customer-requested shortcut wizard and flipped the
  close-after-launch default. The three-step dialog takes one Entry Root folder
  such as `\\contoso.com\Data\Files\programs`, derives the Managed Root from its
  parent and the Entry Root name from its last segment, asks whether the
  Launcher should close after a launch, and writes the `CR-015` shortcut to a
  location chosen in a save dialog. `CloseAfterLaunch` now defaults to `false`
  and gained a call-scoped `CR-014` switch on `Get-LaunchTreeConfiguration` and
  `Show-LaunchTree`; the module launcher bootstrap gained an
  `EntryName`/`ManagedRoot` parameter set so a wizard shortcut works from every
  delivery. Fixed a pre-existing blocker found while validating it: the native
  window helper failed to compile under Windows PowerShell 5.1, the default
  `LauncherHost`, because `Window` implements `IQueryAmbient` and the reference
  to `System.Xaml` was implicit. Both editions pass 231 tests with one skip.
- 2026-08-19: Fixed the access-denied error a customer saw before the Launcher
  opened on a DFS Managed Root. `Test-Path` writes a non-terminating
  `UnauthorizedAccessException` when the containing directory denies list or
  traverse access, so probing a Menu Folder's `description.txt` leaked
  `ItemExistsUnauthorizedAccessError` to the console instead of degrading. The
  description probe now uses `-ErrorAction Stop` and degrades to a
  `DescriptionUnavailable` finding; the root probes use `-ErrorAction Ignore`
  beside their existing findings. A Deny-ACE regression test asserts an empty
  error stream and both findings, and fails without the fix. Both editions pass
  212 tests with one skip.
- 2026-08-17: Answered a customer complaint that `output/LaunchTree.ps1` is too
  large by adding a second generated artifact instead of shrinking the first.
  `tools/Build-LaunchTreeScript.ps1` gained `-Variant Full|Minimal`; Minimal
  embeds the AST call-graph closure of `Show-LaunchTree`, exposes only
  `-Command Show`, `-EntryName`, and `-ManagedRoot`, and strips comments and
  orphaned blank lines under a token-stream equivalence gate. On customer
  request the Event Log and every JSON reader then came out through overrides in
  `tools/MinimalVariant`. Cost of the JSON removal: no machine configuration, so
  only defaults and command-line roots, and no preference file, so window
  geometry and sort order are no longer remembered.
- 2026-07-29: Built the `TabbedList` Launcher Layout and made it the default on
  customer request; `Grid` stays selectable through `LauncherLayout`. Added
  `CR-013` root overrides on the read commands, rejecting a relative value
  instead of falling back, and replaced the tall header with one compact line
  that doubles as the drag handle and restores a remembered position clamped to
  the virtual screen. Durable live-UI lessons: a themed `ComboBox` needs a full
  XAML `Style`; a fixed-height tab strip starves its labels once a scrollbar
  appears; tab-strip owner and selected tab must be tracked separately so only a
  list row descends; and `TabItem.DesiredSize` under-measures the strip. Menu
  Folders with no Launch Item beneath them are hidden. Added `AS-018`, `AS-020`.
- 2026-08-06: Prepared the repository for a public release. A disclosure audit
  of every tracked file, commit, and historical screenshot blob found nothing
  sensitive. Added the MIT `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, and
  `CODEOWNERS`, and replaced the contradictory manifest copyright.
- 2026-08-17: Made `.memory-bank/promptHistory.md` local-only by rewriting all
  38 commits on `main` with `git filter-branch --index-filter`. Every SHA
  changed; `origin/main` and `refs/original/refs/heads/main` still carry the old
  blobs until the owner force-pushes and drops that ref.
- 2026-08-18: Turned the Launcher's compact top line into a window title bar on
  customer request. The application icon and the Entry Root title sit at its
  left, `Window.Icon` carries the same icon into the taskbar, and Back moved
  into a navigation strip at the left of the `TabbedList` tab strip. The icon
  ships as `source/Assets/LaunchTree.ico`, embedded as base64 with a unit test
  comparing the two. A probe then measured a 10-pixel non-client inset on every
  side while the DWM visible frame started 8 pixels in at the sides and 0 at the
  top, so only the top border showed; a `WindowChrome` with zero caption height,
  glass frame, and corner radius plus a 4 DIU resize border makes the live window
  measure inset 0 on all four sides.
- 2026-08-18: Fixed internet shortcut (`.url`) Launch Items rendering the
  generic file icon. `IShellItemImageFactory` returned the correct browser icon
  synchronously on the Launcher's STA thread but the generic document icon from
  `Task.Run`, because the internet shortcut icon handler answers only in an STA
  and the shell substitutes a fallback instead of failing. `NativeIcon.GetAsync`
  now dispatches to one background STA thread running a WPF `Dispatcher`, which
  keeps the existing `Task<BitmapSource>` contract and bounds thread count at
  the 1,000-object scale. Supplying `-ReferencedAssemblies` replaces the
  PowerShell 7 default reference set, so `Initialize-LaunchTreeWpf` adds the
  threading reference assemblies when present. The icon cache key moved to `v2`
  because the fallback icon had already been persisted. Suite: 190 passed.
- 2026-08-18: Moved the selected description out of the title bar into its own
  field on customer request. Sizing it to its content moved the tab strip, so it
  reserves exactly two lines at a 16 DIU line height, truncates with an ellipsis
  into the tooltip, and collapses in `Grid`. Four captures place the tab strip
  at the same position.
- 2026-08-18: Fixed a customer report that a Managed Root on a DFS namespace
  found no Entry Roots. A DFS link is a directory reparse point, and traversal
  skipped every reparse point. Traversal now reads the reparse tag through
  `FindFirstFileW` and admits only `IO_REPARSE_TAG_DFS` and `IO_REPARSE_TAG_DFSR`;
  junctions, symbolic links, and mount points stay excluded with a
  `ReparsePointIgnored` finding. Verified on the lab namespace
  `\\contoso.com\Data`, whose `Files` link targets hidden shares: 201 objects
  read through the referral, DFSR mount point still ignored. Suite: 197 passed.
- 2026-08-19: Fixed a customer report that a folder holding three `.url` files
  showed only two. `Get-LaunchTreeLaunchItemDetail` read the whole shortcut with
  a strict UTF-8 decoder, so one ANSI byte anywhere in the file threw and the
  shortcut was dropped as `LaunchItemInvalid` — here in `IconFile`, a field the
  menu never reads. The read now falls back to `TextInfo.ANSICodePage`. Every
  existing fixture was ASCII, which is why the suite never caught it.
- 2026-08-19: Investigated blank icons in the same folder. No defect: all three
  `IconFile` targets were absent. Treat a blank icon as a missing target first.
- 2026-08-19: Added `Clear-LaunchTreeCache` so an operator can discard cached
  icons without `Remove-LaunchTree`, which also deletes Start Entries and the
  event registration. `ADR-0007` carries a dated amendment for the eighth
  command, `FR-034` specifies it, and both single-file deliveries reach it as
  `-Command ClearCache`. Verified against the real cache: 159 entries discarded.
- 2026-08-19: Removed Content Source subtitles from compact Launcher rows.
- 2026-08-19: Fixed the Launcher taskbar button showing the PowerShell host
  icon even though the window and Alt+Tab used the embedded LaunchTree icon.
  The native HWND now receives the per-window AppUserModelID
  `LaunchTree.Launcher` during WPF `SourceInitialized`, separating its taskbar
  group without changing the identity of the hosting PowerShell process.
- 2026-08-19: Replaced the title-bar gear with the classic Minimize and Maximize
  controls on customer request and moved the shortcut wizard to
  `New-LaunchTreeShortcut`, reachable as `-Command CreateShortcut` in both
  single-file deliveries; `ADR-0007` carries a second dated amendment and the
  theme moved into `Get-LaunchTreeTheme`. Maximize needed no chrome workaround:
  `WindowChrome` clips the window region to the work area, so only the
  remembered geometry (`RestoreBounds`) and the tab width fit needed a guard.

## Stable capabilities

- Managed and Personal Content Sources merge into immutable Content Snapshots.
- Native Start Entries carry opaque Entry IDs into a session-local Launcher.
- Reconciliation is ownership-aware, idempotent, and rollback-protected.
- WPF rendering, Shell icons, cache, preferences, navigation, and capture
  validation are implemented.
- Event Log ACL validation, linked standard-user probing, structured event
  emission, health, and redacted Support Bundles are implemented.

## Open work

- Close High-priority compatibility and validation issues before release.
- Implement Generated State schema migration before introducing schema 2.
