function Get-LaunchTreeLaunchItemDetail {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath
    )

    $extension = [IO.Path]::GetExtension($LiteralPath).ToLowerInvariant()
    if ($extension -eq '.url') {
        try {
            $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
            try {
                $lines = [IO.File]::ReadAllLines($LiteralPath, $strictUtf8)
            } catch [Text.DecoderFallbackException] {
                # Windows writes internet shortcuts in the system ANSI code page.
                $ansiCodePage = [Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage
                $lines = [IO.File]::ReadAllLines($LiteralPath, [Text.Encoding]::GetEncoding($ansiCodePage))
            }

            $urlLine = $lines | Where-Object { $_ -match '^URL=' } | Select-Object -First 1
            if (-not $urlLine) {
                throw [System.IO.InvalidDataException]::new('The internet shortcut has no URL field.')
            }

            $urlValue = $urlLine.Substring(4).Trim()
            $uri = $null
            if (-not [Uri]::TryCreate($urlValue, [UriKind]::Absolute, [ref] $uri) -or
                $uri.Scheme -notin @('http', 'https')) {
                return [PSCustomObject] @{
                    Succeeded   = $false
                    Description = $null
                    Code        = 'UrlSchemeRejected'
                    Message     = 'The internet shortcut must use HTTP or HTTPS.'
                }
            }

            return [PSCustomObject] @{
                Succeeded   = $true
                Description = $null
                Code        = $null
                Message     = $null
            }
        } catch {
            $errorRecord = $_
            return [PSCustomObject] @{
                Succeeded   = $false
                Description = $null
                Code        = 'LaunchItemInvalid'
                Message     = $errorRecord.Exception.Message
            }
        }
    }

    if ($extension -eq '.lnk') {
        $shell = $null
        $shortcut = $null
        try {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($LiteralPath)
            return [PSCustomObject] @{
                Succeeded   = $true
                Description = ([string] $shortcut.Description).Trim()
                Code        = $null
                Message     = $null
            }
        } catch {
            $errorRecord = $_
            return [PSCustomObject] @{
                Succeeded   = $false
                Description = $null
                Code        = 'LaunchItemInvalid'
                Message     = $errorRecord.Exception.Message
            }
        } finally {
            if ($shortcut) {
                [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut)
            }
            if ($shell) {
                [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
            }
        }
    }

    [PSCustomObject] @{
        Succeeded   = $false
        Description = $null
        Code        = 'LaunchItemTypeUnsupported'
        Message     = "The Launch Item extension '$extension' is unsupported."
    }
}