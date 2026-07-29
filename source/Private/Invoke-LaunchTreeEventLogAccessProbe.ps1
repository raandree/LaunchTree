function Invoke-LaunchTreeEventLogAccessProbe {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Diagnostic probe; writes only its own nonce verification event.'
    )]
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LogName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SourceName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Nonce,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int] $TimeoutSeconds = 15
    )

    # Returns a process exit code: 0 verified, 10 ran elevated, 11 not verified.
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    try {
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            return 10
        }
    } finally {
        $identity.Dispose()
    }

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        try {
            $message = "LaunchTree standard-user Event Log probe: $Nonce"
            [Diagnostics.EventLog]::WriteEntry(
                $SourceName,
                $message,
                [Diagnostics.EventLogEntryType]::Information,
                1602
            )
            $eventLog = [Diagnostics.EventLog]::new($LogName, '.')
            try {
                for ($index = $eventLog.Entries.Count - 1; $index -ge 0; $index--) {
                    $entry = $eventLog.Entries[$index]
                    if ($entry.Source -eq $SourceName -and
                        $entry.EventID -eq 1602 -and
                        $entry.Message -like "*$Nonce*") {
                        return 0
                    }
                }
            } finally {
                $eventLog.Dispose()
            }
        } catch {
            $probeError = $_
            Write-Debug -Message $probeError.Exception.Message
        }
        [Threading.Thread]::Sleep(100)
    }

    11
}
