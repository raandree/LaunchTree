function Get-LaunchTreeDiagnostic {
    <#
        .SYNOPSIS
            Reads structured LaunchTree diagnostic events.

        .DESCRIPTION
            Reads the dedicated Windows Event Log and returns redacted,
            automation-friendly event objects. URL query strings and successful
            Launch Item activity are never returned.

        .PARAMETER LogName
            Specifies the Windows Event Log to query.

        .PARAMETER Since
            Specifies the earliest event creation time to include.

        .PARAMETER EventId
            Filters results to one or more stable event IDs.

        .PARAMETER Level
            Filters results to one or more event level display names.

        .EXAMPLE
            Get-LaunchTreeDiagnostic -Since (Get-Date).AddDays(-1)

            Returns redacted diagnostic events from the last day.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $LogName = 'LaunchTree',

        [Parameter()]
        [datetime] $Since = [DateTime]::Now.AddDays(-30),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int[]] $EventId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]] $Level
    )

    $filter = @{
        LogName   = $LogName
        StartTime = $Since
    }
    if ($EventId) {
        $filter.Id = $EventId
    }

    try {
        $events = @(Get-WinEvent -FilterHashtable $filter -ErrorAction Stop)
    } catch [System.Exception] {
        $errorRecord = $_
        Write-Verbose -Message $errorRecord.Exception.Message
        return
    }

    foreach ($eventRecord in $events) {
        $levelName = [string] $eventRecord.LevelDisplayName
        if ($Level -and $levelName -notin $Level) {
            continue
        }

        [PSCustomObject] @{
            PSTypeName   = 'LaunchTree.DiagnosticEvent'
            EventId      = [int] $eventRecord.Id
            Level        = $levelName
            TimeCreated  = $eventRecord.TimeCreated
            Message      = ConvertTo-LaunchTreeRedactedText -InputObject (
                [string] $eventRecord.Message
            )
            ProviderName = [string] $eventRecord.ProviderName
            LogName      = [string] $eventRecord.LogName
        }
    }
}