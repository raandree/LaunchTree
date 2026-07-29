function Get-LaunchTreeRuntimeContext {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $standalonePath = Get-Variable -Name 'LaunchTreeStandalonePath' -Scope Script `
        -ValueOnly -ErrorAction SilentlyContinue

    if (-not $standalonePath) {
        $module = $ExecutionContext.SessionState.Module
        if (-not $module) {
            throw [System.InvalidOperationException]::new(
                'LaunchTree is running outside a module without a standalone script path.'
            )
        }

        return [PSCustomObject] @{
            PSTypeName      = 'LaunchTree.RuntimeContext'
            HostKind        = 'Module'
            RootPath        = $module.ModuleBase
            Version         = $module.Version.ToString()
            LauncherPath    = Join-Path -Path $module.ModuleBase -ChildPath (
                'Scripts\Start-LaunchTreeLauncher.ps1'
            )
            LauncherCommand = $null
            ProbePath       = Join-Path -Path $module.ModuleBase -ChildPath (
                'Scripts\Test-LaunchTreeEventLogAccess.ps1'
            )
            ProbeCommand    = $null
        }
    }

    $standaloneVersion = Get-Variable -Name 'LaunchTreeStandaloneVersion' -Scope Script `
        -ValueOnly -ErrorAction SilentlyContinue

    [PSCustomObject] @{
        PSTypeName      = 'LaunchTree.RuntimeContext'
        HostKind        = 'Script'
        RootPath        = Split-Path -Path $standalonePath -Parent
        Version         = if ($standaloneVersion) { $standaloneVersion } else { '0.0.0' }
        LauncherPath    = $standalonePath
        LauncherCommand = 'Show'
        ProbePath       = $standalonePath
        ProbeCommand    = 'EventLogProbe'
    }
}
