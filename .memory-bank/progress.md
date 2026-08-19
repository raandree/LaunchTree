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
  `CR-013` root overrides on `Get-LaunchTreeConfiguration`, `Show-LaunchTree`,
  `Test-LaunchTree`, and `Export-LaunchTreeSupportBundle`, rejecting a relative
  value instead of falling back; `Update-LaunchTree` is excluded because an
  activated Start Entry re-resolves the root from the configuration file.
  Replaced the tall header with one compact line that doubles as the drag
  handle and restores a remembered position clamped to the virtual screen.
  Durable lessons from that run, each paid for by a live-UI failure: a themed
  `ComboBox` needs a full XAML `Style` or it renders as a classic control
  inside the dark window; a fixed-height tab strip starves its labels once a
  scrollbar appears, so it must size to content; a tab handler that rebuilds
  the strip from shared selection state enters the wrong folder, so tab-strip
  owner and selected tab are tracked separately and only a list row descends;
  and `TabItem.DesiredSize` or a single `ExtentWidth` read under-measures the
  strip by about one tab, so the width fit grows by reported overflow until
  scrolling stops. Menu Folders with no Launch Item beneath them are hidden,
  and a tab whose owner holds no Launch Item of its own redirects to its first
  child unless nothing can replace it. Added `AS-018` and `AS-020`.
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
  supplied three in-house apps as the reference pattern. A first pass sized the
  field to its content; the customer rejected that because the tab strip moved
  whenever a tab carried a different description, so the field now reserves
  exactly two lines at a 16 DIU line height, truncates a longer text with an
  ellipsis, and keeps the full text in the tooltip. It is collapsed in `Grid`.
  Captures of one line, two full lines, an overflowing text, and no
  `description.txt` all place the tab strip at the same position.
- 2026-08-18: Fixed a customer report that a Managed Root on a DFS namespace
  found no Entry Roots. A DFS link is a directory reparse point, and traversal
  skipped every reparse point, so `Show-LaunchTree` threw `Entry Root '<name>'
  was not found`. Traversal now reads the reparse tag through `FindFirstFileW`
  and admits only `IO_REPARSE_TAG_DFS` and `IO_REPARSE_TAG_DFSR`; junctions,
  symbolic links, and mount points stay excluded with a `ReparsePointIgnored`
  finding. Verified on the lab namespace `\\contoso.com\Data`, whose `Files`
  link targets the hidden shares `\\vwS1\Files$` and `\\vwS2\Files$`: the Entry
  Root is discovered, 201 objects are read through the referral, the DFSR mount
  point is still ignored, and the Minimal delivery opens the Launcher with the
  customer's exact command on both editions. Suite: 197 passed, 1 skip.
- 2026-08-19: Fixed a customer report that a folder holding three `.url` files
  showed only two. `Get-LaunchTreeLaunchItemDetail` read the whole shortcut with
  a strict UTF-8 decoder, so one byte of the system ANSI code page anywhere in
  the file threw and the shortcut was dropped as `LaunchItemInvalid`. The byte
  sat in `IconFile=C:\...\IT Service Hashtag wei\xDF gro\xDF.ico`, a field the menu
  never reads. Windows writes `.url` files in the ANSI code page, and no
  requirement demands UTF-8 for them, so the read now falls back to
  `TextInfo.ANSICodePage` on `DecoderFallbackException`; the `http`/`https`
  scheme check is unchanged. Every existing test wrote its `.url` fixtures as
  ASCII, which is why the suite never caught it. Verified against the real
  folder: all three items appear with no Health Finding. Suite: 198 passed,
  1 skip.
- 2026-08-19: Investigated a follow-up report that the same folder still showed
  blank icons for three `.url` items, suspected to be a second decoding fault.
  No defect: the shortcut is plain CP1252, the host ANSI code page is 1252, and
  the icon never passes through LaunchTree because `NativeIcon` hands the shell
  the `.url` path and the internet shortcut handler resolves `IconFile` itself.
  A pixel-hash probe showed all three targets were simply absent, one saved with
  a doubled `.ico.ico` extension. Treat a blank Launch Item icon as a missing
  `IconFile` target until a byte dump says otherwise. Fixing the file name did
  not help either, because `Get-LaunchTreeIconCachePath` keys on the shortcut's
  own path, length, and `LastWriteTimeUtc` and never observes the icon target.
- 2026-08-19: Added `Clear-LaunchTreeCache` so an operator can discard cached
  icons without `Remove-LaunchTree`, which also deletes Start Entries and the
  event registration. It resolves the namespace through
  `Get-LaunchTreeConfiguration`, accepts a `-CachePath` override, supports
  `ShouldProcess` at `Medium` impact, removes only `*.png`, keeps the namespace
  directory so the next Launcher run repopulates it, and returns the entry count
  and bytes reclaimed. `ADR-0007` fixed the public surface at seven commands, so
  it carries a dated amendment rather than a silent breach; added `FR-034`,
  raised the `Test-Documentation.ps1` `FR` range to 34, and wired `ClearCache`
  into the full single-file dispatch map. Verified against the real cache: 159
  entries and 561,321 bytes discarded. Suite: 209 passed, 1 skip. The same edit
  curated `progress.md` and `systemPatterns.md` back inside their line budgets,
  which had both been breached since before this session. Follow-up the same
  day: the customer asked for it in `LaunchTree.Minimal.ps1` too, so the Minimal
  closure now starts from both `Show-LaunchTree` and `Clear-LaunchTreeCache` and
  the script accepts `-Command ClearCache`. It costs one function and about 4 KB
  because the Minimal `Get-LaunchTreeConfiguration` override already supplies
  `Cache.Path`. Suite: 210 passed, 1 skip.
- 2026-08-19: Removed Content Source subtitles from compact Launcher rows.
- 2026-08-19: Fixed the Launcher taskbar button showing the PowerShell host
  icon even though the window and Alt+Tab used the embedded LaunchTree icon.
  The native HWND now receives the per-window AppUserModelID
  `LaunchTree.Launcher` during WPF `SourceInitialized`, separating its taskbar
  group without changing the identity of the hosting PowerShell process.

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
