---
status: current
last-verified: 2026-08-19
owner: active-agent
source: repository evidence
---

# System patterns

## Architecture

Accepted: machine-wide native Start shortcuts open one session-local WPF launcher
process. A managed directory tree supplies entry roots and a roaming per-user tree
augments matching roots. The launcher reads snapshots, delegates invocation to
Windows Shell, manages only generated state and caches, and takes opaque Entry IDs
across the process boundary. Reconciliation is transactional, its event log is
writable by standard interactive users, and runtime artifacts have no dependency.

## Documentation

`docs/getting-started.md` is the canonical first-run operator path and links to
deployment and specifications instead of duplicating them;
`tools/Initialize-QuickStart.ps1` is the scripted fast path. Every documented
sample block runs standalone, multistatement ones inside
`& { $ErrorActionPreference = 'Stop'; ... }`.

## Constraints

Root resolution has one owner, `Get-LaunchTreeConfiguration`; commands forward the
`CR-013` root overrides and the `CR-014` `CloseAfterLaunch` override to it. An
invalid override throws instead of falling back, and `Update-LaunchTree` refuses
root overrides because an activated Start Entry re-resolves its root.

The standard-user Event Log probe (`Initialize-LaunchTreeUnelevatedProcess` plus
`Invoke-LaunchTreeStandardUserEventProbe`) de-elevates through
`CreateProcessWithTokenW` and the UAC-linked token, which is only
`Identification`-level from an interactive elevated admin; raising it needs
`SeTcbPrivilege`, held only by SYSTEM, so the probe is best-effort and
`Test-LaunchTree` reports `StandardUserEventAccessUnverified`. Windows binds an
event source name to one classic log, and `EventLog.WriteEntry` registers an
unknown source in `Application` when the caller is elevated, so runtime code
resolves it through `LogNameFromSourceName` first.

An icon cache key covers the shortcut's path, length, and last-write time, never
the icon target, so a repaired target cannot invalidate the entry it produced;
`Clear-LaunchTreeCache` is the escape hatch. Shell icon extraction runs on the
STA worker owned by `LaunchTree.NativeIcon`, because the internet shortcut
handler answers only in an STA and elsewhere the shell substitutes the generic
file icon. The Launcher sets `System.AppUserModel.ID` on its HWND during
`SourceInitialized`, because `Window.Icon` alone can group it under PowerShell.
Content Source metadata uses the encoding its producing component writes:
`description.txt` stays strict UTF-8, while a Windows-authored `.lnk` or `.url`
is ANSI, so `Get-LaunchTreeLaunchItemDetail` falls back to the ANSI code page.
Every filesystem probe over Managed or Personal content passes an explicit
`ErrorAction`: `Test-Path` writes a non-terminating `UnauthorizedAccessException`
rather than `$false` when the directory denies list or traverse access; the
description probe uses `Stop` and degrades to `DescriptionUnavailable`, the root
probes use `Ignore`. An Entry Root path is split with plain string operations,
never `Split-Path` or the .NET path helpers, which throw on a bare drive
specifier and disagree across editions about the parent of a UNC share. A
wizard-created shortcut is user-owned: it names its Entry Root directly and
Reconciliation ignores it.

Shell invocation never asks for a process object: `-PassThru` fails a launch that
succeeded, because Windows Shell returns no handle when it hands the request to a
running instance, an elevated process, or a protocol handler. A type compiled
against WPF must reference `System.Xaml` explicitly, because `Window` implements
`System.Windows.Markup.IQueryAmbient` and the Windows PowerShell compiler will
not resolve it while PowerShell 7 does; the Launcher is normally hosted by
Windows PowerShell, so such an omission stays invisible to a PowerShell 7 test
run. A borderless window that carries a `WindowChrome` needs no maximize
workaround: WPF clips its window region to the work area, but the remembered
geometry must come from `RestoreBounds` while maximized.

## Delivery

The Sampler module under `output/module/LaunchTree/<version>` stays the
recommended form. `tools/Build-LaunchTreeScript.ps1` also emits a parse-checked
`output/LaunchTree.ps1`, and `output/LaunchTree.Minimal.ps1` for `Show`,
`ClearCache`, and `CreateShortcut`. Minimal content is derived, not curated:
`tools/MinimalVariant` files replace same-named module functions to drop the
Event Log and every JSON reader, an AST call-graph traversal selects what to
embed, and a token comparison proves the comment strip changed nothing.
`tools/Build-LaunchTreeExecutable.ps1` then compiles each script with the in-box
.NET Framework compiler, embedding script and bootstrap as resources. That host
must implement a `PSHost`, because `exit` reaches a caller only through
`SetShouldExit`, and must bind argument names against the embedded script's
`ParamBlock`, because splatting an argument array binds by position only. A
compiled delivery reports `LauncherIsExecutable`, so its Start Entries, wizard
shortcuts, and probe target the executable itself; a binary asset stays base64
in the private function that decodes it. Continuous integration mirrors that
boundary: `.github/workflows/ci.yml` runs every job on Windows and matrixes the
two supported hosts, not two operating systems; publication stays token-gated.

## Decisions

Durable context stays evidence-backed in `.memory-bank`, and
`docs/design-concept.md` is a sign-off gate: the native/WPF and deployment
boundaries required a requirements interview before implementation. Directory
traversal decides on the reparse tag from `FindFirstFileW`, not the attribute, so
`Test-LaunchTreeTraversableDirectory` admits the DFS tags, refuses every other
one, and a junction or mount point cannot leave the root.

- `ADR-0001..0003`: native Start Entries open the WPF Launcher, Managed and
  Personal sources merge by relative path, Windows Shell invokes Launch Items.
- `ADR-0004..0007`: Sampler module with a WPF runtime, transactional
  Reconciliation, versioned configuration/event/cache contracts, read-mostly
  surface amended by `Clear-LaunchTreeCache` and `New-LaunchTreeShortcut`.
- `ADR-0008..0010`: opaque Entry ID activation through a validated Launcher Host,
  standard-user diagnostic log access, long-path degradation.
