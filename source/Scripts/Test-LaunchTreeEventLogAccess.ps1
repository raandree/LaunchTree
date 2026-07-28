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
    [string] $Nonce
)

$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
try {
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        exit 10
    }
} finally {
    $identity.Dispose()
}

$deadline = [DateTime]::UtcNow.AddSeconds(15)
while ([DateTime]::UtcNow -lt $deadline) {
    try {
        $message = "StartMenuFolders standard-user Event Log probe: $Nonce"
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
                    exit 0
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

exit 11