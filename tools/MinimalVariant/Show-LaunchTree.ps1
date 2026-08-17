function Show-LaunchTree {
    <#
        .SYNOPSIS
            Opens a recursive LaunchTree WPF Launcher by Entry Root name.

        .DESCRIPTION
            Replaces the module command in the Minimal single-file script. The
            Entry ID parameter set resolves an opaque ID through Generated
            State, which is JSON, so the Minimal delivery keeps only the Entry
            Root name path. Single-instance activation belongs to the Entry ID
            path and is omitted with it.

        .PARAMETER EntryName
            Specifies the Entry Root to open.

        .PARAMETER ConfigurationPath
            Accepted for signature compatibility. The file is never read.

        .PARAMETER ManagedRoot
            Overrides the Managed Root that supplies Entry Roots.

        .PARAMETER PersonalRoot
            Overrides the Personal Root merged into matching Entry Roots.

        .PARAMETER CapturePath
            Renders the Launcher to a PNG and self-closes for visual validation.

        .EXAMPLE
            Show-LaunchTree -EntryName 'Programs' -ManagedRoot D:\temp

            Opens an Entry Root below a Managed Root supplied for this call.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $EntryName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ManagedRoot,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $PersonalRoot,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $CapturePath
    )

    if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne
        [Threading.ApartmentState]::STA) {
        throw [System.Threading.ThreadStateException]::new(
            'Show-LaunchTree requires an STA PowerShell host.'
        )
    }
    $startupStopwatch = [Diagnostics.Stopwatch]::StartNew()

    $configurationParameters = @{}
    foreach ($parameterName in 'ConfigurationPath', 'ManagedRoot', 'PersonalRoot') {
        if ($PSBoundParameters.ContainsKey($parameterName)) {
            $configurationParameters[$parameterName] = $PSBoundParameters[$parameterName]
        }
    }
    $configuration = Get-LaunchTreeConfiguration @configurationParameters

    $snapshot = Get-LaunchTreeContentSnapshot -Configuration $configuration
    if (@($snapshot.HealthFindings | Where-Object Severity -eq 'Error').Count -gt 0) {
        throw [System.InvalidOperationException]::new(
            'The Launcher cannot open because the Managed Root is unhealthy.'
        )
    }
    if ($snapshot.EntryRoots.Name -notcontains $EntryName) {
        throw [System.Collections.Generic.KeyNotFoundException]::new(
            "Entry Root '$EntryName' was not found."
        )
    }

    $windowParameters = @{
        Configuration      = $configuration
        Snapshot           = $snapshot
        EntryName          = $EntryName
        CapturePath        = $CapturePath
        ActivationServer   = $null
        GeneratedStatePath = $null
        StartupStopwatch   = $startupStopwatch
    }
    Show-LaunchTreeWindow @windowParameters
}
