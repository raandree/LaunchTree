function Save-StartMenuFolderCachedIcon {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Private cache helper; the Launcher owns this bounded cache state.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Image,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath
    )

    Initialize-StartMenuFolderWpf
    $directory = Split-Path -Path $LiteralPath -Parent
    $null = New-Item -Path $directory -ItemType Directory -Force
    $temporaryPath = "$LiteralPath.$([guid]::NewGuid().ToString('N')).tmp"
    $encoder = [System.Windows.Media.Imaging.PngBitmapEncoder]::new()
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($Image))
    $stream = [IO.File]::Open($temporaryPath, [IO.FileMode]::CreateNew)
    try {
        $encoder.Save($stream)
    } finally {
        $stream.Dispose()
    }
    Move-Item -LiteralPath $temporaryPath -Destination $LiteralPath -Force
}