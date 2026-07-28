<#
    .SYNOPSIS
        Creates a default LaunchTree machine configuration and a sample Entry
        Root of Launch Items that exist on every Windows installation.

    .DESCRIPTION
        Writes the schema version 1 machine configuration when none exists,
        creates one Entry Root with Launch Items for built-in Windows programs
        and two HTTP(S) links, and reconciles the Start Entry so the Entry Root
        appears in the Windows Start menu. Existing files are preserved unless
        -Force is supplied, and Launch Items whose target is missing on this
        machine are skipped. Reconciliation requires an elevated interactive
        session; without one the script reports the skipped step and keeps the
        content it created.

    .PARAMETER ConfigurationPath
        Specifies the machine configuration JSON file to create.

    .PARAMETER ManagedRoot
        Specifies the Managed Root recorded in the machine configuration.

    .PARAMETER PersonalRoot
        Specifies the Personal Root recorded in the machine configuration.

    .PARAMETER EntryName
        Specifies the Entry Root directory name created below the Managed Root.

    .PARAMETER LauncherHost
        Specifies the Launcher Host recorded in the machine configuration.

    .PARAMETER SkipReconciliation
        Creates the configuration and content without creating a Start Entry.

    .PARAMETER Force
        Replaces an existing machine configuration and existing sample files.

    .EXAMPLE
        .\Initialize-QuickStart.ps1

        Creates the default configuration, the sample Entry Root, and the Start
        Entry when the session is elevated.

    .EXAMPLE
        .\Initialize-QuickStart.ps1 -EntryName 'Admin tools' -Force

        Replaces the configuration and refreshes the sample Entry Root.
#>
[CmdletBinding(SupportsShouldProcess)]
[OutputType([PSCustomObject])]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigurationPath = (
        Join-Path -Path $env:ProgramData -ChildPath 'LaunchTree\LaunchTree.json'
    ),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ManagedRoot = (
        Join-Path -Path $env:ProgramData -ChildPath 'LaunchTree\LaunchTree'
    ),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $PersonalRoot = '%APPDATA%\LaunchTree\LaunchTree',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $EntryName = 'Windows tools',

    [Parameter()]
    [ValidateSet('WindowsPowerShell', 'PowerShell7')]
    [string] $LauncherHost = 'WindowsPowerShell',

    [Parameter()]
    [switch] $SkipReconciliation,

    [Parameter()]
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

$configurationExists = Test-Path -LiteralPath $ConfigurationPath -PathType Leaf
$configurationAction = 'Kept'
if ($configurationExists -and -not $Force) {
    Write-Verbose (
        "Kept the existing machine configuration '$ConfigurationPath'. " +
        'Use -Force to replace it.'
    )
} elseif ($PSCmdlet.ShouldProcess($ConfigurationPath, 'Write machine configuration')) {
    $configurationDirectory = Split-Path -Path $ConfigurationPath -Parent
    $null = New-Item -Path $configurationDirectory -ItemType Directory -Force

    [ordered] @{
        SchemaVersion    = 1
        VendorName       = 'LaunchTree'
        ManagedRoot      = $ManagedRoot
        PersonalRoot     = $PersonalRoot
        MaximumDepth     = 5
        LauncherHost     = $LauncherHost
        DefaultSortOrder = 'NameAscending'
        CloseAfterLaunch = $true
        Cache            = [ordered] @{
            MaximumSizeMB  = 64
            MaximumAgeDays = 30
        }
        Diagnostics      = [ordered] @{
            LogName             = 'LaunchTree'
            SourceName          = 'LaunchTree'
            MaximumLogSizeMB    = 25
            TargetRetentionDays = 30
        }
    } | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath $ConfigurationPath -Encoding UTF8

    $configurationAction = if ($configurationExists) { 'Replaced' } else { 'Created' }
}

$entryRoot = Join-Path -Path $ManagedRoot -ChildPath $EntryName
$webFolder = Join-Path -Path $entryRoot -ChildPath 'Web links'
$systemRoot = $env:SystemRoot

$shortcutDefinitions = @(
    @{
        Name        = 'File Explorer'
        Target      = Join-Path -Path $systemRoot -ChildPath 'explorer.exe'
        Description = 'Browse files and folders.'
    }
    @{
        Name        = 'Notepad'
        Target      = Join-Path -Path $systemRoot -ChildPath 'System32\notepad.exe'
        Description = 'Write a quick note.'
    }
    @{
        Name        = 'Command Prompt'
        Target      = Join-Path -Path $systemRoot -ChildPath 'System32\cmd.exe'
        Description = 'Run classic command-line tools.'
    }
    @{
        Name        = 'Windows PowerShell'
        Target      = Join-Path -Path $systemRoot -ChildPath (
            'System32\WindowsPowerShell\v1.0\powershell.exe'
        )
        Description = 'Run Windows PowerShell.'
    }
    @{
        Name        = 'Task Manager'
        Target      = Join-Path -Path $systemRoot -ChildPath 'System32\Taskmgr.exe'
        Description = 'Inspect processes and performance.'
    }
    @{
        Name        = 'Control Panel'
        Target      = Join-Path -Path $systemRoot -ChildPath 'System32\control.exe'
        Description = 'Open classic Windows settings.'
    }
)

$urlDefinitions = @(
    @{
        Name = 'Microsoft Learn'
        Url  = 'https://learn.microsoft.com/windows/'
    }
    @{
        Name = 'Windows support'
        Url  = 'https://support.microsoft.com/windows'
    }
)

$createdItems = [Collections.Generic.List[string]]::new()
$keptItems = [Collections.Generic.List[string]]::new()
$skippedItems = [Collections.Generic.List[string]]::new()

if ($PSCmdlet.ShouldProcess($entryRoot, 'Create sample Entry Root')) {
    $null = New-Item -Path $entryRoot -ItemType Directory -Force
    $null = New-Item -Path $webFolder -ItemType Directory -Force

    $descriptions = @{
        $entryRoot = 'Built-in Windows tools.'
        $webFolder = 'Documentation and support links.'
    }
    foreach ($folder in $descriptions.Keys) {
        $descriptionPath = Join-Path -Path $folder -ChildPath 'description.txt'
        if ($Force -or -not (Test-Path -LiteralPath $descriptionPath -PathType Leaf)) {
            $descriptions[$folder] |
                Set-Content -LiteralPath $descriptionPath -Encoding UTF8
        }
    }

    $shell = New-Object -ComObject WScript.Shell
    try {
        foreach ($definition in $shortcutDefinitions) {
            $shortcutPath = Join-Path -Path $entryRoot -ChildPath (
                '{0}.lnk' -f $definition.Name
            )
            if (-not (Test-Path -LiteralPath $definition.Target -PathType Leaf)) {
                Write-Warning (
                    "Skipped '$($definition.Name)' because " +
                    "'$($definition.Target)' does not exist."
                )
                $skippedItems.Add($definition.Name)
                continue
            }
            if ((Test-Path -LiteralPath $shortcutPath -PathType Leaf) -and -not $Force) {
                $keptItems.Add($definition.Name)
                continue
            }

            $shortcut = $shell.CreateShortcut($shortcutPath)
            try {
                $shortcut.TargetPath = $definition.Target
                $shortcut.Description = $definition.Description
                $shortcut.IconLocation = '{0},0' -f $definition.Target
                $shortcut.Save()
            } finally {
                [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject(
                    $shortcut
                )
            }
            $createdItems.Add($definition.Name)
        }
    } finally {
        [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
    }

    foreach ($definition in $urlDefinitions) {
        $urlPath = Join-Path -Path $webFolder -ChildPath ('{0}.url' -f $definition.Name)
        if ((Test-Path -LiteralPath $urlPath -PathType Leaf) -and -not $Force) {
            $keptItems.Add($definition.Name)
            continue
        }

        @('[InternetShortcut]', "URL=$($definition.Url)") |
            Set-Content -LiteralPath $urlPath -Encoding ASCII
        $createdItems.Add($definition.Name)
    }
}

$startEntryAction = 'Skipped'
$startEntryCount = 0
if (-not $SkipReconciliation) {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isElevated = [Security.Principal.WindowsPrincipal]::new(
        $currentIdentity
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not (Get-Module -Name LaunchTree)) {
        $builtModuleRoot = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) `
            -ChildPath 'output\module\LaunchTree'
        $builtManifest = Get-ChildItem -Path $builtModuleRoot -Recurse `
            -Filter 'LaunchTree.psd1' -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        $installedModule = Get-Module -Name LaunchTree -ListAvailable |
            Select-Object -First 1

        if ($installedModule) {
            Import-Module -Name $installedModule -Force
        } elseif ($builtManifest) {
            Import-Module -Name $builtManifest.FullName -Force
        }
    }

    if (-not (Get-Module -Name LaunchTree)) {
        $startEntryAction = 'ModuleUnavailable'
        Write-Warning (
            'Skipped Reconciliation because the LaunchTree module is neither ' +
            'installed nor built. Import it and run Update-LaunchTree.'
        )
    } elseif (-not $isElevated) {
        $startEntryAction = 'NotElevated'
        Write-Warning (
            'Skipped Reconciliation because the session is not elevated. Run ' +
            'Update-LaunchTree from an elevated interactive session to create ' +
            'the Start Entry.'
        )
    } elseif ($PSCmdlet.ShouldProcess($ConfigurationPath, 'Reconcile Start Entries')) {
        try {
            $update = Update-LaunchTree -ConfigurationPath $ConfigurationPath `
                -Confirm:$false
            $startEntryAction = if ($update.Succeeded) { 'Reconciled' } else { 'Failed' }
            $startEntryCount = @($update.Added).Count + @($update.Updated).Count
        } catch {
            $reconciliationError = $_
            $startEntryAction = 'Failed'
            Write-Error -ErrorRecord $reconciliationError -ErrorAction Continue
        }
    }
}

[PSCustomObject] @{
    ConfigurationPath   = $ConfigurationPath
    ConfigurationAction = $configurationAction
    ManagedRoot         = $ManagedRoot
    EntryRoot           = $entryRoot
    CreatedLaunchItems  = $createdItems.ToArray()
    KeptLaunchItems     = $keptItems.ToArray()
    SkippedLaunchItems  = $skippedItems.ToArray()
    StartEntryAction    = $startEntryAction
    StartEntryCount     = $startEntryCount
}
