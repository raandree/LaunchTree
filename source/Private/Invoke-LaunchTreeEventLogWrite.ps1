function Invoke-StartMenuFolderEventLogWrite {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Private Event Log core called by the structured diagnostic writer.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SourceName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Message,

        [Parameter(Mandatory)]
        [Diagnostics.EventLogEntryType] $EntryType,

        [Parameter(Mandatory)]
        [ValidateRange(1000, 1699)]
        [int] $EventId
    )

    [Diagnostics.EventLog]::WriteEntry(
        $SourceName,
        $Message,
        $EntryType,
        $EventId
    )
}