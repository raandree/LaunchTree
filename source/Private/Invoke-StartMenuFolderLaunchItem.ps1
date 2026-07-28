function Invoke-StartMenuFolderLaunchItem {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath
    )

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new(
            'The Launch Item does not exist.',
            $LiteralPath
        )
    }

    $extension = [IO.Path]::GetExtension($LiteralPath).ToLowerInvariant()
    if ($extension -notin @('.lnk', '.url')) {
        throw [System.InvalidOperationException]::new(
            "The Launch Item extension '$extension' is unsupported."
        )
    }

    try {
        $null = Start-Process -FilePath $LiteralPath -PassThru -ErrorAction Stop
        [PSCustomObject] @{
            PSTypeName  = 'StartMenuFolders.LaunchResult'
            Succeeded   = $true
            LiteralPath = $LiteralPath
            Message     = $null
        }
    } catch {
        $errorRecord = $_
        [PSCustomObject] @{
            PSTypeName  = 'StartMenuFolders.LaunchResult'
            Succeeded   = $false
            LiteralPath = $LiteralPath
            Message     = $errorRecord.Exception.Message
        }
    }
}