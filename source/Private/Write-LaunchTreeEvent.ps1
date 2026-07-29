function Write-LaunchTreeEvent {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject] $Configuration,

        [Parameter(Mandatory)]
        [ValidateRange(1000, 1699)]
        [int] $EventId,

        [Parameter(Mandatory)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string] $Level,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Operation,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Message,

        [Parameter()]
        [AllowNull()]
        [string] $Path,

        [Parameter()]
        [AllowNull()]
        [string] $ErrorCode
    )

    try {
        $runtime = Get-LaunchTreeRuntimeContext
        $payload = [ordered] @{
            EventSchemaVersion = 1
            ModuleVersion      = $runtime.Version
            Operation          = $Operation
            Message            = ConvertTo-LaunchTreeRedactedText -InputObject $Message
            Path               = if ($Path) {
                ConvertTo-LaunchTreeRedactedText -InputObject $Path
            } else {
                $null
            }
            ErrorCode          = $ErrorCode
        }
        $entryType = switch ($Level) {
            Information { [Diagnostics.EventLogEntryType]::Information }
            Warning { [Diagnostics.EventLogEntryType]::Warning }
            Error { [Diagnostics.EventLogEntryType]::Error }
        }
        $writeParameters = @{
            LogName    = [string] $Configuration.Diagnostics.LogName
            SourceName = [string] $Configuration.Diagnostics.SourceName
            Message    = $payload | ConvertTo-Json -Depth 4 -Compress
            EntryType  = $entryType
            EventId    = $EventId
        }
        Invoke-LaunchTreeEventLogWrite @writeParameters
        $true
    } catch {
        $eventError = $_
        Write-Verbose -Message (
            "Event $EventId could not be written: $($eventError.Exception.Message)"
        )
        $false
    }
}