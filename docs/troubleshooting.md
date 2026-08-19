# Troubleshooting

Use `Test-LaunchTree` first. Its `Status` is `Healthy`, `Degraded`, or
`Unhealthy`, followed by structured Health Findings.

## Missing Start Entries

1. Verify the immediate directory exists under the Managed Root.
2. Run `Test-LaunchTree` and inspect `GeneratedStateMissing`,
   `OwnedStartEntryMissing`, and collision findings.
3. Run elevated `Update-LaunchTree -Confirm:$false`.
4. Confirm no unowned shortcut already uses the Entry Root name in Common
   Programs.

Personal-only directories do not create machine-wide Start Entries. The
Personal Root augments matching managed Entry Roots.

## Managed Root on a DFS namespace

An Entry Root published as a DFS link is a directory reparse point. LaunchTree
traverses `IO_REPARSE_TAG_DFS` and `IO_REPARSE_TAG_DFSR` and ignores every other
directory reparse point, so a Managed Root such as
`\\contoso.com\Namespace\Menus` finds its Entry Roots whether they are plain
directories or DFS links, and whether a link target is a visible or a hidden
(`$`) share.

If an Entry Root below a DFS Managed Root is still missing, check in this order:

1. Confirm the referral resolves for the signed-in user:
   `Get-ChildItem -LiteralPath '\\contoso.com\Namespace\Menus' -Force`.
2. Confirm the entry is a DFS link and not a junction or mount point. Only DFS
   tags are traversed; a `ReparsePointIgnored` Health Finding names any
   directory that was skipped.
3. Confirm the user has read access on the link target itself. Namespace
   permissions do not grant access behind the referral.

A directory the signed-in user may not list is skipped rather than aborting the
Launcher. `ContentPathInaccessible` names the directory, and
`DescriptionUnavailable` names a `description.txt` that could not be probed or
read; run `Test-LaunchTree` to see both.

## Launcher does not open from PowerShell

`Show-LaunchTree` opens an Entry Root without a Start Entry:

```powershell
Show-LaunchTree -EntryName 'LaunchTree Demo'
```

- `The term 'Show-LaunchTree' is not recognized` means the module is neither
  installed below a `$env:PSModulePath` directory nor imported. Import the
  installed or built `LaunchTree.psd1` manifest first, or dot-source
  `LaunchTree.ps1` when you use the single-file script.
- A prompt for `EntryId` means the default parameter set was selected. Use
  `-EntryName` until Reconciliation has written Generated State.
- `Show-LaunchTree requires an STA PowerShell host` means the session is MTA.
  Both consoles are STA by default, while a session started with `-MTA`, a
  background job, and a remote session are not.
- Add `-ConfigurationPath` when the machine configuration is not at
  `%ProgramData%\LaunchTree\LaunchTree.json`.
- `Entry Root '<name>' was not found` means the Entry Root is not an immediate
  directory of the Managed Root that is currently in effect. Confirm the
  effective root with `Get-LaunchTreeConfiguration`, then pass `-ManagedRoot`
  for content kept somewhere else.

## Launch Item failures

The Launcher asks Windows Shell to open the `.lnk` or HTTP(S) `.url` file
itself. It does not reconstruct arguments or working directories.

- Open the shortcut from File Explorer to compare native Shell behavior.
- Reject `.url` files that use any scheme other than HTTP or HTTPS.
- Run `Get-LaunchTreeDiagnostic -EventId 1201` for redacted failures.
- A shortcut may still trigger its own Windows elevation prompt.

## Icon or cache problems

The Launcher requests DPI-sized icons from Windows Shell. Extraction failures
fall back to a fixed icon without resizing the tile.

1. Close the Launcher.
2. Run `Clear-LaunchTreeCache` to discard every cached icon. Use
   `Remove-LaunchTree` only when full Generated State removal is intended.
3. Reopen the Launcher so the versioned cache can rebuild.
4. Use diagnostic event IDs `1401` and `1402` for extraction or cache failures.

A blank Launch Item icon is usually a missing icon target rather than a failed
extraction. Read the `IconFile` line of a `.url` in the system ANSI code page
and confirm the file exists; PowerShell 7 reads as UTF-8 by default and will
show a replacement character for a legitimate `ß` or `ä` that Windows wrote as a
single ANSI byte.

A cache key covers the shortcut's own path, length, and last-write time, not
the icon it points at. Deploying or renaming an icon target therefore cannot
invalidate the entry the shortcut already produced, and the stale icon survives
until `Cache.MaximumAgeDays` expires it. Run `Clear-LaunchTreeCache` after any
icon deployment.

## Policy blocks

The WPF Launcher requires FullLanguage. `-ExecutionPolicy Bypass` does not
override Constrained Language Mode, AppLocker, or Windows Defender Application
Control.

- Run `$ExecutionContext.SessionState.LanguageMode` in the selected Launcher
  Host.
- Allow the built module path or the single-file script path, and the selected
  `powershell.exe` or `pwsh.exe`.
- Use `Test-LaunchTree` to distinguish policy and platform findings.

## Event Log access

Elevated Reconciliation registers the dedicated log and grants Interactive
Users read/write without clear rights. If event writes fail:

- verify `LaunchTree` source uniqueness across classic logs
- inspect `CustomSD` under the dedicated Event Log registry key
- rerun elevated Reconciliation to execute the nonce write/read probe

The write/read probe launches a de-elevated process from the elevated session.
On an interactive elevated admin the linked standard-user token is only
`Identification` level, so the probe cannot start and Reconciliation reports the
`StandardUserEventAccessUnverified` Health Finding (event `1603`) instead of
failing. The dedicated log and Interactive Users access are still registered;
verify standard-user read/write manually from a non-elevated session.

Event records are diagnostic input, not security-audit evidence.

### Source is owned by another log

Reconciliation fails with `Event source 'LaunchTree' is owned by log
'Application'` when the source is already registered for a different classic
log. Windows binds a source name to exactly one log, so the dedicated log
cannot be created while the stray registration exists.

```powershell
[Diagnostics.EventLog]::LogNameFromSourceName('LaunchTree', '.')
```

When the reported log is not `LaunchTree` and no other product owns the name,
remove the stray source from an elevated session and rerun Reconciliation:

```powershell
[Diagnostics.EventLog]::DeleteEventSource('LaunchTree')
Update-LaunchTree -Confirm:$false
```

Deleting the source keeps the records already written to the other log. Set a
different `Diagnostics.SourceName` instead when another product owns the name.

## Single-file script problems

The generated `LaunchTree.ps1` behaves like the module once it is dot-sourced.

- `The term 'Update-LaunchTree' is not recognized` after running
  `.\LaunchTree.ps1` means the script was executed instead of dot-sourced. Use
  `. .\LaunchTree.ps1`, or pass `-Command Update`.
- `Command '<name>' does not support: <parameter>` means the parameter belongs
  to a different operation. The script exposes the union of every command's
  parameters, so it rejects the ones the selected `-Command` cannot use, such
  as `-Path` outside `-Command ExportSupportBundle`.
- Start Entries stop working after the script is moved or renamed, because they
  still point at the previous script path. Run `-Command Update -Force` again
  from the new location.
- Reconciliation through the module points Start Entries at the module, and
  Reconciliation through the script points them at the script. Use the delivery
  you intend to keep.
- Do not edit the script. It is generated from the module source by
  `tools\Build-LaunchTreeScript.ps1` and is overwritten by every build.

## Collect a Support Bundle

```powershell
Export-LaunchTreeSupportBundle -Path C:\Temp\LaunchTree-support.zip
```

The archive contains configuration summaries, health, and recent diagnostics.
It excludes Launch Item arguments and URL query strings. Review source paths
before sending the archive outside your organization: Managed Root, Personal
Root, preference, cache, and error paths are intentionally retained for support
and may contain a Windows user name.

## See also

- [Getting started](getting-started.md)
- [Deployment](deployment.md)
- [Open issues](open-issues.md)
