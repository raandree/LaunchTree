# Getting started

This guide takes an administrator from a LaunchTree package or source
checkout to one working Start Entry. It uses the default paths and creates a
sample Notepad Launch Item that you can remove afterward.

## Prerequisites

- Windows 10, Windows 11, or a validated Windows Server desktop environment
- Windows PowerShell 5.1 or PowerShell 7 in FullLanguage mode
- An interactive administrator account with User Account Control enabled for
  installation and Reconciliation
- A standard-user session for testing the Launcher

LaunchTree does not need network access at runtime. Application control
policy must allow the installed module and the selected Launcher Host.

## Build or obtain the module

If you have a packaged version directory, continue with that directory. To
build the current checkout, run this command from the repository root in
PowerShell 7:

```powershell
pwsh -NoProfile -File .\build.ps1 -ResolveDependency -Tasks build
```

The versioned module is written below:

```text
output\module\LaunchTree\<version>
```

Open an elevated PowerShell session in the repository root and copy the latest
built version to the all-users module path:

```powershell
$builtModule = Get-ChildItem .\output\module\LaunchTree -Directory |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1

if (-not $builtModule) {
    throw 'Build LaunchTree before installing it.'
}

$modulePath = Join-Path $env:ProgramFiles (
    'WindowsPowerShell\Modules\LaunchTree\{0}' -f $builtModule.Name
)
New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
Copy-Item -Path (Join-Path $builtModule.FullName '*') `
    -Destination $modulePath -Recurse -Force
Import-Module (Join-Path $modulePath 'LaunchTree.psd1') -Force
```

For managed deployment or a package from another location, follow the
[deployment guide](deployment.md) instead of the copy example above.

## Run the setup script

The setup script writes a default machine configuration and creates one sample
Entry Root with Launch Items that exist on every Windows installation. Run it
from the elevated session in the repository root:

```powershell
.\tools\Initialize-QuickStart.ps1
```

It creates the machine configuration, a `Windows tools` Entry Root with File
Explorer, Notepad, Command Prompt, Windows PowerShell, Task Manager, and
Control Panel, and a `Web links` Menu Folder with two HTTP(S) Launch Items. It
keeps existing files unless you pass `-Force`, skips a Launch Item whose target
is missing on this machine, and never runs Reconciliation. Use
`-ConfigurationPath`, `-ManagedRoot`, `-PersonalRoot`, `-EntryName`, and
`-LauncherHost` to change the defaults.

Continue with [Inspect the effective configuration](#inspect-the-effective-configuration)
and skip the manual Entry Root section.

## Inspect the effective configuration

The machine configuration is optional. Without one, the module uses these
default locations:

```text
Machine configuration: C:\ProgramData\LaunchTree\LaunchTree.json
Managed Root:          C:\ProgramData\LaunchTree\LaunchTree
Personal Root:         %APPDATA%\LaunchTree\LaunchTree
```

Inspect the settings before creating content:

```powershell
$configuration = Get-LaunchTreeConfiguration
$configuration |
    Select-Object IsValid, ConfigurationPath, ManagedRoot, PersonalRoot,
        LauncherHost
$configuration.HealthFindings |
    Format-Table Severity, Code, Message, Path -AutoSize
```

`IsValid` must be `True`. To change the defaults, copy the
[machine configuration example](examples/LaunchTree.json) to the machine
configuration path, edit it, and run this inspection again.

## Create the first Entry Root manually

Skip this section when the setup script already created the sample content.

Every immediate directory under the Managed Root becomes one Start Entry.
Nested directories become Menu Folders. Run this block in the elevated session
to create a sample Entry Root and a valid Windows shortcut. It reads the
configuration itself, so it also works without the previous section:

```powershell
& {
    $ErrorActionPreference = 'Stop'

    $configuration = Get-LaunchTreeConfiguration
    $entryRoot = Join-Path $configuration.ManagedRoot 'Windows tools'
    $notepadPath = Join-Path $env:SystemRoot 'System32\notepad.exe'
    New-Item -ItemType Directory -Path $entryRoot -Force | Out-Null

    'Built-in Windows tools.' |
        Set-Content -LiteralPath (Join-Path $entryRoot 'description.txt') `
            -Encoding UTF8

    $shell = New-Object -ComObject WScript.Shell
    try {
        $shortcut = $shell.CreateShortcut((Join-Path $entryRoot 'Notepad.lnk'))
        $shortcut.TargetPath = $notepadPath
        $shortcut.IconLocation = "$notepadPath,0"
        $shortcut.Save()
        [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut)
    } finally {
        [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
    }

    "Created $entryRoot"
}
```

The block stops at the first error instead of reporting follow-up failures. An
access-denied error means the session is not elevated, and a missing
`Get-LaunchTreeConfiguration` command means the module is not installed.

You can also add nested directories, other `.lnk` files, and HTTP(S) `.url`
files. A UTF-8 `description.txt` supplies the Menu Folder tooltip.

## Reconcile Start Entries

Remain in the elevated interactive PowerShell session. Reconciliation creates
only module-owned Start Entries and verifies that standard users can write and
read the dedicated diagnostic Event Log:

```powershell
$result = Update-LaunchTree -Confirm:$false
$result | Format-List Succeeded, Added, Updated, Removed
```

Do not run this first-time Event Log validation as `SYSTEM`, and do not use
`-SkipEventLogRegistration` as a substitute for the standard-user access
probe. See the [deployment guide](deployment.md) for managed deployment rules.

## Verify health

Run the health check after Reconciliation:

```powershell
$health = Test-LaunchTree
$health |
    Format-List Status, EntryRootCount, LaunchObjectCount, DiagnosticCount
$health.HealthFindings |
    Format-Table Severity, Code, Message, Path -AutoSize
```

A clean first run reports `Healthy`, one Entry Root, and one Launch Item. If the
status is `Degraded` or `Unhealthy`, use the finding codes with the
[troubleshooting guide](troubleshooting.md).

## Open the Launcher

Return to a standard-user session, open Start, search for **Windows tools**, and
select the new Start Entry. The Launcher should show Notepad with its native
icon. Select Notepad to let Windows Shell open the shortcut.

Nested content and changes inside an existing Entry Root are read each time the
Launcher opens. Run Reconciliation again only after changing machine
configuration or adding, renaming, or removing an immediate Entry Root.

## Remove the sample Generated State

Run removal from an elevated interactive PowerShell session before deleting the
module files:

```powershell
Remove-LaunchTree -Confirm:$false
```

Removal deletes module-owned Start Entries, the ownership record, selected user
cache, and diagnostic registration. It preserves machine configuration, the
Managed Root, the Personal Root, Menu Folders, and Launch Items. Delete the
sample `Windows tools` directory separately when you no longer need it.

## See also

- [Deployment](deployment.md)
- [Troubleshooting](troubleshooting.md)
- [Configuration specification](specifications/configuration.md)
- [Open issues](open-issues.md)
