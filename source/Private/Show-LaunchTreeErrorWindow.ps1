function Show-StartMenuFolderErrorWindow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Title,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Message,

        [Parameter()]
        [AllowNull()]
        [string] $CapturePath
    )

    Initialize-StartMenuFolderWpf
    $window = [System.Windows.Window]::new()
    $window.Title = $Title
    $window.Width = 560
    $window.Height = 420
    $window.MinWidth = 520
    $window.MinHeight = 420
    $window.WindowStyle = [System.Windows.WindowStyle]::None
    $window.ResizeMode = [System.Windows.ResizeMode]::CanResizeWithGrip
    $window.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#202020')
    $window.Foreground = [System.Windows.Media.Brushes]::White
    $window.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe UI Variable Text')

    $border = [System.Windows.Controls.Border]::new()
    $border.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#454545')
    $border.BorderThickness = [System.Windows.Thickness]::new(1)
    $border.CornerRadius = [System.Windows.CornerRadius]::new(8)
    $border.Padding = [System.Windows.Thickness]::new(32)
    $window.Content = $border

    $stack = [System.Windows.Controls.StackPanel]::new()
    $stack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $icon = [System.Windows.Controls.TextBlock]::new()
    $icon.Text = [char] 0xE7BA
    $icon.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe Fluent Icons')
    $icon.FontSize = 42
    $icon.Foreground = [System.Windows.Media.Brushes]::IndianRed
    $icon.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $heading = [System.Windows.Controls.TextBlock]::new()
    $heading.Text = $Title
    $heading.FontSize = 24
    $heading.FontWeight = [System.Windows.FontWeights]::SemiBold
    $heading.TextAlignment = [System.Windows.TextAlignment]::Center
    $heading.Margin = [System.Windows.Thickness]::new(0, 18, 0, 12)
    $details = [System.Windows.Controls.TextBlock]::new()
    $details.Text = $Message
    $details.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#D0D0D0')
    $details.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $details.TextAlignment = [System.Windows.TextAlignment]::Center
    $closeButton = [System.Windows.Controls.Button]::new()
    $closeButton.Content = 'Close'
    $closeButton.Width = 96
    $closeButton.Height = 34
    $closeButton.Margin = [System.Windows.Thickness]::new(0, 24, 0, 0)
    $closeButton.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $closeButton.Add_Click({ $window.Close() })
    [void] $stack.Children.Add($icon)
    [void] $stack.Children.Add($heading)
    [void] $stack.Children.Add($details)
    [void] $stack.Children.Add($closeButton)
    $border.Child = $stack

    if ($CapturePath) {
        $timer = [System.Windows.Threading.DispatcherTimer]::new()
        $timer.Interval = [TimeSpan]::FromMilliseconds(150)
        $timer.Add_Tick({
            $timer.Stop()
            $window.UpdateLayout()
            Save-StartMenuFolderVisual -Visual $border -LiteralPath $CapturePath
            $window.Close()
        })
        $window.Add_ContentRendered({ $timer.Start() })
    }

    [void] $window.ShowDialog()
}