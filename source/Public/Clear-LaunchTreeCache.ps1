function Clear-LaunchTreeCache {
    <#
        .SYNOPSIS
            Discards every cached icon in the user cache namespace.

        .DESCRIPTION
            Removes the cached icons the Launcher wrote for Launch Items and
            reports how much was reclaimed. A cache key identifies only the
            shortcut, so repairing or deploying an icon target cannot invalidate
            the entry the shortcut already produced; clearing forces the next
            Launcher run to extract every icon again. The cache namespace
            directory, source content, Generated State, machine configuration,
            and user preferences are preserved.

        .PARAMETER ConfigurationPath
            Specifies the machine configuration JSON file used to resolve the
            cache namespace.

        .PARAMETER CachePath
            Overrides the per-user cache namespace to clear.

        .EXAMPLE
            Clear-LaunchTreeCache

            Discards every cached icon in the configured cache namespace.

        .EXAMPLE
            Clear-LaunchTreeCache -WhatIf

            Reports the cache namespace that would be cleared without removing
            anything.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $CachePath
    )

    if (-not $PSBoundParameters.ContainsKey('CachePath')) {
        $configurationParameters = @{}
        if ($PSBoundParameters.ContainsKey('ConfigurationPath')) {
            $configurationParameters.ConfigurationPath = $ConfigurationPath
        }
        $CachePath = (Get-LaunchTreeConfiguration @configurationParameters).Cache.Path
    }

    if (-not $PSCmdlet.ShouldProcess($CachePath, 'Clear cached icons')) {
        return
    }

    $removed = 0
    $reclaimedBytes = [int64] 0
    if (Test-Path -LiteralPath $CachePath -PathType Container) {
        foreach ($file in @(Get-ChildItem -LiteralPath $CachePath -Filter '*.png' -File -Force)) {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            $removed++
            $reclaimedBytes += $file.Length
        }
    }

    [PSCustomObject] @{
        PSTypeName     = 'LaunchTree.CacheClearResult'
        Succeeded      = $true
        Path           = $CachePath
        RemovedCount   = $removed
        ReclaimedBytes = $reclaimedBytes
    }
}
