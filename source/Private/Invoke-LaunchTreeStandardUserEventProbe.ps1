function Invoke-LaunchTreeStandardUserEventProbe {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject] $Configuration,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LauncherHostPath
    )

    Initialize-LaunchTreeUnelevatedProcess
    $moduleBase = $ExecutionContext.SessionState.Module.ModuleBase
    $probePath = Join-Path $moduleBase 'Scripts\Test-LaunchTreeEventLogAccess.ps1'
    if (-not (Test-Path -LiteralPath $probePath -PathType Leaf)) {
        throw [IO.FileNotFoundException]::new('The standard-user probe script is missing.', $probePath)
    }

    $nonce = [guid]::NewGuid().ToString('N')
    $argumentParts = @(
        '-NoLogo'
        '-NoProfile'
        '-NonInteractive'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        (ConvertTo-LaunchTreeCommandLineArgument -Value $probePath)
        '-LogName'
        (ConvertTo-LaunchTreeCommandLineArgument -Value $Configuration.Diagnostics.LogName)
        '-SourceName'
        (ConvertTo-LaunchTreeCommandLineArgument -Value $Configuration.Diagnostics.SourceName)
        '-Nonce'
        (ConvertTo-LaunchTreeCommandLineArgument -Value $nonce)
    )
    $exitCode = [LaunchTree.UnelevatedProcess]::Run(
        $LauncherHostPath,
        ($argumentParts -join ' '),
        $moduleBase,
        20000
    )
    if ($exitCode -ne 0) {
        throw [InvalidOperationException]::new(
            "The standard-user Event Log probe failed with exit code $exitCode."
        )
    }
    $true
}