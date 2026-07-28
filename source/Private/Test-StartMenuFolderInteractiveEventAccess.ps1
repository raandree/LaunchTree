function Test-StartMenuFolderInteractiveEventAccess {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SecurityDescriptor
    )

    try {
        $descriptor = [Security.AccessControl.RawSecurityDescriptor]::new(
            $SecurityDescriptor
        )
        $interactiveSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-4')
        $allowedMask = 0
        $deniedMask = 0
        foreach ($accessControlEntry in $descriptor.DiscretionaryAcl) {
            if (-not ($accessControlEntry -is [Security.AccessControl.CommonAce]) -or
                -not $accessControlEntry.SecurityIdentifier.Equals($interactiveSid)) {
                continue
            }
            if ($accessControlEntry.AceQualifier -eq
                [Security.AccessControl.AceQualifier]::AccessAllowed) {
                $allowedMask = $allowedMask -bor $accessControlEntry.AccessMask
            } elseif ($accessControlEntry.AceQualifier -eq
                [Security.AccessControl.AceQualifier]::AccessDenied) {
                $deniedMask = $deniedMask -bor $accessControlEntry.AccessMask
            }
        }

        ($allowedMask -band 0x3) -eq 0x3 -and
            ($allowedMask -band 0x4) -eq 0 -and
            ($deniedMask -band 0x3) -eq 0
    } catch {
        $descriptorError = $_
        Write-Verbose -Message $descriptorError.Exception.Message
        $false
    }
}