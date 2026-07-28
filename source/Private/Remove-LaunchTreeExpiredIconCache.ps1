function Remove-LaunchTreeExpiredIconCache {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Private Launcher helper prunes only the bounded user icon cache.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $CachePath,

        [Parameter(Mandatory)]
        [ValidateRange(1, 1024)]
        [int] $MaximumSizeMB,

        [Parameter(Mandatory)]
        [ValidateRange(1, 365)]
        [int] $MaximumAgeDays
    )

    if (-not (Test-Path -LiteralPath $CachePath -PathType Container)) {
        return
    }

    $expiration = [DateTime]::UtcNow.AddDays(-$MaximumAgeDays)
    $files = @(Get-ChildItem -LiteralPath $CachePath -Filter '*.png' -File -Force)
    foreach ($file in $files) {
        if ($file.LastAccessTimeUtc -lt $expiration -or
            $file.LastWriteTimeUtc -lt $expiration) {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    $remainingFiles = @(
        Get-ChildItem -LiteralPath $CachePath -Filter '*.png' -File -Force |
            Sort-Object -Property LastAccessTimeUtc
    )
    $maximumBytes = [int64] $MaximumSizeMB * 1MB
    $totalBytes = ($remainingFiles | Measure-Object -Property Length -Sum).Sum
    foreach ($file in $remainingFiles) {
        if ($totalBytes -le $maximumBytes) {
            break
        }
        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
        $totalBytes -= $file.Length
    }
}