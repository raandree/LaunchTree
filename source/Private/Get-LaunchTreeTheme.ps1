function Get-LaunchTreeTheme {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $isHighContrast = [System.Windows.SystemParameters]::HighContrast
    $appsUseLightTheme = 0
    try {
        $themeValue = Get-ItemPropertyValue -LiteralPath (
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        ) -Name 'AppsUseLightTheme' -ErrorAction Stop
        $appsUseLightTheme = [int] $themeValue
    } catch {
        $themeError = $_
        Write-Verbose -Message $themeError.Exception.Message
    }
    $isLight = -not $isHighContrast -and $appsUseLightTheme -eq 1

    if ($isHighContrast) {
        $windowBrush = [System.Windows.SystemColors]::WindowBrush
        $surfaceBrush = [System.Windows.SystemColors]::ControlBrush
        $foregroundBrush = [System.Windows.SystemColors]::WindowTextBrush
        $secondaryBrush = [System.Windows.SystemColors]::GrayTextBrush
        $accentBrush = [System.Windows.SystemColors]::HighlightBrush
        $borderBrush = [System.Windows.SystemColors]::ActiveBorderBrush
        $hoverColor = [System.Windows.SystemColors]::HighlightColor.ToString()
        $pressedColor = [System.Windows.SystemColors]::ControlDarkColor.ToString()
    } elseif ($isLight) {
        $windowBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#F3F3F3')
        $surfaceBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#FFFFFF')
        $foregroundBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#1A1A1A')
        $secondaryBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#5D5D5D')
        $accentBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#0067C0')
        $borderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#D3D3D3')
        $hoverColor = '#E8E8E8'
        $pressedColor = '#D8D8D8'
    } else {
        $windowBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#202020')
        $surfaceBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#2B2B2B')
        $foregroundBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#F5F5F5')
        $secondaryBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#B9B9B9')
        $accentBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#60CDFF')
        $borderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#454545')
        $hoverColor = '#383838'
        $pressedColor = '#474747'
    }
    if ($isHighContrast) {
        $hoverForegroundColor = [System.Windows.SystemColors]::HighlightTextColor.ToString()
        $pressedForegroundColor = [System.Windows.SystemColors]::ControlTextColor.ToString()
    } else {
        $hoverForegroundColor = $foregroundBrush.Color.ToString()
        $pressedForegroundColor = $foregroundBrush.Color.ToString()
    }

    [PSCustomObject] @{
        PSTypeName             = 'LaunchTree.Theme'
        Window                 = $windowBrush
        Surface                = $surfaceBrush
        Foreground             = $foregroundBrush
        Secondary              = $secondaryBrush
        Accent                 = $accentBrush
        Border                 = $borderBrush
        ForegroundColor        = $foregroundBrush.Color.ToString()
        SurfaceColor           = $surfaceBrush.Color.ToString()
        AccentColor            = $accentBrush.Color.ToString()
        BorderColor            = $borderBrush.Color.ToString()
        HoverColor             = $hoverColor
        PressedColor           = $pressedColor
        HoverForegroundColor   = $hoverForegroundColor
        PressedForegroundColor = $pressedForegroundColor
    }
}
