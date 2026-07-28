function Save-StartMenuFolderVisual {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Windows.Media.Visual] $Visual,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath
    )

    $bounds = [System.Windows.Media.VisualTreeHelper]::GetDescendantBounds($Visual)
    $dpi = [System.Windows.Media.VisualTreeHelper]::GetDpi($Visual)
    $pixelWidth = [Math]::Max(1, [int] [Math]::Ceiling($bounds.Width * $dpi.DpiScaleX))
    $pixelHeight = [Math]::Max(1, [int] [Math]::Ceiling($bounds.Height * $dpi.DpiScaleY))
    $bitmap = [System.Windows.Media.Imaging.RenderTargetBitmap]::new(
        $pixelWidth,
        $pixelHeight,
        $dpi.PixelsPerInchX,
        $dpi.PixelsPerInchY,
        [System.Windows.Media.PixelFormats]::Pbgra32
    )
    $bitmap.Render($Visual)

    $encoder = [System.Windows.Media.Imaging.PngBitmapEncoder]::new()
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $directory = Split-Path -Path $LiteralPath -Parent
    $null = New-Item -Path $directory -ItemType Directory -Force
    $stream = [IO.File]::Open($LiteralPath, [IO.FileMode]::Create)
    try {
        $encoder.Save($stream)
    } finally {
        $stream.Dispose()
    }
}