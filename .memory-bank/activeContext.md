---
status: current
last-verified: 2026-08-19
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

Complete external release validation for the implemented LaunchTree module
while preserving the approved behavior and security boundaries.

## Evidence

- Memory Bank initialized from the canonical base.
- Requirements interview covered purpose, users, inputs/outputs, failures,
  boundaries, security, performance, operations, rollback, observability,
  non-goals, and open questions.
- The signed Design Concept and accepted specifications control the module.
- Seven exported commands implement configuration, health, Reconciliation,
    Launcher display, diagnostics, Support Bundle export, and removal.
- Full Sampler workflows pass under PowerShell 7 and Windows PowerShell 5.1
    with 173 tests, zero failures, and one intentional host-dependent skip in
    each supported edition.
- The isolated file-copy lifecycle is `Healthy`, exercises the Launcher, and
    removes Generated State with zero runtime dependencies.
- Independent security and quality re-review approved the implementation with
    no remaining Blocker or Major.
- `docs/open-issues.md` tracks ten issues. External Windows Server, ARM64,
    visual-matrix, application-control, and elevated Event Log evidence remain
    release gates; schema-2 migration is future work.
- The product, module, command noun prefix, paths, configuration file names,
    Event Log name and source, and type names are renamed to `LaunchTree`
    before first release, so no deployed Generated State needs migration.
- Machine configuration selects the Launcher Layout: `TabbedList` is the
    customer-requested default showing Menu Folders as tabs, the active
    description above them, and Launch Items as compact rows; `Grid` remains
    selectable for the tile presentation.
- `TabbedList` tab selection keeps the tab strip visible: a tab highlights and
    opens in place, and only a Menu Folder list row moves the strip deeper.
- The tab strip's owning Entry Root or Menu Folder keeps a tab only while it
    holds a Launch Item of its own; otherwise the first child tab is selected.
- Deterministic nonblank captures validate both Launcher Layouts; independent
    re-review approved the change with no remaining Blocker or Major findings.
- `CR-013` lets a caller relocate the menu for one invocation through
    `ManagedRoot` and `PersonalRoot` parameters on the read commands, while
    persistent relocation still belongs in the machine configuration.
- The Launcher's compact top line is a window title bar (application icon,
  Entry Root title, Close) that doubles as the window drag handle; the selected
  description sits in a `TabbedList` field directly below it that always
  reserves two lines, the Back control sits at the left of the navigation strip
  below that, and the current path is the title tooltip.
- The application icon is `source/Assets/LaunchTree.ico`, embedded as base64 in
  `Get-LaunchTreeApplicationIcon` so the single-file deliveries stay
  self-contained; a unit test guards asset and embedding against drift. The
  native Launcher window receives the per-window AppUserModelID
  `LaunchTree.Launcher`, so Windows does not group its taskbar button under the
  PowerShell host icon.
- The window applies a `WindowChrome` with `CaptionHeight` and
  `GlassFrameThickness` at zero, because a borderless resizable window
  otherwise keeps its top resize border inside the visible frame and shows a
  thicker top edge. Client and window rect are now flush on all four sides.
- A dragged window position is remembered and restored on the next activation,
  clamped to the virtual screen; only a first run without stored coordinates
  opens near the Start button.
- `TabbedList` sizes the window width to its tab strip instead of scrolling the
  tabs, and shows no item count.
- Compact `TabbedList` rows show a description only when one exists; Content
  Source metadata is never used as subtitle filler.
- The repository is licensed under MIT and carries the governance files a public
  release needs: `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, and `CODEOWNERS`.
  A disclosure audit of every tracked file, the full commit history, and every
  historical screenshot blob found no personally identifiable information in
  content, no secrets, and no customer or agency reference; the author identity
  in commit metadata is accepted as public by the owner.
- The build emits two single-file artifacts. `output/LaunchTree.ps1` is
  unchanged. `output/LaunchTree.Minimal.ps1` is derived from the
  `Show-LaunchTree` call graph for hosts that only open the Launcher, and needs
  the same external matrix coverage as the other two deliveries.
- The build also compiles each of those scripts into `output/LaunchTree.exe` and
  `output/LaunchTree.Minimal.exe` with the in-box .NET Framework compiler, so an
  executable delivery costs no external dependency. The embedded script is not a
  file on disk, so under WDAC or AppLocker enforcement it runs in Constrained
  Language Mode where an allowed `.ps1` would not; the executables are unsigned
  and need the same external matrix coverage as the other deliveries.
- A Managed Root on a DFS namespace works: traversal admits the DFS reparse
  tags and still refuses junctions, symbolic links, and mount points. Hidden
  (`$`) link targets need no special handling, because the referral is resolved
  before LaunchTree reads the directory.
- Real `.url` files are ANSI, not UTF-8. Content readers must decode a
  shortcut leniently and validate only the fields they consume, because a
  strict whole-file UTF-8 read made a valid Launch Item vanish over a byte in
  `IconFile`. Content fixtures must cover ANSI bytes, not only ASCII.
- An icon cache entry cannot notice that its icon target changed, because the
  key covers only the shortcut. `Clear-LaunchTreeCache` is the eighth exported
  command and the supported recovery; `ADR-0007` carries a dated amendment for
  the enlarged surface and `FR-034` specifies the behavior. It reaches every
  delivery: the module, `-Command ClearCache` in the full script, and the same
  switch in `LaunchTree.Minimal.ps1`, whose embedded set now derives from two
  entry points rather than one.
- `Test-Path` does not return `$false` for a path it may not probe: it writes a
  non-terminating `UnauthorizedAccessException`. Content traversal therefore
  passes an explicit `ErrorAction` on every probe, so a denied Menu Folder on a
  DFS Managed Root degrades to Health Findings instead of printing a raw error
  before the Launcher opens.
- The Launcher title bar carries the classic Minimize, Maximize, and Close
  controls. The shortcut wizard is no longer a gear beside Close: `FR-035` is
  now the `New-LaunchTreeShortcut` command, which both single-file deliveries
  reach as `-Command CreateShortcut`. The wizard derives the Managed Root from
  the parent of the entered Entry Root folder and the Entry Root name from its
  last segment, and writes the `CR-015` shortcut through a save dialog. The
  result is user-owned, not Generated State.
- WPF's `WindowChrome` handles the maximized borderless window itself: measured
  on a 150% display, the window rect is inflated by the resize border while the
  window region is clipped to exactly the work area, so no compensating margin
  is needed. The remembered geometry uses `RestoreBounds` while maximized, and
  the tab-strip width fit is skipped in that state.
- `CloseAfterLaunch` now defaults to `false`, so the Launcher stays open after an
  item starts. `CR-014` adds a call-scoped switch on `Get-LaunchTreeConfiguration`
  and `Show-LaunchTree`, and the wizard bakes it into the shortcut it writes.
- The Launcher could not start under Windows PowerShell 5.1 at all: the native
  window helper failed to compile because `Window` implements `IQueryAmbient` and
  `System.Xaml` was not referenced. Because 5.1 is the default `LauncherHost`,
  every Start Entry was affected while the PowerShell 7 test run stayed green.
  Validate host-dependent WPF work on the edition that actually hosts it.
- The Pester build dependency is `latest` rather than a pinned version and now
  resolves Pester 6.1.0 on both supported editions. The suite needed no
  conversion, because it uses only the classic `Should` assertions that Pester 6
  keeps. New tests must stay self-contained: Pester 6 discovers and runs one file
  at a time, so a discovery-time side effect no longer reaches another file.
- The `Get-LaunchTreeContentSnapshot` test 'Should report a Menu Folder that
  denies access without writing a host error' fails on `main`. It expects both
  `DescriptionUnavailable` and `ContentPathInaccessible` but the snapshot reports
  only `ContentPathInaccessible`. The failure predates the Pester upgrade and
  reproduces with Pester 5.7.1, so it belongs to the denied-Menu-Folder work,
  not to the dependency change. It also decides the color of the first GitHub
  Actions run: the CI test legs stay red until it is fixed.
- Continuous integration is `.github/workflows/ci.yml`, Windows only, with the
  test matrix over the two supported hosts instead of over operating systems.
  Releasing is token-gated in `build.yaml`, so nothing publishes until
  `GitHubToken` and `GalleryApiToken` exist in the repository. Adding them makes
  every push to `main` a stable release, because `GitVersion.yml` declares
  `main` a release branch with no prerelease tag.
Run the outstanding external matrix and policy validations before declaring a
production-ready release. `OI-009` still needs a real standard-user Event Log
verification path (unelevated shell or Task Scheduler) now that the inline
linked-token probe is best-effort and non-fatal. The single-file script delivery
needs the same external matrix coverage as the module. The development machine
still has the stray `LaunchTree` source bound to the `Application` log; remove
it with `[Diagnostics.EventLog]::DeleteEventSource('LaunchTree')` from an
elevated session before rerunning Reconciliation there.
