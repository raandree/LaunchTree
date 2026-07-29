# Best-effort verification: returns a result rather than throwing so a launch
# limitation (for example an interactive elevated admin whose linked token is
# only Identification level) degrades to a Health Finding instead of aborting
# Reconciliation.
function Invoke-LaunchTreeStandardUserEventProbe {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject] $Configuration,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LauncherHostPath
    )

    $newResult = {
        param([bool] $Verified, [string] $Reason)
        [PSCustomObject] @{
            PSTypeName = 'LaunchTree.EventProbeResult'
            Verified   = $Verified
            Reason     = $Reason
        }
    }

    $runtime = Get-LaunchTreeRuntimeContext
    $moduleBase = $runtime.RootPath
    $probePath = $runtime.ProbePath
    if (-not (Test-Path -LiteralPath $probePath -PathType Leaf)) {
        return & $newResult $false "The standard-user probe script '$probePath' is missing."
    }

    $nonce = [guid]::NewGuid().ToString('N')
    $argumentParts = [System.Collections.Generic.List[string]]::new()
    foreach ($part in @(
            '-NoLogo'
            '-NoProfile'
            '-NonInteractive'
            '-ExecutionPolicy'
            'Bypass'
            '-File'
            (ConvertTo-LaunchTreeCommandLineArgument -Value $probePath)
        )) {
        [void] $argumentParts.Add($part)
    }
    if ($runtime.ProbeCommand) {
        [void] $argumentParts.Add('-Command')
        [void] $argumentParts.Add(
            (ConvertTo-LaunchTreeCommandLineArgument -Value $runtime.ProbeCommand)
        )
    }
    foreach ($part in @(
            '-LogName'
            (ConvertTo-LaunchTreeCommandLineArgument -Value $Configuration.Diagnostics.LogName)
            '-SourceName'
            (ConvertTo-LaunchTreeCommandLineArgument -Value $Configuration.Diagnostics.SourceName)
            '-Nonce'
            (ConvertTo-LaunchTreeCommandLineArgument -Value $nonce)
        )) {
        [void] $argumentParts.Add($part)
    }

    try {
        $exitCode = Invoke-LaunchTreeUnelevatedProcess `
            -ApplicationPath $LauncherHostPath `
            -Arguments ($argumentParts -join ' ') `
            -WorkingDirectory $moduleBase `
            -TimeoutMilliseconds 20000
    } catch {
        return & $newResult $false (
            'The de-elevated Event Log probe process could not be started from ' +
            "this session: $($_.Exception.Message)"
        )
    }

    if ($exitCode -eq 10) {
        return & $newResult $false (
            'The Event Log probe ran elevated, so standard-user access was not exercised.'
        )
    }
    if ($exitCode -ne 0) {
        return & $newResult $false (
            "The standard-user Event Log probe reported exit code $exitCode."
        )
    }
    & $newResult $true 'Standard-user Event Log read and write access verified.'
}