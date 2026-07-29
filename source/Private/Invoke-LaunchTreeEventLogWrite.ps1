function Invoke-LaunchTreeEventLogWrite {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Private Event Log core called by the structured diagnostic writer.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LogName,

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

    # WriteEntry registers an unknown source in the Application log when the
    # caller is elevated, which permanently blocks dedicated-log registration.
    $registeredLog = ''
    try {
        $registeredLog = [Diagnostics.EventLog]::LogNameFromSourceName(
            $SourceName,
            '.'
        )
    } catch {
        $lookupError = $_
        throw [System.InvalidOperationException]::new(
            "Event source '$SourceName' is not registered for log '$LogName': " +
            $lookupError.Exception.Message
        )
    }
    if ($registeredLog -ne $LogName) {
        throw [System.InvalidOperationException]::new(
            "Event source '$SourceName' is not registered for log '$LogName'. " +
            'Run elevated Reconciliation to register diagnostics.'
        )
    }

    [Diagnostics.EventLog]::WriteEntry(
        $SourceName,
        $Message,
        $EntryType,
        $EventId
    )
}