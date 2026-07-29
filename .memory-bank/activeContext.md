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
- The Launcher header is one compact line (Back, title, active description,
  Close) that doubles as the window drag handle; the current path is the title
  tooltip and the full description is the description tooltip.
- A dragged window position is remembered and restored on the next activation,
  clamped to the virtual screen; only a first run without stored coordinates
  opens near the Start button.
Run the outstanding external matrix and policy validations before declaring a
production-ready release. `OI-009` still needs a real standard-user Event Log
verification path (unelevated shell or Task Scheduler) now that the inline
linked-token probe is best-effort and non-fatal. The single-file script delivery
needs the same external matrix coverage as the module. The development machine
still has the stray `LaunchTree` source bound to the `Application` log; remove
it with `[Diagnostics.EventLog]::DeleteEventSource('LaunchTree')` from an
elevated session before rerunning Reconciliation there.
