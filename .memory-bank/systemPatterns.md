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
invocation to Windows Shell, manages only generated state and caches, and takes
opaque Entry IDs across the process boundary. Reconciliation is transactional,
and a dedicated event log is writable by standard interactive users.
Implementation adds a current-user named-pipe activation channel, bounded
versioned icon cache, presentation-only preference file, structured Health
Findings, diagnostics, and tested layout helpers. No runtime artifact has an
external dependency; themed XAML and content-sized scrollbar strips are
invariants. `TabbedList` omits `Grid` search and sort, separates tab-strip owner
from selected tab, and keeps an owning tab only while it holds a Launch Item.

## Documentation

`docs/getting-started.md` is the canonical first-run operator path. It stays
task-oriented and links to deployment and specifications instead of duplicating
those contracts. `tools/Initialize-QuickStart.ps1` is the scripted fast path: it
creates only administrator-authored inputs, keeps existing files unless forced,
and leaves Reconciliation to `Update-LaunchTree`. Every documented sample block
must run standalone: it resolves the values it uses instead of relying on an
earlier block, and a multistatement block runs inside
`& { $ErrorActionPreference = 'Stop'; ... }` so the first failure stops it.

## Constraints

Root resolution has one owner, `Get-LaunchTreeConfiguration`; commands forward
the `CR-013` `ManagedRoot` and `PersonalRoot` overrides to it. An invalid
override throws instead of falling back, and `Update-LaunchTree` refuses them
because an activated Start Entry re-resolves its root from the configuration.

The standard-user Event Log probe (`Initialize-LaunchTreeUnelevatedProcess` plus
`Invoke-LaunchTreeStandardUserEventProbe`) launches a de-elevated process with
`CreateProcessWithTokenW` and the UAC-linked token. From an interactive elevated
admin that token is `Identification`-level, which the API rejects; raising it
needs `SeTcbPrivilege`, held only by SYSTEM. The probe is therefore best-effort
and never throws, and `Test-LaunchTree` reports
`StandardUserEventAccessUnverified`.

Windows binds an event source name to exactly one classic log, and
`System.Diagnostics.EventLog.WriteEntry` registers an unknown source in the
`Application` log when the caller is elevated. Runtime code therefore resolves
the source through `[Diagnostics.EventLog]::LogNameFromSourceName` first; a
mismatch skips the write instead of registering anything.

Shell icon extraction runs on the dedicated STA worker owned by
`LaunchTree.NativeIcon`, never on the thread pool. `IShellItemImageFactory`
succeeds in any apartment, but the internet shortcut handler answers only in an
STA and the shell substitutes the generic file icon elsewhere, so an MTA thread
yields a plausible but wrong image instead of an error. The worker is one
background STA thread running a WPF `Dispatcher`, which supplies the queue and
bounds thread count at any scale; every frame is frozen before it crosses back.
Supplying `-ReferencedAssemblies` replaces the PowerShell 7 default reference
set, so `Initialize-LaunchTreeWpf` re-adds the `$PSHOME\ref` threading
assemblies when that folder exists.

## Delivery

The Sampler module under `output/module/LaunchTree/<version>` stays the
recommended form and is unchanged. `output/LaunchTree.ps1` is a generated
self-contained script for hosts where installing a module is impractical. Both
scripts are generated, never hand-maintained:
`tools/Build-LaunchTreeScript.ps1` concatenates the selected `source/Private`
and `source/Public` functions and parse-checks the result.

`-Variant Full` embeds every function; the `Build_Single_File_Script` task runs
it during `build`. `-Variant Minimal` emits the Launcher-only
`output/LaunchTree.Minimal.ps1`, with parameters `-Command Show`, `-EntryName`,
and `-ManagedRoot`. Its content is derived, not curated: files in
`tools/MinimalVariant` replace same-named module functions to drop the Event Log
and every JSON reader, an AST call-graph traversal from `Show-LaunchTree` over
the overridden graph selects what to embed, and a token-stream comparison proves
the comment strip changed nothing.

Host-dependent values resolve through the private
`Get-LaunchTreeRuntimeContext`: the module base, version, launcher path, and
probe path as a module, and the script's own path plus a `-Command` token when
running standalone. A binary asset the runtime needs is embedded as base64 in
the private function that decodes it, because the single-file deliveries carry
functions only. `source/Assets` holds the editable source of truth and a unit
test compares it against the embedded copy.

## Decisions

Durable context stays evidence-backed in `.memory-bank`, and
`docs/design-concept.md` is a sign-off gate: the native/WPF and deployment
boundaries required a requirements interview before implementation.

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
