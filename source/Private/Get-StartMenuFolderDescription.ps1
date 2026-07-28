function Get-StartMenuFolderDescription {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath
    )

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        return $null
    }

    $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
    $bytes = [IO.File]::ReadAllBytes($LiteralPath)
    $strictUtf8.GetString($bytes).Trim()
}