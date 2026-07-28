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
    if (-not (Test-StartMenuFolderInteractiveEventAccess -SecurityDescriptor $descriptor)) {
        throw [Security.SecurityException]::new(
            'The Event Log descriptor does not grant Interactive Users read/write without clear rights.'
        )
    }
    Set-ItemProperty -LiteralPath $eventLogKey -Name 'CustomSD' -Value $descriptor -Type String
    $maximumBytes = [int64] $Configuration.Diagnostics.MaximumLogSizeMB * 1MB
    Set-ItemProperty -LiteralPath $eventLogKey -Name 'MaxSize' -Value $maximumBytes -Type DWord
    Set-ItemProperty -LiteralPath $eventLogKey -Name 'Retention' -Value 0 -Type DWord

    $launcherHostPath = Get-StartMenuFolderLauncherHostPath -LauncherHost (
        $Configuration.LauncherHost
    )
    $probeParameters = @{
        Configuration    = $Configuration
        LauncherHostPath = $launcherHostPath
    }
    $null = Invoke-StartMenuFolderStandardUserEventProbe @probeParameters
}