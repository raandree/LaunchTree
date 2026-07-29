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
item invocation to Windows Shell, and manages only generated state and caches.
Opaque Entry IDs cross the Start Entry process boundary. Reconciliation is
transactional, and a dedicated event log is explicitly writable by standard
interactive users.

Implementation adds a current-user named-pipe activation channel, bounded
versioned icon cache, presentation-only preference file, structured Health
Findings, diagnostics, WPF/offline validation, and tested layout helpers.
`Grid` remains the default Launcher Layout; `TabbedList` projects snapshots
into tabs and rows. Runtime artifacts have no external dependency. Every
Launcher control uses explicit themed XAML with paired high-contrast colors.

## Documentation

`docs/getting-started.md` is the canonical first-run operator path. It remains
task-oriented and links to deployment and specifications for advanced or
normative details instead of duplicating those contracts.

`tools/Initialize-QuickStart.ps1` is the scripted fast path for that guide. It
creates only administrator-authored inputs, keeps existing files unless forced,
and leaves Reconciliation to `Update-LaunchTree`, so the public command surface
in `ADR-0007` stays unchanged.

Every documented sample block must run standalone. A block resolves the values
it uses instead of relying on a variable from an earlier block, and a
multistatement block runs inside `& { $ErrorActionPreference = 'Stop'; ... }`
so the first failure stops the block instead of cascading.

## Constraints

The standard-user Event Log probe (`Initialize-LaunchTreeUnelevatedProcess` plus
`Invoke-LaunchTreeStandardUserEventProbe`) launches a de-elevated process with
`CreateProcessWithTokenW` and the UAC-linked token. From an interactive elevated
admin the linked token is `Identification`-level, which that API rejects
(`ERROR_ACCESS_DENIED`); a usable `Impersonation`-level linked token requires
`SeTcbPrivilege`, held only by SYSTEM. The probe is therefore best-effort: it
returns a structured `LaunchTree.EventProbeResult` (never throws), Reconciliation
still registers the log and Interactive Users access,
`Register-LaunchTreeEventLog` warns and emits event `1603`, and `Test-LaunchTree`
reports the `StandardUserEventAccessUnverified` finding. Real standard-user
verification still needs a de-elevation path through the unelevated shell or
Task Scheduler.

Windows binds an event source name to exactly one classic log, and
`System.Diagnostics.EventLog.WriteEntry` registers an unknown source in the
`Application` log when the caller is elevated. Runtime code therefore never
writes without first resolving the source through
`[Diagnostics.EventLog]::LogNameFromSourceName` and comparing it to the
configured log; a mismatch skips the write instead of registering anything, so
only elevated Reconciliation can create the dedicated log and source.

## Delivery

Two delivery forms share one source. The Sampler module under
`output/module/LaunchTree/<version>` stays the recommended form and is
unchanged. `output/LaunchTree.ps1` is a generated self-contained script for
hosts where installing a module is impractical.

The script is generated, never hand-maintained, so it cannot drift:
`tools/Build-LaunchTreeScript.ps1` concatenates every `source/Private` and
`source/Public` function, parse-checks the result, and the
`Build_Single_File_Script` task runs it during `build`.

Host-dependent values resolve through the private
`Get-LaunchTreeRuntimeContext`, which returns the module base, version, launcher
path, and probe path when running as a module, and the script's own path plus a
`-Command` token when running standalone. Consumers never read
`$ExecutionContext.SessionState.Module` directly, so module behavior is
identical while the script targets itself for Start Entries and the
standard-user probe.

## Decisions

### Decision 1: Use the canonical Memory Bank base

- Choice: Keep durable project context in .memory-bank.
- Rationale: Preserve evidence-backed context across sessions.

### Decision 2: Require design sign-off before implementation

- Choice: Treat `docs/design-concept.md` as a draft gate for module work.
- Rationale: The native/WPF boundary and deployment constraints required an
  explicit requirements interview before code could be evaluated correctly.

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
