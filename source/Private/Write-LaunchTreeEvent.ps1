function Write-StartMenuFolderEvent {
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
        $module = $ExecutionContext.SessionState.Module
        $payload = [ordered] @{
            EventSchemaVersion = 1
            ModuleVersion      = $module.Version.ToString()
            Operation          = $Operation
            Message            = ConvertTo-StartMenuFolderRedactedText -InputObject $Message
            Path               = if ($Path) {
                ConvertTo-StartMenuFolderRedactedText -InputObject $Path
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
            SourceName = [string] $Configuration.Diagnostics.SourceName
            Message    = $payload | ConvertTo-Json -Depth 4 -Compress
            EntryType  = $entryType
            EventId    = $EventId
        }
        Invoke-StartMenuFolderEventLogWrite @writeParameters
        $true
    } catch {
        $eventError = $_
        Write-Verbose -Message (
            "Event $EventId could not be written: $($eventError.Exception.Message)"
        )
        $false
    }
}