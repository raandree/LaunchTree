function Get-StartMenuFolderIconCachePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $CachePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SourcePath,

        [Parameter(Mandatory)]
        [ValidateRange(16, 512)]
        [int] $PixelSize
    )

    $sourceItem = Get-Item -LiteralPath $SourcePath -Force -ErrorAction Stop
    $key = '{0}|{1}|{2}|{3}|v1' -f (
        [IO.Path]::GetFullPath($sourceItem.FullName).ToUpperInvariant()
    ), $sourceItem.Length, $sourceItem.LastWriteTimeUtc.Ticks, $PixelSize
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($key)
        $hash = ([BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace('-', '')
    } finally {
        $algorithm.Dispose()
    }

    Join-Path -Path $CachePath -ChildPath "$hash.png"
}