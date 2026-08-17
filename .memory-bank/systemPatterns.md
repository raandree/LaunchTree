---
status: current
last-verified: 2026-07-29
owner: active-agent
source: repository evidence
---

# System patterns

## Architecture

Accepted: machine-wide native Start shortcuts open one session-local WPF
launcher process. A managed directory tree supplies entry roots; a roaming
per-user tree augments matching roots. The launcher reads snapshots, delegates
item invocation to Windows Shell, manages only generated state and caches, and
receives opaque Entry IDs across the Start Entry process boundary.
Reconciliation is transactional, and a dedicated event log is explicitly
writable by standard interactive users.

Implementation adds a current-user named-pipe activation channel, bounded
versioned icon cache, presentation-only preference file, structured Health
Findings, diagnostics, WPF/offline validation, and tested layout helpers.
Runtime artifacts have no external dependency; themed XAML and content-sized
scrollbar strips are invariants. `TabbedList` omits `Grid` search and sort,
separates the tab-strip owner from the selected tab, and descends only through a
Menu Folder row; an owning Menu Folder keeps a tab only while it holds a direct
Launch Item, otherwise the first sorted child tab replaces it.

## Documentation

`docs/getting-started.md` is the canonical first-run operator path. It remains
task-oriented and links to deployment and specifications for advanced or
normative details instead of duplicating those contracts.
`tools/Initialize-QuickStart.ps1` is the scripted fast path for that guide: it
creates only administrator-authored inputs, keeps existing files unless forced,
and leaves Reconciliation to `Update-LaunchTree`, so the public command surface
in `ADR-0007` stays unchanged.

Every documented sample block must run standalone: it resolves the values it
uses instead of relying on an earlier block, and a multistatement block runs
inside `& { $ErrorActionPreference = 'Stop'; ... }` so the first failure stops
the block instead of cascading.

## Constraints

Root resolution has one owner, `Get-LaunchTreeConfiguration`; commands forward
the `CR-013` `ManagedRoot` and `PersonalRoot` overrides to it. An invalid
override throws instead of falling back, and `Update-LaunchTree` refuses them
because an activated Start Entry re-resolves its root from the configuration.

The standard-user Event Log probe (`Initialize-LaunchTreeUnelevatedProcess` plus
`Invoke-LaunchTreeStandardUserEventProbe`) launches a de-elevated process with
`CreateProcessWithTokenW` and the UAC-linked token. From an interactive elevated
admin that token is `Identification`-level, which the API rejects
(`ERROR_ACCESS_DENIED`); an `Impersonation`-level token needs `SeTcbPrivilege`,
held only by SYSTEM. The probe is therefore best-effort and never throws:
Reconciliation still registers the log and Interactive Users access,
`Register-LaunchTreeEventLog` warns and emits event `1603`, and `Test-LaunchTree`
reports `StandardUserEventAccessUnverified`. Real verification still needs a
de-elevation path through the unelevated shell or Task Scheduler.

Windows binds an event source name to exactly one classic log, and
`System.Diagnostics.EventLog.WriteEntry` registers an unknown source in the
`Application` log when the caller is elevated. Runtime code therefore resolves
the source through `[Diagnostics.EventLog]::LogNameFromSourceName` before
writing; a mismatch skips the write instead of registering anything, so only
elevated Reconciliation can create the dedicated log and source.

## Delivery

The Sampler module under `output/module/LaunchTree/<version>` stays the
recommended form and is unchanged. `output/LaunchTree.ps1` is a generated
self-contained script for hosts where installing a module is impractical. Both
scripts are generated, never hand-maintained, so they cannot drift:
`tools/Build-LaunchTreeScript.ps1` concatenates the selected `source/Private`
and `source/Public` functions and parse-checks the result.

`-Variant Full` embeds every function; the `Build_Single_File_Script` task runs
it during `build`. `-Variant Minimal` emits the Launcher-only
`output/LaunchTree.Minimal.ps1` through `Build_Minimal_Single_File_Script`, with
parameters `-Command Show`, `-EntryName`, and `-ManagedRoot`. Its content is
derived, not curated: an AST call-graph traversal from `Show-LaunchTree` selects
what to embed, a guard scans every non-comment token for an omitted function
name so a name reached only through a string still fails the build, and a
token-stream comparison proves the comment and blank-line strip that follows
changed nothing but comments and whitespace.

Host-dependent values resolve through the private
`Get-LaunchTreeRuntimeContext`, which returns the module base, version, launcher
path, and probe path when running as a module, and the script's own path plus a
`-Command` token when running standalone, so module behavior is identical while
a script targets itself for Start Entries and the standard-user probe.

## Decisions

- Keep evidence-backed durable context in `.memory-bank` across sessions.
- Treat `docs/design-concept.md` as a sign-off gate; the native/WPF and
  deployment boundaries required a requirements interview before implementation.
## Decision record index

- `ADR-0001`: Native Start Entries open the WPF Launcher.
- `ADR-0002`: Managed and Personal Content Sources merge by relative path.
- `ADR-0003`: Windows Shell invokes Launch Items.
- `ADR-0004`: Sampler PowerShell module with a WPF runtime.
- `ADR-0005`: Transactional Reconciliation and ownership records.
- `ADR-0006`: Versioned configuration, events, and cache contracts.
- `ADR-0007`: Seven-command read-mostly public surface.
- `ADR-0008`: Opaque Entry ID activation through a validated Launcher Host.
- `ADR-0009`: Standard-user access to the dedicated diagnostic event log.
- `ADR-0010`: Explicit long-path degradation on Windows PowerShell 5.1.
