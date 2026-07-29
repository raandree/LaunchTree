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
