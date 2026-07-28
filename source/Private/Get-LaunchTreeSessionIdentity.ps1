function Get-LaunchTreeSessionIdentity {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    try {
        $sid = $identity.User.Value
    } finally {
        $identity.Dispose()
    }
    $sessionId = [Diagnostics.Process]::GetCurrentProcess().SessionId
    $suffix = '{0}.{1}' -f $sessionId, $sid

    [PSCustomObject] @{
        MutexName = 'Local\LaunchTree.{0}' -f $suffix
        PipeName  = 'LaunchTree.{0}' -f $suffix
    }
}