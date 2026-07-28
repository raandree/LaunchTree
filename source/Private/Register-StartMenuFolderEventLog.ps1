function Register-StartMenuFolderEventLog {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Private registration helper; public Reconciliation owns ShouldProcess.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject] $Configuration
    )

    if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') {
        throw [System.PlatformNotSupportedException]::new(
            'Windows Event Log registration is supported only on Windows.'
        )
    }
    if (-not (Test-StartMenuFolderAdministrator)) {
        throw [System.UnauthorizedAccessException]::new(
            'Reconciliation must run as an administrator to register diagnostics.'
        )
    }

    $logName = [string] $Configuration.Diagnostics.LogName
    $sourceName = [string] $Configuration.Diagnostics.SourceName
    if ([string]::IsNullOrWhiteSpace($logName) -or
        [string]::IsNullOrWhiteSpace($sourceName)) {
        throw [System.IO.InvalidDataException]::new(
            'Diagnostics LogName and SourceName must not be empty.'
        )
    }

    if ([Diagnostics.EventLog]::SourceExists($sourceName)) {
        $registeredLog = [Diagnostics.EventLog]::LogNameFromSourceName($sourceName, '.')
        if ($registeredLog -ne $logName) {
            throw [System.InvalidOperationException]::new(
                "Event source '$sourceName' is owned by log '$registeredLog'."
            )
        }
    } else {
        $creationData = [Diagnostics.EventSourceCreationData]::new($sourceName, $logName)
        [Diagnostics.EventLog]::CreateEventSource($creationData)
    }

    $eventLogKey = Join-Path -Path (
        'HKLM:\SYSTEM\CurrentControlSet\Services\EventLog'
    ) -ChildPath $logName
    if (-not (Test-Path -LiteralPath $eventLogKey -PathType Container)) {
        throw [System.InvalidOperationException]::new(
            "Event log registration key '$eventLogKey' was not created."
        )
    }

    $descriptor = Get-StartMenuFolderEventLogSecurityDescriptor
    Set-ItemProperty -LiteralPath $eventLogKey -Name 'CustomSD' -Value $descriptor -Type String
    $maximumBytes = [int64] $Configuration.Diagnostics.MaximumLogSizeMB * 1MB
    Set-ItemProperty -LiteralPath $eventLogKey -Name 'MaxSize' -Value $maximumBytes -Type DWord
    Set-ItemProperty -LiteralPath $eventLogKey -Name 'Retention' -Value 0 -Type DWord

    $nonce = [guid]::NewGuid().ToString('N')
    $message = "StartMenuFolders event log access probe: $nonce"
    [Diagnostics.EventLog]::WriteEntry(
        $sourceName,
        $message,
        [Diagnostics.EventLogEntryType]::Information,
        1602
    )

    $eventLog = [Diagnostics.EventLog]::new($logName, '.')
    try {
        $probeFound = $false
        for ($index = $eventLog.Entries.Count - 1; $index -ge 0; $index--) {
            $entry = $eventLog.Entries[$index]
            if ($entry.Source -eq $sourceName -and
                $entry.EventID -eq 1602 -and
                $entry.Message -like "*$nonce*") {
                $probeFound = $true
                break
            }
        }
        if (-not $probeFound) {
            throw [System.InvalidOperationException]::new(
                'The event log write/read probe could not be verified.'
            )
        }
    } finally {
        $eventLog.Dispose()
    }
}