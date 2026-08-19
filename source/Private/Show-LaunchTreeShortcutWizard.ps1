function Show-LaunchTreeShortcutWizard {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject] $Configuration,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject] $Theme,

        [Parameter()]
        [AllowNull()]
        [object] $Owner,

        [Parameter()]
        [AllowNull()]
        [string] $InitialPath
    )

    Initialize-LaunchTreeWpf

    $runtimeContext = Get-LaunchTreeRuntimeContext
    $launcherHostPath = if ($runtimeContext.LauncherIsExecutable) {
        ''
    } else {
        Get-LaunchTreeLauncherHostPath -LauncherHost $Configuration.LauncherHost
    }

    $state = [PSCustomObject] @{
        Step       = 1
        Definition = $null
        ResultPath = $null
    }

    $wizard = [System.Windows.Window]::new()
    $wizard.Title = 'Create a LaunchTree shortcut'
    $wizard.Icon = Get-LaunchTreeApplicationIcon
    $wizard.WindowStyle = [System.Windows.WindowStyle]::None
    $wizard.ResizeMode = [System.Windows.ResizeMode]::CanResizeWithGrip
    $wizard.ShowInTaskbar = $false
    $wizard.Width = 640
    $wizard.Height = 480
    $wizard.MinWidth = 560
    $wizard.MinHeight = 440
    $wizard.Background = $Theme.Window
    $wizard.Foreground = $Theme.Foreground
    $wizard.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe UI Variable Text')
    $wizard.FontSize = 14
    $wizard.UseLayoutRounding = $true
    $wizard.SnapsToDevicePixels = $true
    if ($Owner) {
        $wizard.Owner = $Owner
        $wizard.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
    } else {
        $wizard.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
    }

    $windowChrome = [System.Windows.Shell.WindowChrome]::new()
    $windowChrome.CaptionHeight = 0
    $windowChrome.CornerRadius = [System.Windows.CornerRadius]::new(0)
    $windowChrome.GlassFrameThickness = [System.Windows.Thickness]::new(0)
    $windowChrome.ResizeBorderThickness = [System.Windows.Thickness]::new(4)
    $windowChrome.UseAeroCaptionButtons = $false
    [System.Windows.Shell.WindowChrome]::SetWindowChrome($wizard, $windowChrome)

    $rootBorder = [System.Windows.Controls.Border]::new()
    $rootBorder.BorderBrush = $Theme.Border
    $rootBorder.BorderThickness = [System.Windows.Thickness]::new(1)
    $rootBorder.CornerRadius = [System.Windows.CornerRadius]::new(8)
    $rootBorder.Background = $Theme.Window
    $wizard.Content = $rootBorder

    $rootGrid = [System.Windows.Controls.Grid]::new()
    foreach ($height in @(
            [System.Windows.GridLength]::Auto
            [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
            [System.Windows.GridLength]::Auto
        )) {
        $rowDefinition = [System.Windows.Controls.RowDefinition]::new()
        $rowDefinition.Height = $height
        [void] $rootGrid.RowDefinitions.Add($rowDefinition)
    }
    $rootBorder.Child = $rootGrid

    $chromeButtonStyle = [System.Windows.Markup.XamlReader]::Parse(@"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
       xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="Button">
  <Setter Property="Background" Value="Transparent" />
  <Setter Property="Foreground" Value="$( $Theme.ForegroundColor )" />
  <Setter Property="BorderThickness" Value="0" />
  <Setter Property="Padding" Value="6" />
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="Button">
        <Border x:Name="Root" Background="{TemplateBinding Background}" CornerRadius="6"
                Padding="{TemplateBinding Padding}">
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True">
            <Setter TargetName="Root" Property="Background" Value="$( $Theme.HoverColor )" />
            <Setter Property="Foreground" Value="$( $Theme.HoverForegroundColor )" />
          </Trigger>
          <Trigger Property="IsPressed" Value="True">
            <Setter TargetName="Root" Property="Background" Value="$( $Theme.PressedColor )" />
            <Setter Property="Foreground" Value="$( $Theme.PressedForegroundColor )" />
          </Trigger>
          <Trigger Property="IsKeyboardFocused" Value="True">
            <Setter TargetName="Root" Property="BorderBrush" Value="$( $Theme.AccentColor )" />
            <Setter TargetName="Root" Property="BorderThickness" Value="2" />
          </Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>
"@)

    $commandButtonStyle = [System.Windows.Markup.XamlReader]::Parse(@"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
       xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="Button">
  <Setter Property="Background" Value="$( $Theme.SurfaceColor )" />
  <Setter Property="Foreground" Value="$( $Theme.ForegroundColor )" />
  <Setter Property="Height" Value="32" />
  <Setter Property="MinWidth" Value="92" />
  <Setter Property="Margin" Value="8,0,0,0" />
  <Setter Property="Padding" Value="14,0,14,0" />
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="Button">
        <Border x:Name="Root" Background="{TemplateBinding Background}" CornerRadius="6"
                BorderBrush="$( $Theme.BorderColor )" BorderThickness="1"
                Padding="{TemplateBinding Padding}">
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True">
            <Setter TargetName="Root" Property="Background" Value="$( $Theme.HoverColor )" />
            <Setter Property="Foreground" Value="$( $Theme.HoverForegroundColor )" />
          </Trigger>
          <Trigger Property="IsPressed" Value="True">
            <Setter TargetName="Root" Property="Background" Value="$( $Theme.PressedColor )" />
            <Setter Property="Foreground" Value="$( $Theme.PressedForegroundColor )" />
          </Trigger>
          <Trigger Property="IsKeyboardFocused" Value="True">
            <Setter TargetName="Root" Property="BorderBrush" Value="$( $Theme.AccentColor )" />
            <Setter TargetName="Root" Property="BorderThickness" Value="2" />
          </Trigger>
          <Trigger Property="IsEnabled" Value="False">
            <Setter Property="Opacity" Value="0.45" />
          </Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>
"@)

    $newHeading = {
        param([string] $Text)

        $block = [System.Windows.Controls.TextBlock]::new()
        $block.Text = $Text
        $block.FontFamily = [System.Windows.Media.FontFamily]::new(
            'Segoe UI Variable Text Semibold'
        )
        $block.FontSize = 17
        $block.Foreground = $Theme.Foreground
        $block.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
        $block
    }

    $newBodyText = {
        param([string] $Text, [double] $BottomMargin = 16)

        $block = [System.Windows.Controls.TextBlock]::new()
        $block.Text = $Text
        $block.FontSize = 13
        $block.Foreground = $Theme.Secondary
        $block.TextWrapping = [System.Windows.TextWrapping]::Wrap
        $block.Margin = [System.Windows.Thickness]::new(0, 0, 0, $BottomMargin)
        $block
    }

    $newInputBox = {
        param([bool] $IsReadOnly, [int] $Lines = 1)

        $box = [System.Windows.Controls.TextBox]::new()
        $box.BorderThickness = [System.Windows.Thickness]::new(1)
        $box.BorderBrush = $Theme.Border
        $box.Background = $Theme.Surface
        $box.Foreground = $Theme.Foreground
        $box.CaretBrush = $Theme.Accent
        $box.SelectionBrush = $Theme.Accent
        $box.Padding = [System.Windows.Thickness]::new(8, 6, 8, 6)
        $box.IsReadOnly = $IsReadOnly
        if ($Lines -le 1) {
            $box.Height = 32
            $box.VerticalContentAlignment = [System.Windows.VerticalAlignment]::Center
        } else {
            $box.Height = 22 * $Lines
            $box.TextWrapping = [System.Windows.TextWrapping]::Wrap
            $box.VerticalScrollBarVisibility =
                [System.Windows.Controls.ScrollBarVisibility]::Auto
        }
        $box
    }

    $newBrowseRow = {
        param($InputControl, $BrowseButton)

        $grid = [System.Windows.Controls.Grid]::new()
        foreach ($width in @(
                [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
                [System.Windows.GridLength]::Auto
            )) {
            $columnDefinition = [System.Windows.Controls.ColumnDefinition]::new()
            $columnDefinition.Width = $width
            [void] $grid.ColumnDefinitions.Add($columnDefinition)
        }
        [System.Windows.Controls.Grid]::SetColumn($InputControl, 0)
        [System.Windows.Controls.Grid]::SetColumn($BrowseButton, 1)
        [void] $grid.Children.Add($InputControl)
        [void] $grid.Children.Add($BrowseButton)
        $grid
    }

    $header = [System.Windows.Controls.Grid]::new()
    $header.Background = [System.Windows.Media.Brushes]::Transparent
    $header.Margin = [System.Windows.Thickness]::new(6, 2, 6, 2)
    $header.ToolTip = 'Drag to move the window'
    foreach ($width in @(
            [System.Windows.GridLength]::Auto
            [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
            [System.Windows.GridLength]::Auto
            [System.Windows.GridLength]::Auto
        )) {
        $columnDefinition = [System.Windows.Controls.ColumnDefinition]::new()
        $columnDefinition.Width = $width
        [void] $header.ColumnDefinitions.Add($columnDefinition)
    }
    [System.Windows.Controls.Grid]::SetRow($header, 0)
    [void] $rootGrid.Children.Add($header)

    $headerTitle = [System.Windows.Controls.TextBlock]::new()
    $headerTitle.Text = 'Create a LaunchTree shortcut'
    $headerTitle.FontFamily = [System.Windows.Media.FontFamily]::new(
        'Segoe UI Variable Text Semibold'
    )
    $headerTitle.FontSize = 13
    $headerTitle.Foreground = $Theme.Foreground
    $headerTitle.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $headerTitle.Margin = [System.Windows.Thickness]::new(12, 0, 0, 0)
    [System.Windows.Controls.Grid]::SetColumn($headerTitle, 0)
    [void] $header.Children.Add($headerTitle)

    $stepCaption = [System.Windows.Controls.TextBlock]::new()
    $stepCaption.FontSize = 12
    $stepCaption.Foreground = $Theme.Secondary
    $stepCaption.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $stepCaption.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
    [System.Windows.Controls.Grid]::SetColumn($stepCaption, 2)
    [void] $header.Children.Add($stepCaption)

    $dismissButton = [System.Windows.Controls.Button]::new()
    $dismissButton.Content = [char] 0xE8BB
    $dismissButton.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe Fluent Icons')
    $dismissButton.FontSize = 11
    $dismissButton.Width = 28
    $dismissButton.Height = 28
    $dismissButton.ToolTip = 'Close'
    $dismissButton.Style = $chromeButtonStyle
    [System.Windows.Controls.Grid]::SetColumn($dismissButton, 3)
    [void] $header.Children.Add($dismissButton)

    $stepHost = [System.Windows.Controls.Grid]::new()
    $stepHost.Margin = [System.Windows.Thickness]::new(24, 12, 24, 8)
    [System.Windows.Controls.Grid]::SetRow($stepHost, 1)
    [void] $rootGrid.Children.Add($stepHost)

    $pathPanel = [System.Windows.Controls.StackPanel]::new()
    [void] $pathPanel.Children.Add((& $newHeading 'Choose the Entry Root'))
    [void] $pathPanel.Children.Add((& $newBodyText (
                'Enter the folder that holds the shortcuts you want to launch. ' +
                'Its parent folder becomes the Managed Root and its own name becomes ' +
                'the Entry Root the shortcut opens.'
            )))
    $pathBox = & $newInputBox $false
    $pathBox.Text = if ($InitialPath) { $InitialPath } else { '' }
    $browsePathButton = [System.Windows.Controls.Button]::new()
    $browsePathButton.Content = 'Browse...'
    $browsePathButton.Style = $commandButtonStyle
    [void] $pathPanel.Children.Add((& $newBrowseRow $pathBox $browsePathButton))
    $pathExample = & $newBodyText (
        'Example: \\contoso.com\Data\Files\programs opens the programs ' +
        'Entry Root below \\contoso.com\Data\Files.'
    ) 0
    $pathExample.Margin = [System.Windows.Thickness]::new(0, 10, 0, 0)
    [void] $pathPanel.Children.Add($pathExample)
    [void] $stepHost.Children.Add($pathPanel)

    $optionPanel = [System.Windows.Controls.StackPanel]::new()
    $optionPanel.Visibility = [System.Windows.Visibility]::Collapsed
    [void] $optionPanel.Children.Add((& $newHeading 'Choose what happens after a launch'))
    [void] $optionPanel.Children.Add((& $newBodyText (
                'By default the Launcher stays open after an item starts, so more ' +
                'items can be started from the same window.'
            )))
    $closeAfterLaunchBox = [System.Windows.Controls.CheckBox]::new()
    $closeAfterLaunchBox.Content = 'Close the Launcher after starting an item'
    $closeAfterLaunchBox.Foreground = $Theme.Foreground
    $closeAfterLaunchBox.IsChecked = [bool] $Configuration.CloseAfterLaunch
    $closeAfterLaunchBox.Margin = [System.Windows.Thickness]::new(0, 0, 0, 20)
    [void] $optionPanel.Children.Add($closeAfterLaunchBox)
    $managedRootSummary = & $newBodyText '' 6
    $entryNameSummary = & $newBodyText '' 0
    [void] $optionPanel.Children.Add($managedRootSummary)
    [void] $optionPanel.Children.Add($entryNameSummary)
    [void] $stepHost.Children.Add($optionPanel)

    $savePanel = [System.Windows.Controls.StackPanel]::new()
    $savePanel.Visibility = [System.Windows.Visibility]::Collapsed
    [void] $savePanel.Children.Add((& $newHeading 'Save the shortcut'))
    [void] $savePanel.Children.Add((& $newBodyText (
                'Pick the file the shortcut is written to. Browse opens a save ' +
                'dialog so the shortcut can go to the desktop, the Start menu, or ' +
                'any other folder you can write to.'
            )))
    $shortcutBox = & $newInputBox $false
    $browseShortcutButton = [System.Windows.Controls.Button]::new()
    $browseShortcutButton.Content = 'Browse...'
    $browseShortcutButton.Style = $commandButtonStyle
    [void] $savePanel.Children.Add((& $newBrowseRow $shortcutBox $browseShortcutButton))
    $commandLabel = & $newBodyText 'Command line' 4
    $commandLabel.Margin = [System.Windows.Thickness]::new(0, 16, 0, 4)
    [void] $savePanel.Children.Add($commandLabel)
    $commandPreview = & $newInputBox $true 4
    $commandPreview.FontFamily = [System.Windows.Media.FontFamily]::new('Consolas')
    $commandPreview.FontSize = 12
    [void] $savePanel.Children.Add($commandPreview)
    [void] $stepHost.Children.Add($savePanel)

    $footer = [System.Windows.Controls.Grid]::new()
    $footer.Margin = [System.Windows.Thickness]::new(24, 8, 24, 18)
    foreach ($width in @(
            [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
            [System.Windows.GridLength]::Auto
        )) {
        $columnDefinition = [System.Windows.Controls.ColumnDefinition]::new()
        $columnDefinition.Width = $width
        [void] $footer.ColumnDefinitions.Add($columnDefinition)
    }
    [System.Windows.Controls.Grid]::SetRow($footer, 2)
    [void] $rootGrid.Children.Add($footer)

    $statusText = [System.Windows.Controls.TextBlock]::new()
    $statusText.FontSize = 12
    $statusText.Foreground = $Theme.Secondary
    $statusText.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $statusText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $statusText.Margin = [System.Windows.Thickness]::new(0, 0, 12, 0)
    [System.Windows.Controls.Grid]::SetColumn($statusText, 0)
    [void] $footer.Children.Add($statusText)

    $buttonPanel = [System.Windows.Controls.StackPanel]::new()
    $buttonPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    [System.Windows.Controls.Grid]::SetColumn($buttonPanel, 1)
    [void] $footer.Children.Add($buttonPanel)

    $cancelButton = [System.Windows.Controls.Button]::new()
    $cancelButton.Content = 'Cancel'
    $cancelButton.Style = $commandButtonStyle
    $backButton = [System.Windows.Controls.Button]::new()
    $backButton.Content = 'Back'
    $backButton.Style = $commandButtonStyle
    $nextButton = [System.Windows.Controls.Button]::new()
    $nextButton.Content = 'Next'
    $nextButton.Style = $commandButtonStyle
    $nextButton.IsDefault = $true
    foreach ($button in @($cancelButton, $backButton, $nextButton)) {
        [void] $buttonPanel.Children.Add($button)
    }

    $showStatus = {
        param([string] $Text, [bool] $IsError)

        $statusText.Text = $Text
        $statusText.Foreground = if ($IsError) {
            [System.Windows.Media.Brushes]::IndianRed
        } else {
            $Theme.Secondary
        }
    }

    $resolveDefinition = {
        $definitionParameters = @{
            EntryRootPath        = $pathBox.Text
            LauncherHostPath     = $launcherHostPath
            LauncherPath         = $runtimeContext.LauncherPath
            LauncherCommand      = $runtimeContext.LauncherCommand
            LauncherIsExecutable = [bool] $runtimeContext.LauncherIsExecutable
            CloseAfterLaunch     = $closeAfterLaunchBox.IsChecked -eq $true
        }
        $state.Definition = Get-LaunchTreeShortcutDefinition @definitionParameters
    }

    $updateStep = {
        $panels = @($pathPanel, $optionPanel, $savePanel)
        for ($index = 0; $index -lt $panels.Count; $index++) {
            $panels[$index].Visibility = if (($index + 1) -eq $state.Step) {
                [System.Windows.Visibility]::Visible
            } else {
                [System.Windows.Visibility]::Collapsed
            }
        }
        $stepCaption.Text = 'Step {0} of 3' -f $state.Step
        $backButton.IsEnabled = $state.Step -gt 1
        $nextButton.Content = if ($state.Step -eq 3) { 'Create' } else { 'Next' }
        switch ($state.Step) {
            1 { [void] $pathBox.Focus() }
            3 { [void] $shortcutBox.Focus() }
        }
    }

    $browsePathButton.Add_Click({
        $shell = $null
        $folder = $null
        try {
            $shell = New-Object -ComObject Shell.Application
            # BIF_RETURNONLYFSDIRS | BIF_EDITBOX | BIF_NEWDIALOGSTYLE
            $folder = $shell.BrowseForFolder(0, 'Select the Entry Root folder', 0x51)
            if ($folder -and $folder.Self.Path) {
                $pathBox.Text = $folder.Self.Path
            }
        } catch {
            $browseError = $_
            & $showStatus $browseError.Exception.Message $true
        } finally {
            if ($folder) {
                [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($folder)
            }
            if ($shell) {
                [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
            }
        }
    })

    $browseShortcutButton.Add_Click({
        $dialog = [Microsoft.Win32.SaveFileDialog]::new()
        $dialog.Title = 'Save the LaunchTree shortcut'
        $dialog.Filter = 'Shortcut (*.lnk)|*.lnk'
        $dialog.DefaultExt = 'lnk'
        $dialog.AddExtension = $true
        $dialog.OverwritePrompt = $true
        $dialog.FileName = if ($shortcutBox.Text) {
            Split-Path -Path $shortcutBox.Text -Leaf
        } else {
            $state.Definition.FileName
        }
        $dialog.InitialDirectory = if ($shortcutBox.Text) {
            Split-Path -Path $shortcutBox.Text -Parent
        } else {
            [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
        }
        if ($dialog.ShowDialog($wizard)) {
            $shortcutBox.Text = $dialog.FileName
        }
    })

    $nextButton.Add_Click({
        & $showStatus '' $false
        if ($state.Step -eq 1) {
            try {
                & $resolveDefinition
            } catch {
                $definitionError = $_
                & $showStatus $definitionError.Exception.Message $true
                return
            }
            $managedRootSummary.Text = 'Managed Root: {0}' -f $state.Definition.ManagedRoot
            $entryNameSummary.Text = 'Entry Root: {0}' -f $state.Definition.EntryName
            $state.Step = 2
        } elseif ($state.Step -eq 2) {
            try {
                & $resolveDefinition
            } catch {
                $definitionError = $_
                & $showStatus $definitionError.Exception.Message $true
                $state.Step = 1
                & $updateStep
                return
            }
            if ([string]::IsNullOrWhiteSpace($shortcutBox.Text)) {
                $shortcutBox.Text = Join-Path -Path ([Environment]::GetFolderPath(
                        [Environment+SpecialFolder]::DesktopDirectory
                    )) -ChildPath $state.Definition.FileName
            }
            $commandPreview.Text = '{0} {1}' -f $state.Definition.TargetPath,
                $state.Definition.Arguments
            $state.Step = 3
        } else {
            if ([string]::IsNullOrWhiteSpace($shortcutBox.Text)) {
                & $showStatus 'Choose where the shortcut should be saved.' $true
                return
            }
            try {
                $shortcutParameters = @{
                    LiteralPath = $shortcutBox.Text
                    Definition  = $state.Definition
                }
                $state.ResultPath = New-LaunchTreeLauncherShortcut @shortcutParameters
            } catch {
                $shortcutError = $_
                & $showStatus $shortcutError.Exception.Message $true
                return
            }
            $wizard.Close()
            return
        }
        & $updateStep
    })

    $backButton.Add_Click({
        & $showStatus '' $false
        if ($state.Step -gt 1) {
            $state.Step = $state.Step - 1
        }
        & $updateStep
    })

    $cancelButton.Add_Click({ $wizard.Close() })
    $dismissButton.Add_Click({ $wizard.Close() })
    $header.Add_MouseLeftButtonDown({
        param($eventSource, $eventArguments)
        [void] $eventSource
        if ($eventArguments.ButtonState -ne [System.Windows.Input.MouseButtonState]::Pressed) {
            return
        }
        try {
            $wizard.DragMove()
        } catch {
            $dragError = $_
            Write-Verbose -Message $dragError.Exception.Message
        }
    })
    $wizard.Add_PreviewKeyDown({
        param($eventSource, $eventArguments)
        [void] $eventSource
        if ($eventArguments.Key -eq [System.Windows.Input.Key]::Escape) {
            $wizard.Close()
            $eventArguments.Handled = $true
        }
    })

    & $updateStep
    [void] $wizard.ShowDialog()

    $state.ResultPath
}
