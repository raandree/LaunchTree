function Invoke-LaunchTreeLaunchItem {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath,

        [Parameter()]
        [AllowNull()]
        [PSCustomObject] $Configuration
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
    if ($extension -eq '.url') {
        $detail = Get-LaunchTreeLaunchItemDetail -LiteralPath $LiteralPath
        if (-not $detail.Succeeded) {
            throw [System.InvalidOperationException]::new($detail.Message)
        }
    }

    try {
        <#
            No -PassThru: Windows Shell returns no process handle when it hands
            the request to a running instance, an elevated one, or a registered
            protocol handler, and requesting one fails a launch that succeeded.
        #>
        Start-Process -FilePath $LiteralPath -ErrorAction Stop
        [PSCustomObject] @{
            PSTypeName  = 'LaunchTree.LaunchResult'
            Succeeded   = $true
            LiteralPath = $LiteralPath
            Message     = $null
        }
    } catch {
        $errorRecord = $_
        if ($Configuration) {
            $eventParameters = @{
                Configuration = $Configuration
                EventId       = 1201
                Level         = 'Error'
                Operation     = 'LaunchItem'
                Message       = $errorRecord.Exception.Message
                Path          = $LiteralPath
                ErrorCode     = $errorRecord.FullyQualifiedErrorId
            }
            $null = Write-LaunchTreeEvent @eventParameters
        }
        [PSCustomObject] @{
            PSTypeName  = 'LaunchTree.LaunchResult'
            Succeeded   = $false
            LiteralPath = $LiteralPath
            Message     = $errorRecord.Exception.Message
        }
    }
}