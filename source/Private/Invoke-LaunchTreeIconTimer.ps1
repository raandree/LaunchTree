function Invoke-LaunchTreeIconTimer {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Timer,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $IconJobs,

        [Parameter()]
        [AllowNull()]
        [string] $CapturePath
    )

    if ($CapturePath -or $IconJobs.Count -eq 0 -or $Timer.IsEnabled) {
        return $false
    }

    $Timer.Start()
    $true
}