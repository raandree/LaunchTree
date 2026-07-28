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
2. Remove the configured cache directory, or run `Remove-LaunchTree` only
   when full Generated State removal is intended.
3. Reopen the Launcher so the versioned cache can rebuild.
4. Use diagnostic event IDs `1401` and `1402` for extraction or cache failures.

## Policy blocks

The WPF Launcher requires FullLanguage. `-ExecutionPolicy Bypass` does not
override Constrained Language Mode, AppLocker, or Windows Defender Application
Control.

- Run `$ExecutionContext.SessionState.LanguageMode` in the selected Launcher
  Host.
- Allow the built module path and the selected `powershell.exe` or `pwsh.exe`.
- Use `Test-LaunchTree` to distinguish policy and platform findings.

## Event Log access

Elevated Reconciliation registers the dedicated log and grants Interactive
Users read/write without clear rights. If event writes fail:

- verify `LaunchTree` source uniqueness across classic logs
- inspect `CustomSD` under the dedicated Event Log registry key
- rerun elevated Reconciliation to execute the nonce write/read probe

Event records are diagnostic input, not security-audit evidence.

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
