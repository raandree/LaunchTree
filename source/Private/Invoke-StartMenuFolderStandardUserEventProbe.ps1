function Invoke-StartMenuFolderStandardUserEventProbe {
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

    Initialize-StartMenuFolderUnelevatedProcess
    $moduleBase = $ExecutionContext.SessionState.Module.ModuleBase
    $probePath = Join-Path $moduleBase 'Scripts\Test-StartMenuFolderEventLogAccess.ps1'
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
        (ConvertTo-StartMenuFolderCommandLineArgument -Value $probePath)
        '-LogName'
        (ConvertTo-StartMenuFolderCommandLineArgument -Value $Configuration.Diagnostics.LogName)
        '-SourceName'
        (ConvertTo-StartMenuFolderCommandLineArgument -Value $Configuration.Diagnostics.SourceName)
        '-Nonce'
        (ConvertTo-StartMenuFolderCommandLineArgument -Value $nonce)
    )
    $exitCode = [StartMenuFolders.UnelevatedProcess]::Run(
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