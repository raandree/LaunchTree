function Remove-LaunchTree {
    <#
        .SYNOPSIS
            Removes module-owned Generated State.

        .DESCRIPTION
            Removes owned Start Entries, the ownership record, the selected
            user cache, and optionally the dedicated event registration while
            preserving machine configuration and all Managed and Personal
            source content.

        .PARAMETER ConfigurationPath
            Specifies the machine configuration JSON file to preserve and read.

        .PARAMETER GeneratedStatePath
            Overrides the Generated State ownership-record path.

        .PARAMETER CachePath
            Overrides the per-user cache path to remove.

        .PARAMETER SkipEventLog
            Preserves event registration, such as during non-elevated cleanup.

        .EXAMPLE
            Remove-LaunchTree -Confirm:$false

            Removes module-owned Generated State while preserving source data.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $GeneratedStatePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $CachePath,

        [Parameter()]
        [switch] $SkipEventLog
    )

    $configurationParameters = @{}
    if ($PSBoundParameters.ContainsKey('ConfigurationPath')) {
        $configurationParameters.ConfigurationPath = $ConfigurationPath
    }
    $configuration = Get-LaunchTreeConfiguration @configurationParameters
    if (-not $PSBoundParameters.ContainsKey('ConfigurationPath')) {
        $ConfigurationPath = $configuration.ConfigurationPath
    }
    if (-not $PSBoundParameters.ContainsKey('GeneratedStatePath')) {
        $stateDirectory = Split-Path -Path $ConfigurationPath -Parent
        $GeneratedStatePath = Join-Path $stateDirectory 'LaunchTree.generated.json'
    }
    if (-not $PSBoundParameters.ContainsKey('CachePath')) {
        $CachePath = $configuration.Cache.Path
    }

    $state = Import-LaunchTreeGeneratedState -LiteralPath $GeneratedStatePath
    $ownedPaths = @($state.StartEntries | Where-Object { $_ } | Select-Object -ExpandProperty ShortcutPath)
    if (-not $PSCmdlet.ShouldProcess('LaunchTree Generated State', 'Remove')) {
        return
    }

    $removed = [System.Collections.Generic.List[string]]::new()
    foreach ($ownedPath in $ownedPaths) {
        if (Test-Path -LiteralPath $ownedPath -PathType Leaf) {
            Remove-Item -LiteralPath $ownedPath -Force -ErrorAction Stop
            [void] $removed.Add([string] $ownedPath)
        }
    }
    if (Test-Path -LiteralPath $GeneratedStatePath -PathType Leaf) {
        Remove-Item -LiteralPath $GeneratedStatePath -Force -ErrorAction Stop
        [void] $removed.Add($GeneratedStatePath)
    }
    if (Test-Path -LiteralPath $CachePath -PathType Container) {
        Remove-Item -LiteralPath $CachePath -Recurse -Force -ErrorAction Stop
        [void] $removed.Add($CachePath)
    }

    if (-not $SkipEventLog) {
        if (-not (Test-LaunchTreeAdministrator)) {
            throw [System.UnauthorizedAccessException]::new(
                'Event Log removal requires administrator rights.'
            )
        }
        $sourceName = [string] $configuration.Diagnostics.SourceName
        $logName = [string] $configuration.Diagnostics.LogName
        if ([Diagnostics.EventLog]::SourceExists($sourceName) -and
            [Diagnostics.EventLog]::LogNameFromSourceName($sourceName, '.') -eq $logName) {
            [Diagnostics.EventLog]::DeleteEventSource($sourceName)
        }
        if ([Diagnostics.EventLog]::Exists($logName)) {
            [Diagnostics.EventLog]::Delete($logName)
        }
    }

    [PSCustomObject] @{
        PSTypeName = 'LaunchTree.RemovalResult'
        Succeeded  = $true
        Removed    = [string[]] $removed
    }
}