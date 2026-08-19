function Get-LaunchTreeDescription {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath
    )

    # An unreadable path must reach the caller as a Health Finding, not as a
    # non-terminating Test-Path error on the host error stream.
    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf -ErrorAction Stop)) {
        return $null
    }

    $descriptionFile = Get-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop
    if ($descriptionFile.Length -gt 64KB) {
        throw [IO.InvalidDataException]::new(
            'Menu Folder description metadata must not exceed 64 KB.'
        )
    }

    $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
    $bytes = [IO.File]::ReadAllBytes($LiteralPath)
    $strictUtf8.GetString($bytes).Trim()
}