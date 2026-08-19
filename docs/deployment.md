# Deployment

LaunchTree can be installed from PSGallery or copied as a built module.
The target does not need network access at runtime.

## Prerequisites

- Windows 10, Windows 11, or a validated Windows Server desktop environment
- Windows PowerShell 5.1 or native PowerShell 7
- FullLanguage mode for the Launcher process
- Administrator rights for event-log registration and machine-wide Start Entry
  Reconciliation

`-ExecutionPolicy Bypass` does not bypass Constrained Language Mode, AppLocker,
or Windows Defender Application Control. Allow the built module and selected
Launcher Host through the applicable policy.

## Build artifact

Run the Sampler build through the project detached launcher. The copyable module
is produced under:

```text
output\module\LaunchTree\<version>
```

Copy the complete version directory. It has no runtime PSGallery dependency.
The repository verifies this lifecycle with:

```powershell
pwsh -NoProfile -STA -File .\tools\Test-OfflineLifecycle.ps1
```

## Single-file script delivery

The same build also produces a self-contained script that needs no installed
module:

```text
output\LaunchTree.ps1
```

It is generated from the module source by `tools\Build-LaunchTreeScript.ps1`
and contains every private and public function, so it cannot drift from the
module. Do not edit it; edit the module source and rebuild. The module delivery
is unchanged and remains the recommended option.

Use the script when installing a module is impractical, for example a locked
workstation, a one-off recovery, or a scripted bootstrap. Copy it to a stable
machine-wide path first, because Reconciliation points its Start Entries at the
script file itself:

```text
C:\Program Files\LaunchTree\LaunchTree.ps1
```

Dot-source it to load the commands, then use them normally:

```powershell
. 'C:\Program Files\LaunchTree\LaunchTree.ps1'
Update-LaunchTree -Confirm:$false
Test-LaunchTree
```

Or run one operation without loading the commands:

```powershell
& 'C:\Program Files\LaunchTree\LaunchTree.ps1' -Command Update -Force
& 'C:\Program Files\LaunchTree\LaunchTree.ps1' -Command Show -EntryName 'LaunchTree Demo'
```

Moving or renaming the script after Reconciliation invalidates the owned Start
Entries. Run Reconciliation again from the new location, and allow the script
path through AppLocker or Windows Defender Application Control just as you would
the built module.

### Minimal single-file script

The build also produces a Launcher-only script for hosts that never reconcile:

```text
output\LaunchTree.Minimal.ps1
```

The generator derives it from the `Show-LaunchTree`, `Clear-LaunchTreeCache`,
and `New-LaunchTreeShortcut` call graphs, so it embeds only the functions those
calls need, and it then removes every comment and the blank lines they leave
behind. What remains is the code those calls execute. It accepts only the
parameters they need:

```powershell
& 'C:\Program Files\LaunchTree\LaunchTree.Minimal.ps1' -Command Show `
    -ManagedRoot 'D:\temp\' -EntryName 'Programs'
```

`-Command ClearCache` discards every cached icon, which a stale icon needs
because a cache key covers the shortcut rather than the icon it points at:

```powershell
& 'C:\Program Files\LaunchTree\LaunchTree.Minimal.ps1' -Command ClearCache
```

`-Command CreateShortcut` opens the wizard that writes a Windows shortcut to an
Entry Root, which the same switch reaches in the full script and the module
exposes as `New-LaunchTreeShortcut`:

```powershell
& 'C:\Program Files\LaunchTree\LaunchTree.Minimal.ps1' -Command CreateShortcut
```

Reconciliation, health checks, diagnostics, Support Bundle export, removal, and
the Event Log probe are not part of this delivery. Deploy the full script or the
module when a machine needs Start Entries or diagnostics.

The delivery also carries no Event Log writer and reads no JSON, which has three
consequences an operator must plan for:

- The machine configuration file is never read. `ManagedRoot` and `PersonalRoot`
  come from the command line, and every other setting stays at its default, so
  the Launcher Layout is always `TabbedList`.
- The user preference file is neither read nor written, so window position,
  size, and sort order are not remembered between sessions.
- Nothing is written to the Windows Event Log.

The replaced implementations live in `tools/MinimalVariant`. A unit test
compares the configuration object of both deliveries so the reduced one cannot
drift from the module contract.

## Executable delivery

The build compiles each single-file script into a self-contained executable:

```text
output\LaunchTree.exe
output\LaunchTree.Minimal.exe
```

`tools\Build-LaunchTreeExecutable.ps1` embeds the generated script as a resource
in a small .NET Framework host and compiles it with the C# compiler that ships
with Windows. No external module or SDK is involved, and the result needs
nothing installed on the target machine beyond .NET Framework 4, which is part
of Windows. Do not edit an executable; edit the module source and rebuild.

Each executable takes exactly the parameters of the script it was built from,
so every `-Command` example above works unchanged:

```powershell
& 'C:\Program Files\LaunchTree\LaunchTree.exe' -Command Update -Force
& 'C:\Program Files\LaunchTree\LaunchTree.exe' -Command Test
& 'C:\Program Files\LaunchTree\LaunchTree.Minimal.exe' -Command Show `
    -ManagedRoot 'D:\temp\' -EntryName 'Programs'
```

`LaunchTree.exe` is a console application. It hides a console window it created
for itself, so a Start Entry or a double click shows no console while a terminal
still receives the output and the exit code. `LaunchTree.Minimal.exe` is a
windows application that never creates one.

Reconciliation performed by an executable points its Start Entries at the
executable itself rather than at a Launcher Host, so `LauncherHost` in the
machine configuration has no effect on that delivery. Copy the file to a stable
machine-wide path before reconciling, and rerun Reconciliation after a move or
rename, exactly as for the script.

Two limitations distinguish this delivery from the script:

- The embedded script is not a file on disk, so under Windows Defender
  Application Control or AppLocker in enforcement it runs in Constrained
  Language Mode even where an allowed `.ps1` would not. Verify the delivery
  against your policy before choosing it.
- The executable is unsigned. Sign it yourself before distributing it outside
  the machine that built it, and allow its path just as you would the script.

## File-copy installation

1. Copy the built version directory to a module path, for example:

   ```text
   C:\Program Files\WindowsPowerShell\Modules\LaunchTree\<version>
   ```

2. Create the machine configuration from
   [the example](examples/LaunchTree.json).
3. Populate the Managed Root with one directory per Start Entry.
4. Run elevated Reconciliation:

   ```powershell
   Import-Module LaunchTree
   Update-LaunchTree -Confirm:$false
   Test-LaunchTree
   ```

The default diagnostic probe requires an elevated interactive administrator
token with a linked standard-user token. Deployment running as `SYSTEM` must
pre-provision and externally validate the dedicated Event Log ACL, then call
`Update-LaunchTree -SkipEventLogRegistration`. This exception remains a
release-evidence item under `OI-009`; do not treat the skip switch as proof of
standard-user Event Log access.

## Group Policy deployment

Use a computer startup script or software-distribution policy to copy the built
module and machine configuration. Run `Update-LaunchTree` after content
changes. Reconciliation is idempotent and transactionally restores prior
Generated State after failure.

Do not copy content into the Common Programs directory yourself. The module
owns only Start Entries listed in its ownership record and refuses collisions
with unowned shortcuts.

## Content layout

```text
C:\ProgramData\LaunchTree\LaunchTree\
├── Entertainment\
│   ├── description.txt
│   ├── Media tools\
│   │   └── Media Player.lnk
│   ├── Paint.lnk
│   └── Xbox.url
└── Work essentials\
    ├── Calculator.lnk
    └── Office\
        └── Word.lnk
```

`description.txt` is UTF-8 plain text. Launch Items are `.lnk` files or `.url`
files using HTTP or HTTPS.

## Update

Copy the new built version beside or over the deployed version, import it, and
run Reconciliation. Entry IDs remain stable for unchanged normalized Entry Root
paths. Generated State supports one previous major schema.

## Removal

Run elevated removal before deleting the module files:

```powershell
Remove-LaunchTree -Confirm:$false
```

Removal preserves machine configuration, the Managed Root, the Personal Root,
Menu Folders, and Launch Items.

## See also

- [Getting started](getting-started.md)
- [Configuration specification](specifications/configuration.md)
- [Troubleshooting](troubleshooting.md)
