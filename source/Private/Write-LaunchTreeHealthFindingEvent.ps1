function Write-StartMenuFolderHealthFindingEvent {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject] $Configuration,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject] $HealthFinding
    )

    $eventIdByCode = @{
        ManagedRootInaccessible = 1002
        ContentPathInaccessible = 1101
        LaunchItemInvalid       = 1101
        MaximumDepthExceeded    = 1102
        DescriptionUnavailable  = 1103
        UrlSchemeRejected       = 1104
        HostPathLimitExceeded   = 1105
        ReparsePointIgnored     = 1106
    }
    if (-not $eventIdByCode.ContainsKey([string] $HealthFinding.Code)) {
        return $false
    }

    $eventParameters = @{
        Configuration = $Configuration
        EventId       = $eventIdByCode[[string] $HealthFinding.Code]
        Level         = if ($HealthFinding.Severity -eq 'Error') { 'Error' } else { 'Warning' }
        Operation     = 'ContentDiscovery'
        Message       = [string] $HealthFinding.Message
        Path          = [string] $HealthFinding.Path
        ErrorCode     = [string] $HealthFinding.Code
    }
    Write-StartMenuFolderEvent @eventParameters
}