function Show-LaunchTreeWindow {
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

    Initialize-LaunchTreeWpf
    try {
        $cacheTrimParameters = @{
            CachePath      = $Configuration.Cache.Path
            MaximumSizeMB  = $Configuration.Cache.MaximumSizeMB
            MaximumAgeDays = $Configuration.Cache.MaximumAgeDays
        }
        Remove-LaunchTreeExpiredIconCache @cacheTrimParameters
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
    $useTabbedListLayout = $Configuration.LauncherLayout -eq 'TabbedList'

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

    $window = [System.Windows.Window]::new()
    $window.Title = $EntryName
    $window.WindowStyle = [System.Windows.WindowStyle]::None
    $window.ResizeMode = [System.Windows.ResizeMode]::CanResizeWithGrip
    $window.ShowInTaskbar = $true
    $window.MinWidth = if ($useTabbedListLayout) { 600 } else { 520 }
    $window.MinHeight = 420
    $window.Width = if ($Configuration.Window.Width) {
        $Configuration.Window.Width
    } elseif ($useTabbedListLayout) {
        680
    } else {
        760
    }
    $window.Height = if ($Configuration.Window.Height) {
        $Configuration.Window.Height
    } elseif ($useTabbedListLayout) {
        720
    } else {
        590
    }
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
    $rootGrid.RowDefinitions[2].Height = [System.Windows.GridLength]::Auto
    [void] $rootGrid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new())
    $rootGrid.RowDefinitions[3].Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    [void] $rootGrid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new())
    $rootGrid.RowDefinitions[4].Height = [System.Windows.GridLength]::Auto
    $rootBorder.Child = $rootGrid

    $header = [System.Windows.Controls.Grid]::new()
    $header.Margin = if ($useTabbedListLayout) {
        [System.Windows.Thickness]::new(24, 18, 24, 14)
    } else {
        [System.Windows.Thickness]::new(20, 16, 20, 10)
    }
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
    $title.FontSize = if ($useTabbedListLayout) { 20 } else { 24 }
    $title.Foreground = $foregroundBrush
    $descriptionText = [System.Windows.Controls.TextBlock]::new()
    $descriptionText.Foreground = $secondaryBrush
    $descriptionText.FontSize = 12
    $descriptionText.Margin = [System.Windows.Thickness]::new(0, 3, 0, 0)
    $descriptionText.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $descriptionText.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    $descriptionText.MaxHeight = 42
    $descriptionText.Visibility = [System.Windows.Visibility]::Collapsed
    $breadcrumb = [System.Windows.Controls.TextBlock]::new()
    $breadcrumb.Text = $EntryName
    $breadcrumb.Foreground = $secondaryBrush
    $breadcrumb.FontSize = 12
    $breadcrumb.Margin = [System.Windows.Thickness]::new(0, 3, 0, 0)
    [void] $titleStack.Children.Add($title)
    if ($useTabbedListLayout) {
        [void] $titleStack.Children.Add($descriptionText)
    }
    [void] $titleStack.Children.Add($breadcrumb)
    [System.Windows.Controls.Grid]::SetColumn($titleStack, 1)
    [void] $header.Children.Add($titleStack)

    $sortBox = [System.Windows.Controls.ComboBox]::new()
    $sortBox.Width = 132
    $sortBox.Height = 36
    $sortBox.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
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
    $searchBorder.Margin = if ($useTabbedListLayout) {
        [System.Windows.Thickness]::new(24, 12, 24, 8)
    } else {
        [System.Windows.Thickness]::new(20, 0, 20, 14)
    }
    $searchBorder.Background = $surfaceBrush
    $searchBorder.BorderBrush = $borderBrush
    $searchBorder.BorderThickness = [System.Windows.Thickness]::new(1)
    $searchBorder.CornerRadius = [System.Windows.CornerRadius]::new(6)
    [System.Windows.Controls.Grid]::SetRow(
        $searchBorder,
        $(if ($useTabbedListLayout) { 2 } else { 1 })
    )
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
    $searchBox.ToolTip = 'Search all Entry Roots'
    [System.Windows.Controls.Grid]::SetColumn($searchBox, 1)
    [void] $searchGrid.Children.Add($searchBox)
    $searchBorder.Child = $searchGrid

    $folderTabs = [System.Windows.Controls.TabControl]::new()
    $folderTabs.Height = 44
    $folderTabs.Background = $surfaceBrush
    $folderTabs.BorderBrush = $borderBrush
    $folderTabs.BorderThickness = [System.Windows.Thickness]::new(0, 0, 0, 1)
    $folderTabs.Visibility = if ($useTabbedListLayout) {
        [System.Windows.Visibility]::Visible
    } else {
        [System.Windows.Visibility]::Collapsed
    }
    [System.Windows.Controls.Grid]::SetRow($folderTabs, 1)
    [void] $rootGrid.Children.Add($folderTabs)

    $scrollViewer = [System.Windows.Controls.ScrollViewer]::new()
    $scrollViewer.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $scrollViewer.HorizontalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Disabled
    $scrollViewer.Padding = if ($useTabbedListLayout) {
        [System.Windows.Thickness]::new(24, 8, 20, 8)
    } else {
        [System.Windows.Thickness]::new(14, 0, 14, 8)
    }
    [System.Windows.Controls.Grid]::SetRow($scrollViewer, 3)
    [void] $rootGrid.Children.Add($scrollViewer)
    if ($useTabbedListLayout) {
        $itemsPanel = [System.Windows.Controls.StackPanel]::new()
        $itemsPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Stretch
        $listBorder = [System.Windows.Controls.Border]::new()
        $listBorder.Background = $surfaceBrush
        $listBorder.BorderBrush = $borderBrush
        $listBorder.BorderThickness = [System.Windows.Thickness]::new(1)
        $listBorder.CornerRadius = [System.Windows.CornerRadius]::new(8)
        $listBorder.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
        $listBorder.Child = $itemsPanel
        $scrollViewer.Content = $listBorder
    } else {
        $itemsPanel = [System.Windows.Controls.WrapPanel]::new()
        $itemsPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $scrollViewer.Content = $itemsPanel
    }

    $statusText = [System.Windows.Controls.TextBlock]::new()
    $statusText.Margin = [System.Windows.Thickness]::new(20, 8, 20, 14)
    $statusText.Foreground = $secondaryBrush
    $statusText.FontSize = 12
    $statusText.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    [System.Windows.Controls.Grid]::SetRow($statusText, 4)
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
                        <Setter Property="Foreground" Value="$hoverForegroundColor" />
          </Trigger>
          <Trigger Property="IsPressed" Value="True">
            <Setter TargetName="Root" Property="Background" Value="$pressedColor" />
                        <Setter Property="Foreground" Value="$pressedForegroundColor" />
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

    $sortStyleXaml = @"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
       TargetType="ComboBox">
  <Setter Property="Foreground" Value="$( $foregroundBrush.Color.ToString() )" />
  <Setter Property="FontSize" Value="13" />
  <Setter Property="VerticalContentAlignment" Value="Center" />
  <Setter Property="FocusVisualStyle" Value="{x:Null}" />
  <Setter Property="ItemContainerStyle">
    <Setter.Value>
      <Style TargetType="ComboBoxItem">
        <Setter Property="Foreground" Value="$( $foregroundBrush.Color.ToString() )" />
        <Setter Property="Template">
          <Setter.Value>
            <ControlTemplate TargetType="ComboBoxItem">
              <Border x:Name="ItemRoot" Background="Transparent" CornerRadius="4"
                      Margin="4,1,4,1" Padding="0,7,10,7" SnapsToDevicePixels="True">
                <Grid>
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="12" />
                    <ColumnDefinition Width="*" />
                  </Grid.ColumnDefinitions>
                  <Border x:Name="ItemAccent" Width="3" Height="16" CornerRadius="2"
                          Background="$( $accentBrush.Color.ToString() )"
                          HorizontalAlignment="Center" VerticalAlignment="Center"
                          Visibility="Collapsed" />
                  <ContentPresenter Grid.Column="1" VerticalAlignment="Center"
                                    TextElement.Foreground="{TemplateBinding Foreground}" />
                </Grid>
              </Border>
              <ControlTemplate.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                  <Setter TargetName="ItemRoot" Property="Background" Value="$hoverColor" />
                                    <Setter Property="Foreground" Value="$hoverForegroundColor" />
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                  <Setter TargetName="ItemRoot" Property="Background" Value="$pressedColor" />
                  <Setter TargetName="ItemAccent" Property="Visibility" Value="Visible" />
                                    <Setter Property="Foreground" Value="$pressedForegroundColor" />
                </Trigger>
              </ControlTemplate.Triggers>
            </ControlTemplate>
          </Setter.Value>
        </Setter>
      </Style>
    </Setter.Value>
  </Setter>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="ComboBox">
        <Grid>
          <Border x:Name="Root" Background="$( $surfaceBrush.Color.ToString() )"
                  BorderBrush="$( $borderBrush.Color.ToString() )" BorderThickness="1"
                  CornerRadius="6" SnapsToDevicePixels="True" />
          <ToggleButton Focusable="False" ClickMode="Press"
                        IsChecked="{Binding IsDropDownOpen, Mode=TwoWay,
                                    RelativeSource={RelativeSource TemplatedParent}}">
            <ToggleButton.Template>
              <ControlTemplate TargetType="ToggleButton">
                <Border Background="Transparent" />
              </ControlTemplate>
            </ToggleButton.Template>
          </ToggleButton>
          <ContentPresenter Margin="12,0,34,0" IsHitTestVisible="False"
                            HorizontalAlignment="Left" VerticalAlignment="Center"
                            TextElement.Foreground="{TemplateBinding Foreground}"
                            Content="{TemplateBinding SelectionBoxItem}"
                            ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                            ContentStringFormat="{TemplateBinding SelectionBoxItemStringFormat}" />
          <TextBlock Text="&#xE70D;" FontFamily="Segoe Fluent Icons" FontSize="11"
                     Foreground="$( $secondaryBrush.Color.ToString() )"
                     IsHitTestVisible="False" Margin="0,0,13,0"
                     HorizontalAlignment="Right" VerticalAlignment="Center" />
          <Popup x:Name="PART_Popup" Placement="Bottom" VerticalOffset="4"
                 AllowsTransparency="True" Focusable="False" PopupAnimation="Fade"
                 IsOpen="{TemplateBinding IsDropDownOpen}">
            <Border Background="$( $surfaceBrush.Color.ToString() )"
                    BorderBrush="$( $borderBrush.Color.ToString() )" BorderThickness="1"
                    CornerRadius="6" Padding="0,4,0,4" SnapsToDevicePixels="True"
                    MaxHeight="{TemplateBinding MaxDropDownHeight}"
                    MinWidth="{Binding ActualWidth,
                              RelativeSource={RelativeSource TemplatedParent}}">
              <ScrollViewer>
                <StackPanel IsItemsHost="True"
                            KeyboardNavigation.DirectionalNavigation="Contained" />
              </ScrollViewer>
            </Border>
          </Popup>
        </Grid>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True">
            <Setter TargetName="Root" Property="Background" Value="$hoverColor" />
                        <Setter Property="Foreground" Value="$hoverForegroundColor" />
          </Trigger>
          <Trigger Property="IsDropDownOpen" Value="True">
            <Setter TargetName="Root" Property="Background" Value="$pressedColor" />
            <Setter TargetName="Root" Property="BorderBrush" Value="$( $accentBrush.Color.ToString() )" />
                        <Setter Property="Foreground" Value="$pressedForegroundColor" />
          </Trigger>
          <Trigger Property="IsKeyboardFocusWithin" Value="True">
            <Setter TargetName="Root" Property="BorderBrush" Value="$( $accentBrush.Color.ToString() )" />
            <Setter TargetName="Root" Property="BorderThickness" Value="2" />
          </Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>
"@
    $sortBox.Style = [System.Windows.Markup.XamlReader]::Parse($sortStyleXaml)

        if ($useTabbedListLayout) {
                $tabControlStyleXaml = @"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             TargetType="TabControl">
    <Setter Property="Background" Value="$( $surfaceBrush.Color.ToString() )" />
    <Setter Property="BorderThickness" Value="0" />
    <Setter Property="Padding" Value="20,0,12,0" />
    <Setter Property="Template">
        <Setter.Value>
            <ControlTemplate TargetType="TabControl">
                <Border Background="{TemplateBinding Background}"
                                BorderBrush="$( $borderBrush.Color.ToString() )"
                                BorderThickness="0,0,0,1">
                    <ScrollViewer HorizontalScrollBarVisibility="Auto"
                                                VerticalScrollBarVisibility="Disabled">
                        <TabPanel IsItemsHost="True" />
                    </ScrollViewer>
                </Border>
            </ControlTemplate>
        </Setter.Value>
    </Setter>
</Style>
"@
                $folderTabs.Style = [System.Windows.Markup.XamlReader]::Parse($tabControlStyleXaml)

                $tabItemStyleXaml = @"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             TargetType="TabItem">
    <Setter Property="Background" Value="Transparent" />
    <Setter Property="Foreground" Value="$( $secondaryBrush.Color.ToString() )" />
    <Setter Property="FontSize" Value="13" />
    <Setter Property="FontWeight" Value="SemiBold" />
    <Setter Property="Padding" Value="14,11,14,9" />
    <Setter Property="FocusVisualStyle" Value="{x:Null}" />
    <Setter Property="Template">
        <Setter.Value>
            <ControlTemplate TargetType="TabItem">
                <Border x:Name="TabRoot" Background="{TemplateBinding Background}"
                                BorderBrush="Transparent" BorderThickness="0,0,0,2"
                                Padding="{TemplateBinding Padding}">
                    <ContentPresenter ContentSource="Header"
                                                        HorizontalAlignment="Center"
                                                        VerticalAlignment="Center" />
                </Border>
                <ControlTemplate.Triggers>
                    <Trigger Property="IsSelected" Value="True">
                        <Setter TargetName="TabRoot" Property="BorderBrush"
                                        Value="$( $accentBrush.Color.ToString() )" />
                        <Setter Property="Foreground" Value="$( $accentBrush.Color.ToString() )" />
                    </Trigger>
                    <Trigger Property="IsMouseOver" Value="True">
                        <Setter TargetName="TabRoot" Property="Background" Value="$hoverColor" />
                        <Setter Property="Foreground" Value="$hoverForegroundColor" />
                    </Trigger>
                    <Trigger Property="IsKeyboardFocused" Value="True">
                        <Setter TargetName="TabRoot" Property="BorderBrush"
                                        Value="$( $accentBrush.Color.ToString() )" />
                    </Trigger>
                </ControlTemplate.Triggers>
            </ControlTemplate>
        </Setter.Value>
    </Setter>
</Style>
"@
                $tabItemStyle = [System.Windows.Markup.XamlReader]::Parse($tabItemStyleXaml)

                $listItemStyleXaml = @"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             TargetType="Button">
    <Setter Property="Background" Value="Transparent" />
    <Setter Property="Foreground" Value="$( $foregroundBrush.Color.ToString() )" />
    <Setter Property="BorderThickness" Value="0" />
    <Setter Property="Padding" Value="2" />
    <Setter Property="HorizontalContentAlignment" Value="Stretch" />
    <Setter Property="FocusVisualStyle" Value="{x:Null}" />
    <Setter Property="Template">
        <Setter.Value>
            <ControlTemplate TargetType="Button">
                <Border x:Name="FocusRoot" BorderBrush="Transparent"
                                BorderThickness="2" CornerRadius="5"
                                Padding="{TemplateBinding Padding}">
                    <Border x:Name="RowRoot" Background="{TemplateBinding Background}"
                                    BorderBrush="$( $borderBrush.Color.ToString() )"
                                    BorderThickness="0,0,0,1" Padding="14,8">
                        <ContentPresenter HorizontalAlignment="Stretch"
                                                            VerticalAlignment="Center" />
                    </Border>
                </Border>
                <ControlTemplate.Triggers>
                    <Trigger Property="IsMouseOver" Value="True">
                        <Setter TargetName="RowRoot" Property="Background" Value="$hoverColor" />
                        <Setter Property="Foreground" Value="$hoverForegroundColor" />
                    </Trigger>
                    <Trigger Property="IsPressed" Value="True">
                        <Setter TargetName="RowRoot" Property="Background" Value="$pressedColor" />
                        <Setter Property="Foreground" Value="$pressedForegroundColor" />
                    </Trigger>
                    <Trigger Property="IsKeyboardFocused" Value="True">
                        <Setter TargetName="FocusRoot" Property="BorderBrush"
                                        Value="$( $accentBrush.Color.ToString() )" />
                    </Trigger>
                </ControlTemplate.Triggers>
            </ControlTemplate>
        </Setter.Value>
    </Setter>
</Style>
"@
                $listItemStyle = [System.Windows.Markup.XamlReader]::Parse($listItemStyleXaml)
        }

    $script:currentRelativePath = ''
    $script:visibleButtons = [System.Collections.Generic.List[object]]::new()
    $script:iconJobs = [System.Collections.Generic.List[object]]::new()
    $script:activeConfiguration = $Configuration
    $script:activeSnapshot = $Snapshot
    $script:activeEntryName = $EntryName
    $script:isRenderingFolderTabs = $false

    $renderItems = {
        $interactionStopwatch = [Diagnostics.Stopwatch]::StartNew()
        $itemsPanel.Children.Clear()
        $script:visibleButtons.Clear()
        $script:iconJobs.Clear()

        $searchText = $searchBox.Text.Trim()
        $isSearching = -not [string]::IsNullOrWhiteSpace($searchText)
        if ($useTabbedListLayout) {
            $contentParameters = @{
                Snapshot            = $script:activeSnapshot
                EntryName           = $script:activeEntryName
                CurrentRelativePath = $script:currentRelativePath
                SearchText          = $searchText
                Descending          = $sortBox.SelectedIndex -eq 1
            }
            $tabbedContent = Get-LaunchTreeTabbedListContent @contentParameters
            $candidateItems = @($tabbedContent.LaunchItems)
            $menuFolders = @($tabbedContent.MenuFolders)
            $menuFolderTabs = @($tabbedContent.MenuFolderTabs)

            $descriptionText.Text = $tabbedContent.Description
            $descriptionText.Visibility = if ([string]::IsNullOrWhiteSpace(
                    $tabbedContent.Description
                )) {
                [System.Windows.Visibility]::Collapsed
            } else {
                [System.Windows.Visibility]::Visible
            }
            $descriptionText.ToolTip = if ($descriptionText.Visibility -eq
                [System.Windows.Visibility]::Visible) {
                $tabbedContent.Description
            } else {
                $null
            }
            $breadcrumb.Text = if ($script:currentRelativePath) {
                @($script:activeEntryName, $script:currentRelativePath) -join '  ›  '
            } else {
                $script:activeEntryName
            }

            $script:isRenderingFolderTabs = $true
            $folderTabs.Items.Clear()
            $currentTab = [System.Windows.Controls.TabItem]::new()
            $currentTab.Header = $tabbedContent.CurrentName
            $currentTab.Style = $tabItemStyle
            $currentTab.IsSelected = $true
            [void] $folderTabs.Items.Add($currentTab)
            foreach ($menuFolderTab in $menuFolderTabs) {
                $menuFolder = $menuFolderTab.Item
                if ($isSearching -and
                    $menuFolder.EntryName -eq $script:activeEntryName -and
                    $menuFolder.RelativePath -eq $script:currentRelativePath) {
                    continue
                }
                $folderTab = [System.Windows.Controls.TabItem]::new()
                if ($isSearching) {
                    $tabHeader = [System.Windows.Controls.StackPanel]::new()
                    $tabName = [System.Windows.Controls.TextBlock]::new()
                    $tabName.Text = $menuFolderTab.Header
                    $tabContext = [System.Windows.Controls.TextBlock]::new()
                    $tabContext.Text = $menuFolderTab.Context
                    $tabContext.FontSize = 10
                    $tabContext.Opacity = 0.76
                    $tabContext.MaxWidth = 220
                    $tabContext.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
                    [void] $tabHeader.Children.Add($tabName)
                    [void] $tabHeader.Children.Add($tabContext)
                    $folderTab.Header = $tabHeader
                } else {
                    $folderTab.Header = $menuFolderTab.Header
                }
                $folderTab.Style = $tabItemStyle
                $folderTab.Tag = $menuFolder
                if (-not [string]::IsNullOrWhiteSpace($menuFolder.Description)) {
                    $folderTab.ToolTip = $menuFolder.Description
                }
                [void] $folderTabs.Items.Add($folderTab)
            }
            $folderTabs.SelectedItem = $currentTab
            $script:isRenderingFolderTabs = $false
        } else {
            $candidateItems = if ($isSearching) {
                @($script:activeSnapshot.Objects | Where-Object {
                    $_.Name.IndexOf(
                        $searchText,
                        [StringComparison]::CurrentCultureIgnoreCase
                    ) -ge 0
                })
            } else {
                @($script:activeSnapshot.Objects | Where-Object {
                    $_.EntryName -eq $script:activeEntryName -and
                    $_.ParentRelativePath -eq $script:currentRelativePath
                })
            }
            $menuFolders = @($candidateItems | Where-Object Kind -eq 'MenuFolder')
        }

        $descending = $sortBox.SelectedIndex -eq 1
        if (-not $useTabbedListLayout) {
            $candidateItems = @(
                $candidateItems | Sort-Object -Property Name -Descending:$descending
            )
        }
        foreach ($item in $candidateItems) {
            $button = [System.Windows.Controls.Button]::new()
            $button.Style = if ($useTabbedListLayout) { $listItemStyle } else { $buttonStyle }
            if ($useTabbedListLayout) {
                $button.Height = 66
                $button.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Stretch
                $button.Margin = [System.Windows.Thickness]::new(0)
            } else {
                $button.Width = 122
                $button.Height = 112
                $button.Margin = [System.Windows.Thickness]::new(5)
            }
            $button.Tag = $item
            $button.ContextMenu = $null
            if (-not [string]::IsNullOrWhiteSpace($item.Description)) {
                $tooltip = [System.Windows.Controls.ToolTip]::new()
                $tooltip.Content = $item.Description
                $tooltip.MaxWidth = 360
                $tooltip.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Mouse
                $button.ToolTip = $tooltip
            }

            $iconGrid = [System.Windows.Controls.Grid]::new()
            $iconGrid.Width = if ($useTabbedListLayout) { 36 } else { 52 }
            $iconGrid.Height = if ($useTabbedListLayout) { 36 } else { 52 }
            $placeholder = [System.Windows.Controls.TextBlock]::new()
            $placeholder.Text = if ($item.Kind -eq 'MenuFolder') { [char] 0xE8B7 } else { [char] 0xE8A5 }
            $placeholder.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe Fluent Icons')
            $placeholder.FontSize = if ($useTabbedListLayout) { 24 } else { 35 }
            $placeholder.Foreground = $accentBrush
            $placeholder.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
            $placeholder.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $image = [System.Windows.Controls.Image]::new()
            $image.Width = if ($useTabbedListLayout) { 32 } else { 48 }
            $image.Height = if ($useTabbedListLayout) { 32 } else { 48 }
            $image.Stretch = [System.Windows.Media.Stretch]::Uniform
            [void] $iconGrid.Children.Add($placeholder)
            [void] $iconGrid.Children.Add($image)

            $label = [System.Windows.Controls.TextBlock]::new()
            $label.Text = $item.Name
            $label.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
            if ($useTabbedListLayout) {
                $label.FontSize = 13
                $label.FontWeight = [System.Windows.FontWeights]::SemiBold

                $detail = [System.Windows.Controls.TextBlock]::new()
                $detail.FontSize = 11
                $detail.Opacity = 0.72
                $detail.Margin = [System.Windows.Thickness]::new(0, 2, 0, 0)
                $detail.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
                $detail.Text = if ($isSearching) {
                    $location = if ($item.ParentRelativePath) {
                        '{0} › {1}' -f $item.EntryName, $item.ParentRelativePath
                    } else {
                        $item.EntryName
                    }
                    '{0} | {1}' -f $location, $item.ContentSource
                } elseif (-not [string]::IsNullOrWhiteSpace($item.Description)) {
                    $item.Description
                } else {
                    $item.ContentSource
                }

                $textStack = [System.Windows.Controls.StackPanel]::new()
                $textStack.Margin = [System.Windows.Thickness]::new(12, 0, 12, 0)
                [void] $textStack.Children.Add($label)
                [void] $textStack.Children.Add($detail)

                $openIcon = [System.Windows.Controls.TextBlock]::new()
                $openIcon.Text = [char] 0xE8A7
                $openIcon.FontFamily = [System.Windows.Media.FontFamily]::new(
                    'Segoe Fluent Icons'
                )
                $openIcon.FontSize = 14
                $openIcon.Opacity = 0.72
                $openIcon.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

                $rowGrid = [System.Windows.Controls.Grid]::new()
                [void] $rowGrid.ColumnDefinitions.Add(
                    [System.Windows.Controls.ColumnDefinition]::new()
                )
                $rowGrid.ColumnDefinitions[0].Width = [System.Windows.GridLength]::Auto
                [void] $rowGrid.ColumnDefinitions.Add(
                    [System.Windows.Controls.ColumnDefinition]::new()
                )
                $rowGrid.ColumnDefinitions[1].Width = [System.Windows.GridLength]::new(
                    1,
                    [System.Windows.GridUnitType]::Star
                )
                [void] $rowGrid.ColumnDefinitions.Add(
                    [System.Windows.Controls.ColumnDefinition]::new()
                )
                $rowGrid.ColumnDefinitions[2].Width = [System.Windows.GridLength]::Auto
                [System.Windows.Controls.Grid]::SetColumn($textStack, 1)
                [System.Windows.Controls.Grid]::SetColumn($openIcon, 2)
                [void] $rowGrid.Children.Add($iconGrid)
                [void] $rowGrid.Children.Add($textStack)
                [void] $rowGrid.Children.Add($openIcon)
                $button.Content = $rowGrid
            } else {
                $stack = [System.Windows.Controls.StackPanel]::new()
                $stack.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
                $label.TextAlignment = [System.Windows.TextAlignment]::Center
                $label.TextWrapping = [System.Windows.TextWrapping]::Wrap
                $label.MaxHeight = 39
                $label.Width = 104
                $label.Margin = [System.Windows.Thickness]::new(0, 7, 0, 0)
                [void] $stack.Children.Add($iconGrid)
                [void] $stack.Children.Add($label)
                $button.Content = $stack
            }
            [void] $itemsPanel.Children.Add($button)
            [void] $script:visibleButtons.Add($button)

            $cachePath = $null
            try {
                $cacheParameters = @{
                    CachePath  = $script:activeConfiguration.Cache.Path
                    SourcePath = $item.FullPath
                    PixelSize  = 64
                }
                $cachePath = Get-LaunchTreeIconCachePath @cacheParameters
                $cachedIcon = Get-LaunchTreeCachedIcon -LiteralPath $cachePath
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
                $null = Write-LaunchTreeEvent @eventParameters
                Write-Verbose -Message $cacheReadError.Exception.Message
            }

            if (-not $image.Source -and $CapturePath) {
                try {
                    $image.Source = [LaunchTree.NativeIcon]::Get($item.FullPath, 64)
                    $placeholder.Visibility = [System.Windows.Visibility]::Collapsed
                    if ($cachePath) {
                        Save-LaunchTreeCachedIcon -Image $image.Source -LiteralPath $cachePath
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
                    $null = Write-LaunchTreeEvent @eventParameters
                    Write-Verbose -Message $iconError.Exception.Message
                }
            } elseif (-not $image.Source) {
                $job = [PSCustomObject] @{
                    Task        = [LaunchTree.NativeIcon]::GetAsync($item.FullPath, 64)
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
                    $launchResult = Invoke-LaunchTreeLaunchItem @launchParameters
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
            $emptyText.Text = if ($isSearching -and $menuFolders.Count -gt 0) {
                'Matching folders are shown as tabs'
            } elseif ($isSearching) {
                'No matching items'
            } elseif ($useTabbedListLayout -and $menuFolders.Count -gt 0) {
                'Select a folder tab'
            } else {
                'This folder is empty'
            }
            $emptyText.Foreground = $secondaryBrush
            $emptyText.FontSize = 16
            $emptyText.Margin = [System.Windows.Thickness]::new(24, 60, 24, 24)
            [void] $itemsPanel.Children.Add($emptyText)
        }

        $visibleCount = if ($useTabbedListLayout) {
            $tabbedContent.VisibleCount
        } else {
            $candidateItems.Count
        }
        $statusText.Text = if ($isSearching) {
            '{0} results across all Start Entries' -f $visibleCount
        } else {
            '{0} items' -f $visibleCount
        }
        $timerParameters = @{
            Timer       = $iconTimer
            IconJobs    = $script:iconJobs
            CapturePath = $CapturePath
        }
        $null = Invoke-LaunchTreeIconTimer @timerParameters
        $interactionStopwatch.Stop()
        $performanceParameters = @{
            Configuration = $script:activeConfiguration
            Metric        = 'Interaction'
            Value         = $interactionStopwatch.Elapsed.TotalMilliseconds
        }
        $null = Write-LaunchTreePerformanceEvent @performanceParameters
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
                        Save-LaunchTreeCachedIcon @saveCacheParameters
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
                        $null = Write-LaunchTreeEvent @eventParameters
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
                $null = Write-LaunchTreeEvent @eventParameters
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
                $nextConfiguration = Get-LaunchTreeConfiguration @configurationParameters
                $resolveParameters = @{
                    EntryId            = [guid] $activation.EntryId
                    ManagedRoot        = $nextConfiguration.ManagedRoot
                    GeneratedStatePath = [string] $activation.GeneratedStatePath
                }
                $nextEntry = Resolve-LaunchTreeEntry @resolveParameters
                $nextSnapshot = Get-LaunchTreeContentSnapshot -Configuration $nextConfiguration
                if (@($nextSnapshot.HealthFindings | Where-Object Severity -eq 'Error').Count -gt 0) {
                    throw [System.InvalidOperationException]::new(
                        'The requested Entry Root is unhealthy.'
                    )
                }

                $script:activeConfiguration = $nextConfiguration
                $script:activeSnapshot = $nextSnapshot
                $navigationParameters = @{
                    Action              = 'ActivateEntry'
                    EntryName           = $script:activeEntryName
                    CurrentRelativePath = $script:currentRelativePath
                    ActivatedEntryName  = $nextEntry.Name
                }
                $navigationState = Get-LaunchTreeNavigationState @navigationParameters
                $script:activeEntryName = $navigationState.EntryName
                $script:currentRelativePath = $navigationState.RelativePath
                $title.Text = $nextEntry.Name
                $window.Title = $nextEntry.Name
                $backButton.IsEnabled = $navigationState.BackEnabled
                if ($navigationState.ClearSearch -and
                    -not [string]::IsNullOrWhiteSpace($searchBox.Text)) {
                    $searchBox.Text = ''
                } else {
                    & $renderItems
                }
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
        $navigationParameters = @{
            Action              = 'Back'
            EntryName           = $script:activeEntryName
            CurrentRelativePath = $script:currentRelativePath
        }
        $navigationState = Get-LaunchTreeNavigationState @navigationParameters
        $script:activeEntryName = $navigationState.EntryName
        $script:currentRelativePath = $navigationState.RelativePath
        $backButton.IsEnabled = $navigationState.BackEnabled
        if ($navigationState.ClearSearch -and
            -not [string]::IsNullOrWhiteSpace($searchBox.Text)) {
            $searchBox.Text = ''
        } else {
            & $renderItems
        }
    })
    $folderTabs.Add_SelectionChanged({
        if (-not $useTabbedListLayout -or $script:isRenderingFolderTabs) {
            return
        }
        $selectedTab = $folderTabs.SelectedItem
        if (-not $selectedTab -or -not $selectedTab.Tag) {
            return
        }

        $navigationParameters = @{
            Action              = 'SelectFolder'
            EntryName           = $script:activeEntryName
            CurrentRelativePath = $script:currentRelativePath
            Folder              = $selectedTab.Tag
        }
        $navigationState = Get-LaunchTreeNavigationState @navigationParameters
        $script:activeEntryName = $navigationState.EntryName
        $script:currentRelativePath = $navigationState.RelativePath
        $title.Text = $navigationState.EntryName
        $window.Title = $navigationState.EntryName
        $backButton.IsEnabled = $navigationState.BackEnabled
        if ($navigationState.ClearSearch -and
            -not [string]::IsNullOrWhiteSpace($searchBox.Text)) {
            $searchBox.Text = ''
        } else {
            & $renderItems
        }
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
        ) -and $script:visibleButtons.Count -gt 0 -and
            (-not $useTabbedListLayout -or -not $folderTabs.IsKeyboardFocusWithin)) {
            $currentIndex = -1
            for ($index = 0; $index -lt $script:visibleButtons.Count; $index++) {
                if ($script:visibleButtons[$index].IsKeyboardFocused) {
                    $currentIndex = $index
                    break
                }
            }
            $columns = if ($useTabbedListLayout) {
                1
            } else {
                [Math]::Max(1, [int] [Math]::Floor($itemsPanel.ActualWidth / 132))
            }
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
            $null = Write-LaunchTreePerformanceEvent @performanceParameters
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
        $timerParameters = @{
            Timer       = $iconTimer
            IconJobs    = $script:iconJobs
            CapturePath = $CapturePath
        }
        $null = Invoke-LaunchTreeIconTimer @timerParameters
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
            Save-LaunchTreeVisual -Visual $rootBorder -LiteralPath $CapturePath
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
        $null = Write-LaunchTreePerformanceEvent @performanceParameters
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
                Save-LaunchTreePreference @preferenceParameters
            } catch {
                $preferenceError = $_
                Write-Verbose -Message $preferenceError.Exception.Message
            }
        }
    })

    [void] $window.ShowDialog()
}