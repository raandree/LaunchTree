function Test-LaunchTree {
    <#
        .SYNOPSIS
            Evaluates LaunchTree installation health.

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
            Test-LaunchTree

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
    $configuration = Get-LaunchTreeConfiguration @configurationParameters
    $findings = [System.Collections.Generic.List[object]]::new()
    foreach ($finding in @($configuration.HealthFindings)) {
        [void] $findings.Add($finding)
    }

    if (-not $PSBoundParameters.ContainsKey('ConfigurationPath')) {
        $ConfigurationPath = $configuration.ConfigurationPath
    }
    if (-not $PSBoundParameters.ContainsKey('GeneratedStatePath')) {
        $stateDirectory = Split-Path -Path $ConfigurationPath -Parent
        $GeneratedStatePath = Join-Path $stateDirectory 'LaunchTree.generated.json'
    }
    if (-not $PSBoundParameters.ContainsKey('StartMenuPath')) {
        $StartMenuPath = [Environment]::GetFolderPath(
            [Environment+SpecialFolder]::CommonPrograms
        )
    }

    if (-not $configuration.IsValid) {
        return [PSCustomObject] @{
            PSTypeName         = 'LaunchTree.HealthResult'
            Status             = 'Unhealthy'
            EntryRootCount     = 0
            LaunchObjectCount  = 0
            DiagnosticCount    = 0
            ConfigurationPath  = $ConfigurationPath
            GeneratedStatePath = $GeneratedStatePath
            StartMenuPath      = $StartMenuPath
            HealthFindings     = [object[]] $findings
        }
    }

    $snapshot = Get-LaunchTreeContentSnapshot -Configuration $configuration
    foreach ($finding in @($snapshot.HealthFindings)) {
        [void] $findings.Add($finding)
    }

    $generatedState = $null
    try {
        $generatedState = Import-LaunchTreeGeneratedState -LiteralPath $GeneratedStatePath
    } catch {
        $stateError = $_
        $findingParameters = @{
            Code     = 'GeneratedStateInvalid'
            Severity = 'Error'
            Message  = $stateError.Exception.Message
            Path     = $GeneratedStatePath
        }
        [void] $findings.Add((New-LaunchTreeHealthFinding @findingParameters))
    }

    if (-not $generatedState -and $snapshot.EntryRoots.Count -gt 0) {
        $findingParameters = @{
            Code     = 'GeneratedStateMissing'
            Severity = 'Warning'
            Message  = 'Entry Roots have not been reconciled into Generated State.'
            Path     = $GeneratedStatePath
        }
        [void] $findings.Add((New-LaunchTreeHealthFinding @findingParameters))
    } elseif ($generatedState) {
        foreach ($entry in @($generatedState.StartEntries)) {
            if (-not (Test-Path -LiteralPath $entry.ShortcutPath -PathType Leaf)) {
                $findingParameters = @{
                    Code     = 'OwnedStartEntryMissing'
                    Severity = 'Warning'
                    Message  = "Owned Start Entry '$($entry.Name)' is missing."
                    Path     = [string] $entry.ShortcutPath
                }
                [void] $findings.Add((New-LaunchTreeHealthFinding @findingParameters))
            }
        }
    }

    $diagnosticCount = 0
    if (-not $SkipEventLog) {
        $diagnostics = @(Get-LaunchTreeDiagnostic -LogName $configuration.Diagnostics.LogName)
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
        PSTypeName         = 'LaunchTree.HealthResult'
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