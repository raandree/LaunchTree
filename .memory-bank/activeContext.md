---
status: current
last-verified: 2026-07-29
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
  self-contained; a unit test guards asset and embedding against drift.
- The window applies a `WindowChrome` with `CaptionHeight` and
  `GlassFrameThickness` at zero, because a borderless resizable window
  otherwise keeps its top resize border inside the visible frame and shows a
  thicker top edge. Client and window rect are now flush on all four sides.
- A dragged window position is remembered and restored on the next activation,
  clamped to the virtual screen; only a first run without stored coordinates
  opens near the Start button.
- `TabbedList` sizes the window width to its tab strip instead of scrolling the
  tabs, and shows no item count.
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
- A Managed Root on a DFS namespace works: traversal admits the DFS reparse
  tags and still refuses junctions, symbolic links, and mount points. Hidden
  (`$`) link targets need no special handling, because the referral is resolved
  before LaunchTree reads the directory.
Run the outstanding external matrix and policy validations before declaring a
production-ready release. `OI-009` still needs a real standard-user Event Log
verification path (unelevated shell or Task Scheduler) now that the inline
linked-token probe is best-effort and non-fatal. The single-file script delivery
needs the same external matrix coverage as the module. The development machine
still has the stray `LaunchTree` source bound to the `Application` log; remove
it with `[Diagnostics.EventLog]::DeleteEventSource('LaunchTree')` from an
elevated session before rerunning Reconciliation there.
