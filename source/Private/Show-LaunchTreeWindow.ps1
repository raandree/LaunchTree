function Show-StartMenuFolderWindow {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        '',
        Justification = 'Snapshot is consumed by WPF event-handler closures.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject] $Configuration,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject] $Snapshot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $EntryName,

        [Parameter()]
        [AllowNull()]
        [string] $CapturePath,

        [Parameter()]
        [AllowNull()]
        [object] $ActivationServer,

        [Parameter()]
        [AllowNull()]
        [string] $GeneratedStatePath,

        [Parameter()]
        [AllowNull()]
        [Diagnostics.Stopwatch] $StartupStopwatch
    )

    Initialize-StartMenuFolderWpf
    try {
        $cacheTrimParameters = @{
            CachePath      = $Configuration.Cache.Path
            MaximumSizeMB  = $Configuration.Cache.MaximumSizeMB
            MaximumAgeDays = $Configuration.Cache.MaximumAgeDays
        }
        Remove-StartMenuFolderExpiredIconCache @cacheTrimParameters
    } catch {
        $cacheTrimError = $_
        Write-Verbose -Message $cacheTrimError.Exception.Message
    }

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

    $window = [System.Windows.Window]::new()
    $window.Title = $EntryName
    $window.WindowStyle = [System.Windows.WindowStyle]::None
    $window.ResizeMode = [System.Windows.ResizeMode]::CanResizeWithGrip
    $window.ShowInTaskbar = $true
    $window.MinWidth = 520
    $window.MinHeight = 420
    $window.Width = if ($Configuration.Window.Width) { $Configuration.Window.Width } else { 760 }
    $window.Height = if ($Configuration.Window.Height) { $Configuration.Window.Height } else { 590 }
    $window.Background = $windowBrush
    $window.Foreground = $foregroundBrush
    $window.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe UI Variable Text')
    $window.FontSize = 14
    $window.UseLayoutRounding = $true
    $window.SnapsToDevicePixels = $true

    $rootBorder = [System.Windows.Controls.Border]::new()
    $rootBorder.BorderBrush = $borderBrush
    $rootBorder.BorderThickness = [System.Windows.Thickness]::new(1)
    $rootBorder.CornerRadius = [System.Windows.CornerRadius]::new(8)
    $rootBorder.Background = $windowBrush
    $window.Content = $rootBorder

    $rootGrid = [System.Windows.Controls.Grid]::new()
    [void] $rootGrid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new())
    $rootGrid.RowDefinitions[0].Height = [System.Windows.GridLength]::Auto
    [void] $rootGrid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new())
    $rootGrid.RowDefinitions[1].Height = [System.Windows.GridLength]::Auto
    [void] $rootGrid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new())
    $rootGrid.RowDefinitions[2].Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    [void] $rootGrid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new())
    $rootGrid.RowDefinitions[3].Height = [System.Windows.GridLength]::Auto
    $rootBorder.Child = $rootGrid

    $header = [System.Windows.Controls.Grid]::new()
    $header.Margin = [System.Windows.Thickness]::new(20, 16, 20, 10)
    [void] $header.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]::new())
    $header.ColumnDefinitions[0].Width = [System.Windows.GridLength]::Auto
    [void] $header.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]::new())
    $header.ColumnDefinitions[1].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    [void] $header.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]::new())
    $header.ColumnDefinitions[2].Width = [System.Windows.GridLength]::Auto
    [void] $header.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]::new())
    $header.ColumnDefinitions[3].Width = [System.Windows.GridLength]::Auto
    [System.Windows.Controls.Grid]::SetRow($header, 0)
    [void] $rootGrid.Children.Add($header)

    $backButton = [System.Windows.Controls.Button]::new()
    $backButton.Content = [char] 0xE72B
    $backButton.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe Fluent Icons')
    $backButton.FontSize = 16
    $backButton.Width = 36
    $backButton.Height = 36
    $backButton.Margin = [System.Windows.Thickness]::new(0, 0, 12, 0)
    $backButton.ToolTip = 'Back'
    $backButton.IsEnabled = $false
    [System.Windows.Controls.Grid]::SetColumn($backButton, 0)
    [void] $header.Children.Add($backButton)

    $titleStack = [System.Windows.Controls.StackPanel]::new()
    $title = [System.Windows.Controls.TextBlock]::new()
    $title.Text = $EntryName
    $title.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe UI Variable Display Semibold')
    $title.FontSize = 24
    $title.Foreground = $foregroundBrush
    $breadcrumb = [System.Windows.Controls.TextBlock]::new()
    $breadcrumb.Text = $EntryName
    $breadcrumb.Foreground = $secondaryBrush
    $breadcrumb.FontSize = 12
    $breadcrumb.Margin = [System.Windows.Thickness]::new(0, 3, 0, 0)
    [void] $titleStack.Children.Add($title)
    [void] $titleStack.Children.Add($breadcrumb)
    [System.Windows.Controls.Grid]::SetColumn($titleStack, 1)
    [void] $header.Children.Add($titleStack)

    $sortBox = [System.Windows.Controls.ComboBox]::new()
    $sortBox.Width = 106
    $sortBox.Height = 34
    $sortBox.Margin = [System.Windows.Thickness]::new(12, 0, 8, 0)
    [void] $sortBox.Items.Add('Name A-Z')
    [void] $sortBox.Items.Add('Name Z-A')
    $sortBox.SelectedIndex = if ($Configuration.SortOrder -eq 'NameDescending') { 1 } else { 0 }
    $sortBox.ToolTip = 'Sort order'
    [System.Windows.Controls.Grid]::SetColumn($sortBox, 2)
    [void] $header.Children.Add($sortBox)

    $closeButton = [System.Windows.Controls.Button]::new()
    $closeButton.Content = [char] 0xE8BB
    $closeButton.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe Fluent Icons')
    $closeButton.FontSize = 14
    $closeButton.Width = 36
    $closeButton.Height = 36
    $closeButton.ToolTip = 'Close'
    [System.Windows.Controls.Grid]::SetColumn($closeButton, 3)
    [void] $header.Children.Add($closeButton)

    $searchBorder = [System.Windows.Controls.Border]::new()
    $searchBorder.Margin = [System.Windows.Thickness]::new(20, 0, 20, 14)
    $searchBorder.Background = $surfaceBrush
    $searchBorder.BorderBrush = $borderBrush
    $searchBorder.BorderThickness = [System.Windows.Thickness]::new(1)
    $searchBorder.CornerRadius = [System.Windows.CornerRadius]::new(6)
    [System.Windows.Controls.Grid]::SetRow($searchBorder, 1)
    [void] $rootGrid.Children.Add($searchBorder)

    $searchGrid = [System.Windows.Controls.Grid]::new()
    [void] $searchGrid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]::new())
    $searchGrid.ColumnDefinitions[0].Width = [System.Windows.GridLength]::Auto
    [void] $searchGrid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]::new())
    $searchGrid.ColumnDefinitions[1].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $searchIcon = [System.Windows.Controls.TextBlock]::new()
    $searchIcon.Text = [char] 0xE721
    $searchIcon.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe Fluent Icons')
    $searchIcon.Foreground = $secondaryBrush
    $searchIcon.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $searchIcon.Margin = [System.Windows.Thickness]::new(12, 0, 8, 0)
    [void] $searchGrid.Children.Add($searchIcon)
    $searchBox = [System.Windows.Controls.TextBox]::new()
    $searchBox.Height = 38
    $searchBox.BorderThickness = [System.Windows.Thickness]::new(0)
    $searchBox.Background = [System.Windows.Media.Brushes]::Transparent
    $searchBox.Foreground = $foregroundBrush
    $searchBox.CaretBrush = $accentBrush
    $searchBox.VerticalContentAlignment = [System.Windows.VerticalAlignment]::Center
    $searchBox.ToolTip = 'Search all Start menu folders'
    [System.Windows.Controls.Grid]::SetColumn($searchBox, 1)
    [void] $searchGrid.Children.Add($searchBox)
    $searchBorder.Child = $searchGrid

    $scrollViewer = [System.Windows.Controls.ScrollViewer]::new()
    $scrollViewer.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $scrollViewer.HorizontalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Disabled
    $scrollViewer.Padding = [System.Windows.Thickness]::new(14, 0, 14, 8)
    [System.Windows.Controls.Grid]::SetRow($scrollViewer, 2)
    [void] $rootGrid.Children.Add($scrollViewer)
    $itemsPanel = [System.Windows.Controls.WrapPanel]::new()
    $itemsPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $scrollViewer.Content = $itemsPanel

    $statusText = [System.Windows.Controls.TextBlock]::new()
    $statusText.Margin = [System.Windows.Thickness]::new(20, 8, 20, 14)
    $statusText.Foreground = $secondaryBrush
    $statusText.FontSize = 12
    $statusText.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    [System.Windows.Controls.Grid]::SetRow($statusText, 3)
    [void] $rootGrid.Children.Add($statusText)

    $buttonStyleXaml = @"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
       TargetType="Button">
  <Setter Property="Background" Value="Transparent" />
  <Setter Property="Foreground" Value="$( $foregroundBrush.Color.ToString() )" />
  <Setter Property="BorderThickness" Value="0" />
  <Setter Property="Padding" Value="6" />
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="Button">
        <Border x:Name="Root" Background="{TemplateBinding Background}"
                CornerRadius="6" Padding="{TemplateBinding Padding}">
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True">
            <Setter TargetName="Root" Property="Background" Value="$hoverColor" />
          </Trigger>
          <Trigger Property="IsPressed" Value="True">
            <Setter TargetName="Root" Property="Background" Value="$pressedColor" />
          </Trigger>
          <Trigger Property="IsKeyboardFocused" Value="True">
            <Setter TargetName="Root" Property="BorderBrush" Value="$( $accentBrush.Color.ToString() )" />
            <Setter TargetName="Root" Property="BorderThickness" Value="2" />
          </Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>
"@
    $buttonStyle = [System.Windows.Markup.XamlReader]::Parse($buttonStyleXaml)
    foreach ($button in @($backButton, $closeButton)) {
        $button.Style = $buttonStyle
    }

    $script:currentRelativePath = ''
    $script:visibleButtons = [System.Collections.Generic.List[object]]::new()
    $script:iconJobs = [System.Collections.Generic.List[object]]::new()
    $script:activeConfiguration = $Configuration
    $script:activeSnapshot = $Snapshot
    $script:activeEntryName = $EntryName

    $renderItems = {
        $interactionStopwatch = [Diagnostics.Stopwatch]::StartNew()
        $itemsPanel.Children.Clear()
        $script:visibleButtons.Clear()
        $script:iconJobs.Clear()

        $searchText = $searchBox.Text.Trim()
        $isSearching = -not [string]::IsNullOrWhiteSpace($searchText)
        $candidateItems = if ($isSearching) {
            @($script:activeSnapshot.Objects | Where-Object {
                $_.Name.IndexOf($searchText, [StringComparison]::CurrentCultureIgnoreCase) -ge 0
            })
        } else {
            @($script:activeSnapshot.Objects | Where-Object {
                $_.EntryName -eq $script:activeEntryName -and
                $_.ParentRelativePath -eq $script:currentRelativePath
            })
        }

        $descending = $sortBox.SelectedIndex -eq 1
        $candidateItems = @($candidateItems | Sort-Object -Property Name -Descending:$descending)
        foreach ($item in $candidateItems) {
            $button = [System.Windows.Controls.Button]::new()
            $button.Style = $buttonStyle
            $button.Width = 122
            $button.Height = 112
            $button.Margin = [System.Windows.Thickness]::new(5)
            $button.Tag = $item
            $button.ContextMenu = $null
            if (-not [string]::IsNullOrWhiteSpace($item.Description)) {
                $tooltip = [System.Windows.Controls.ToolTip]::new()
                $tooltip.Content = $item.Description
                $tooltip.MaxWidth = 360
                $tooltip.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Mouse
                $button.ToolTip = $tooltip
            }

            $stack = [System.Windows.Controls.StackPanel]::new()
            $stack.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
            $iconGrid = [System.Windows.Controls.Grid]::new()
            $iconGrid.Width = 52
            $iconGrid.Height = 52
            $placeholder = [System.Windows.Controls.TextBlock]::new()
            $placeholder.Text = if ($item.Kind -eq 'MenuFolder') { [char] 0xE8B7 } else { [char] 0xE8A5 }
            $placeholder.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe Fluent Icons')
            $placeholder.FontSize = 35
            $placeholder.Foreground = $accentBrush
            $placeholder.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
            $placeholder.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $image = [System.Windows.Controls.Image]::new()
            $image.Width = 48
            $image.Height = 48
            $image.Stretch = [System.Windows.Media.Stretch]::Uniform
            [void] $iconGrid.Children.Add($placeholder)
            [void] $iconGrid.Children.Add($image)

            $label = [System.Windows.Controls.TextBlock]::new()
            $label.Text = $item.Name
            $label.Foreground = $foregroundBrush
            $label.TextAlignment = [System.Windows.TextAlignment]::Center
            $label.TextWrapping = [System.Windows.TextWrapping]::Wrap
            $label.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
            $label.MaxHeight = 39
            $label.Width = 104
            $label.Margin = [System.Windows.Thickness]::new(0, 7, 0, 0)

            [void] $stack.Children.Add($iconGrid)
            [void] $stack.Children.Add($label)
            $button.Content = $stack
            [void] $itemsPanel.Children.Add($button)
            [void] $script:visibleButtons.Add($button)

            $cachePath = $null
            try {
                $cacheParameters = @{
                    CachePath  = $script:activeConfiguration.Cache.Path
                    SourcePath = $item.FullPath
                    PixelSize  = 64
                }
                $cachePath = Get-StartMenuFolderIconCachePath @cacheParameters
                $cachedIcon = Get-StartMenuFolderCachedIcon -LiteralPath $cachePath
                if ($cachedIcon) {
                    $image.Source = $cachedIcon
                    $placeholder.Visibility = [System.Windows.Visibility]::Collapsed
                }
            } catch {
                $cacheReadError = $_
                $eventParameters = @{
                    Configuration = $script:activeConfiguration
                    EventId       = 1402
                    Level         = 'Warning'
                    Operation     = 'IconCache'
                    Message       = $cacheReadError.Exception.Message
                    Path          = $cachePath
                }
                $null = Write-StartMenuFolderEvent @eventParameters
                Write-Verbose -Message $cacheReadError.Exception.Message
            }

            if (-not $image.Source -and $CapturePath) {
                try {
                    $image.Source = [StartMenuFolders.NativeIcon]::Get($item.FullPath, 64)
                    $placeholder.Visibility = [System.Windows.Visibility]::Collapsed
                    if ($cachePath) {
                        Save-StartMenuFolderCachedIcon -Image $image.Source -LiteralPath $cachePath
                    }
                } catch {
                    $iconError = $_
                    $eventParameters = @{
                        Configuration = $script:activeConfiguration
                        EventId       = 1401
                        Level         = 'Warning'
                        Operation     = 'IconExtraction'
                        Message       = $iconError.Exception.Message
                        Path          = $item.FullPath
                    }
                    $null = Write-StartMenuFolderEvent @eventParameters
                    Write-Verbose -Message $iconError.Exception.Message
                }
            } elseif (-not $image.Source) {
                $job = [PSCustomObject] @{
                    Task        = [StartMenuFolders.NativeIcon]::GetAsync($item.FullPath, 64)
                    Image       = $image
                    Placeholder = $placeholder
                    CachePath   = $cachePath
                }
                [void] $script:iconJobs.Add($job)
            }

            $button.Add_Click({
                param($eventSource, $eventArguments)
                $selectedItem = $eventSource.Tag
                if ($selectedItem.Kind -eq 'MenuFolder') {
                    $script:currentRelativePath = $selectedItem.RelativePath
                    $breadcrumb.Text = @(
                        $script:activeEntryName,
                        $script:currentRelativePath
                    ) -join '  ›  '
                    $backButton.IsEnabled = $true
                    $searchBox.Text = ''
                    & $renderItems
                } else {
                    $launchParameters = @{
                        LiteralPath   = $selectedItem.FullPath
                        Configuration = $script:activeConfiguration
                    }
                    $launchResult = Invoke-StartMenuFolderLaunchItem @launchParameters
                    if ($launchResult.Succeeded) {
                        if ($script:activeConfiguration.CloseAfterLaunch) {
                            $window.Close()
                        }
                    } else {
                        $statusText.Foreground = [System.Windows.Media.Brushes]::IndianRed
                        $statusText.Text = $launchResult.Message
                    }
                }
                $eventArguments.Handled = $true
            })
        }

        if ($candidateItems.Count -eq 0) {
            $emptyText = [System.Windows.Controls.TextBlock]::new()
            $emptyText.Text = if ($isSearching) { 'No matching items' } else { 'This folder is empty' }
            $emptyText.Foreground = $secondaryBrush
            $emptyText.FontSize = 16
            $emptyText.Margin = [System.Windows.Thickness]::new(24, 60, 24, 24)
            [void] $itemsPanel.Children.Add($emptyText)
        }

        $statusText.Text = if ($isSearching) {
            '{0} results across all Start Entries' -f $candidateItems.Count
        } else {
            '{0} items' -f $candidateItems.Count
        }
        $interactionStopwatch.Stop()
        $performanceParameters = @{
            Configuration = $script:activeConfiguration
            Metric        = 'Interaction'
            Value         = $interactionStopwatch.Elapsed.TotalMilliseconds
        }
        $null = Write-StartMenuFolderPerformanceEvent @performanceParameters
    }

    $iconTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $iconTimer.Interval = [TimeSpan]::FromMilliseconds(40)
    $iconTimer.Add_Tick({
        foreach ($job in @($script:iconJobs)) {
            if (-not $job.Task.IsCompleted) {
                continue
            }
            if ($job.Task.Status -eq [Threading.Tasks.TaskStatus]::RanToCompletion) {
                $job.Image.Source = $job.Task.Result
                $job.Placeholder.Visibility = [System.Windows.Visibility]::Collapsed
                if ($job.CachePath) {
                    try {
                        $saveCacheParameters = @{
                            Image       = $job.Task.Result
                            LiteralPath = $job.CachePath
                        }
                        Save-StartMenuFolderCachedIcon @saveCacheParameters
                    } catch {
                        $cacheWriteError = $_
                        $eventParameters = @{
                            Configuration = $script:activeConfiguration
                            EventId       = 1402
                            Level         = 'Warning'
                            Operation     = 'IconCache'
                            Message       = $cacheWriteError.Exception.Message
                            Path          = $job.CachePath
                        }
                        $null = Write-StartMenuFolderEvent @eventParameters
                        Write-Verbose -Message $cacheWriteError.Exception.Message
                    }
                }
            } elseif ($job.Task.IsFaulted) {
                $eventParameters = @{
                    Configuration = $script:activeConfiguration
                    EventId       = 1401
                    Level         = 'Warning'
                    Operation     = 'IconExtraction'
                    Message       = $job.Task.Exception.GetBaseException().Message
                    Path          = $null
                }
                $null = Write-StartMenuFolderEvent @eventParameters
            }
            [void] $script:iconJobs.Remove($job)
        }
        if ($script:iconJobs.Count -eq 0) {
            $iconTimer.Stop()
        }
    })

    $activationTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $activationTimer.Interval = [TimeSpan]::FromMilliseconds(80)
    $activationTimer.Add_Tick({
        if (-not $ActivationServer) {
            $activationTimer.Stop()
            return
        }

        $message = $ActivationServer.Take(0)
        while ($message) {
            try {
                $activation = $message | ConvertFrom-Json -ErrorAction Stop
                $configurationParameters = @{
                    ConfigurationPath = [string] $activation.ConfigurationPath
                }
                $nextConfiguration = Get-StartMenuFolderConfiguration @configurationParameters
                $resolveParameters = @{
                    EntryId            = [guid] $activation.EntryId
                    ManagedRoot        = $nextConfiguration.ManagedRoot
                    GeneratedStatePath = [string] $activation.GeneratedStatePath
                }
                $nextEntry = Resolve-StartMenuFolderEntry @resolveParameters
                $nextSnapshot = Get-StartMenuFolderContentSnapshot -Configuration $nextConfiguration
                if (@($nextSnapshot.HealthFindings | Where-Object Severity -eq 'Error').Count -gt 0) {
                    throw [System.InvalidOperationException]::new(
                        'The requested Entry Root is unhealthy.'
                    )
                }

                $script:activeConfiguration = $nextConfiguration
                $script:activeSnapshot = $nextSnapshot
                $script:activeEntryName = $nextEntry.Name
                $script:currentRelativePath = ''
                $title.Text = $nextEntry.Name
                $window.Title = $nextEntry.Name
                $breadcrumb.Text = $nextEntry.Name
                $backButton.IsEnabled = $false
                $searchBox.Text = ''
                & $renderItems
                [void] $window.Activate()
            } catch {
                $activationError = $_
                $statusText.Foreground = [System.Windows.Media.Brushes]::IndianRed
                $statusText.Text = $activationError.Exception.Message
            }
            $message = $ActivationServer.Take(0)
        }
    })

    $backButton.Add_Click({
        if ([string]::IsNullOrWhiteSpace($script:currentRelativePath)) {
            return
        }
        $parent = [IO.Path]::GetDirectoryName($script:currentRelativePath)
        $script:currentRelativePath = if ($parent) { $parent } else { '' }
        $breadcrumb.Text = if ($script:currentRelativePath) {
            @($script:activeEntryName, $script:currentRelativePath) -join '  ›  '
        } else {
            $script:activeEntryName
        }
        $backButton.IsEnabled = -not [string]::IsNullOrWhiteSpace($script:currentRelativePath)
        & $renderItems
    })
    $closeButton.Add_Click({ $window.Close() })
    $sortBox.Add_SelectionChanged({ & $renderItems })
    $searchBox.Add_TextChanged({ & $renderItems })
    $window.Add_PreviewMouseRightButtonDown({
        param($eventSource, $eventArguments)
        [void] $eventSource
        $eventArguments.Handled = $true
    })
    $window.Add_StylusSystemGesture({
        param($eventSource, $eventArguments)
        [void] $eventSource
        $eventArguments.Handled = $true
    })
    $window.Add_PreviewKeyDown({
        param($eventSource, $eventArguments)
        [void] $eventSource
        if ($eventArguments.Key -eq [System.Windows.Input.Key]::Escape) {
            $window.Close()
            $eventArguments.Handled = $true
        } elseif ($eventArguments.Key -eq [System.Windows.Input.Key]::Back -and
            -not $searchBox.IsKeyboardFocusWithin) {
            $backButton.RaiseEvent([System.Windows.RoutedEventArgs]::new(
                [System.Windows.Controls.Button]::ClickEvent
            ))
            $eventArguments.Handled = $true
        } elseif ($eventArguments.Key -in @(
            [System.Windows.Input.Key]::Left,
            [System.Windows.Input.Key]::Right,
            [System.Windows.Input.Key]::Up,
            [System.Windows.Input.Key]::Down
        ) -and $script:visibleButtons.Count -gt 0) {
            $currentIndex = -1
            for ($index = 0; $index -lt $script:visibleButtons.Count; $index++) {
                if ($script:visibleButtons[$index].IsKeyboardFocused) {
                    $currentIndex = $index
                    break
                }
            }
            $columns = [Math]::Max(1, [int] [Math]::Floor($itemsPanel.ActualWidth / 132))
            $delta = switch ($eventArguments.Key) {
                Left { -1 }
                Right { 1 }
                Up { -$columns }
                Down { $columns }
            }
            $targetIndex = if ($currentIndex -lt 0) { 0 } else {
                [Math]::Max(0, [Math]::Min($script:visibleButtons.Count - 1, $currentIndex + $delta))
            }
            [void] $script:visibleButtons[$targetIndex].Focus()
            $eventArguments.Handled = $true
        }
    })

    $window.Add_ContentRendered({
        if ($StartupStopwatch -and $StartupStopwatch.IsRunning) {
            $StartupStopwatch.Stop()
            $performanceParameters = @{
                Configuration = $script:activeConfiguration
                Metric        = 'Startup'
                Value         = $StartupStopwatch.Elapsed.TotalMilliseconds
            }
            $null = Write-StartMenuFolderPerformanceEvent @performanceParameters
        }
        $workArea = [System.Windows.SystemParameters]::WorkArea
        $taskbarAlignment = 0
        try {
            $taskbarAlignment = [int] (Get-ItemPropertyValue -LiteralPath (
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            ) -Name 'TaskbarAl' -ErrorAction Stop)
        } catch {
            $taskbarError = $_
            Write-Verbose -Message $taskbarError.Exception.Message
        }
        $window.Left = if ($taskbarAlignment -eq 1) {
            $workArea.Left + (($workArea.Width - $window.ActualWidth) / 2)
        } else {
            $workArea.Left + 12
        }
        $window.Top = $workArea.Bottom - $window.ActualHeight - 12
        if ($window.Top -lt $workArea.Top) {
            $window.Top = $workArea.Top
        }
        if (-not $CapturePath -and $script:iconJobs.Count -gt 0) {
            $iconTimer.Start()
        }
        if ($ActivationServer) {
            $activationTimer.Start()
        }
    })

    & $renderItems

    if ($CapturePath) {
        $captureTimer = [System.Windows.Threading.DispatcherTimer]::new()
        $captureTimer.Interval = [TimeSpan]::FromMilliseconds(200)
        $captureTimer.Add_Tick({
            $captureTimer.Stop()
            $window.UpdateLayout()
            Save-StartMenuFolderVisual -Visual $rootBorder -LiteralPath $CapturePath
            $window.Close()
        })
        $window.Add_ContentRendered({ $captureTimer.Start() })
    }

    $window.Add_Closed({
        $iconTimer.Stop()
        $activationTimer.Stop()
        $workingSetMB = [Diagnostics.Process]::GetCurrentProcess().WorkingSet64 / 1MB
        $performanceParameters = @{
            Configuration = $script:activeConfiguration
            Metric        = 'WorkingSetMB'
            Value         = $workingSetMB
        }
        $null = Write-StartMenuFolderPerformanceEvent @performanceParameters
        if (-not $CapturePath) {
            try {
                $preferenceParameters = @{
                    Configuration = $script:activeConfiguration
                    SortOrder     = if ($sortBox.SelectedIndex -eq 1) {
                        'NameDescending'
                    } else {
                        'NameAscending'
                    }
                    Width         = $window.ActualWidth
                    Height        = $window.ActualHeight
                    Left          = $window.Left
                    Top           = $window.Top
                }
                Save-StartMenuFolderPreference @preferenceParameters
            } catch {
                $preferenceError = $_
                Write-Verbose -Message $preferenceError.Exception.Message
            }
        }
    })

    [void] $window.ShowDialog()
}