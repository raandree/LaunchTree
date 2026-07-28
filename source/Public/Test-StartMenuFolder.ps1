function Test-StartMenuFolder {
    <#
        .SYNOPSIS
            Evaluates StartMenuFolders installation health.

        .DESCRIPTION
            Validates effective configuration, source content, Generated State,
            owned Start Entries, and recent diagnostics. Returns one structured
            Healthy, Degraded, or Unhealthy result.

        .PARAMETER ConfigurationPath
            Specifies the machine configuration JSON file to evaluate.

        .PARAMETER GeneratedStatePath
            Overrides the Generated State ownership-record path.

        .PARAMETER StartMenuPath
            Overrides the machine-wide Start Programs directory.

        .PARAMETER SkipEventLog
            Skips Event Log checks for offline or pre-provisioning validation.

        .EXAMPLE
            Test-StartMenuFolder

            Returns a structured installation health summary.
    #>
    [CmdletBinding()]
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
        [string] $StartMenuPath,

        [Parameter()]
        [switch] $SkipEventLog
    )

    $configurationParameters = @{}
    if ($PSBoundParameters.ContainsKey('ConfigurationPath')) {
        $configurationParameters.ConfigurationPath = $ConfigurationPath
    }
    $configuration = Get-StartMenuFolderConfiguration @configurationParameters
    $findings = [System.Collections.Generic.List[object]]::new()
    foreach ($finding in @($configuration.HealthFindings)) {
        [void] $findings.Add($finding)
    }

    if (-not $PSBoundParameters.ContainsKey('ConfigurationPath')) {
        $ConfigurationPath = $configuration.ConfigurationPath
    }
    if (-not $PSBoundParameters.ContainsKey('GeneratedStatePath')) {
        $stateDirectory = Split-Path -Path $ConfigurationPath -Parent
        $GeneratedStatePath = Join-Path $stateDirectory 'StartMenuFolders.generated.json'
    }
    if (-not $PSBoundParameters.ContainsKey('StartMenuPath')) {
        $StartMenuPath = [Environment]::GetFolderPath(
            [Environment+SpecialFolder]::CommonPrograms
        )
    }

    $snapshot = Get-StartMenuFolderContentSnapshot -Configuration $configuration
    foreach ($finding in @($snapshot.HealthFindings)) {
        [void] $findings.Add($finding)
    }

    $generatedState = $null
    try {
        $generatedState = Import-StartMenuFolderGeneratedState -LiteralPath $GeneratedStatePath
    } catch {
        $stateError = $_
        $findingParameters = @{
            Code     = 'GeneratedStateInvalid'
            Severity = 'Error'
            Message  = $stateError.Exception.Message
            Path     = $GeneratedStatePath
        }
        [void] $findings.Add((New-StartMenuFolderHealthFinding @findingParameters))
    }

    if (-not $generatedState -and $snapshot.EntryRoots.Count -gt 0) {
        $findingParameters = @{
            Code     = 'GeneratedStateMissing'
            Severity = 'Warning'
            Message  = 'Entry Roots have not been reconciled into Generated State.'
            Path     = $GeneratedStatePath
        }
        [void] $findings.Add((New-StartMenuFolderHealthFinding @findingParameters))
    } elseif ($generatedState) {
        foreach ($entry in @($generatedState.StartEntries)) {
            if (-not (Test-Path -LiteralPath $entry.ShortcutPath -PathType Leaf)) {
                $findingParameters = @{
                    Code     = 'OwnedStartEntryMissing'
                    Severity = 'Warning'
                    Message  = "Owned Start Entry '$($entry.Name)' is missing."
                    Path     = [string] $entry.ShortcutPath
                }
                [void] $findings.Add((New-StartMenuFolderHealthFinding @findingParameters))
            }
        }
    }

    $diagnosticCount = 0
    if (-not $SkipEventLog) {
        $diagnostics = @(Get-StartMenuFolderDiagnostic -LogName $configuration.Diagnostics.LogName)
        $diagnosticCount = $diagnostics.Count
    }

    $status = if (@($findings | Where-Object Severity -eq 'Error').Count -gt 0) {
        'Unhealthy'
    } elseif (@($findings | Where-Object Severity -eq 'Warning').Count -gt 0) {
        'Degraded'
    } else {
        'Healthy'
    }

    [PSCustomObject] @{
        PSTypeName         = 'StartMenuFolders.HealthResult'
        Status             = $status
        EntryRootCount     = $snapshot.EntryRoots.Count
        LaunchObjectCount  = $snapshot.Objects.Count
        DiagnosticCount    = $diagnosticCount
        ConfigurationPath  = $ConfigurationPath
        GeneratedStatePath = $GeneratedStatePath
        StartMenuPath      = $StartMenuPath
        HealthFindings     = [object[]] $findings
    }
}