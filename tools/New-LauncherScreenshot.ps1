[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $Path,

    [Parameter()]
    [ValidateSet('Grid', 'TabbedList')]
    [string] $LauncherLayout = 'TabbedList'
)

$ErrorActionPreference = 'Stop'
if (-not $PSBoundParameters.ContainsKey('Path')) {
    $layoutFileName = if ($LauncherLayout -eq 'TabbedList') {
        'launcher-tabbed-list.png'
    } else {
        'launcher-grid.png'
    }
    $Path = Join-Path $PSScriptRoot "../docs/images/wpf/$layoutFileName"
}
$repositoryRoot = Split-Path -Path $PSScriptRoot -Parent
$moduleManifest = Get-ChildItem -LiteralPath (
    Join-Path $repositoryRoot 'output/module/LaunchTree'
) -Recurse -Filter 'LaunchTree.psd1' |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1
if (-not $moduleManifest) {
    throw 'Build the module before generating a Launcher screenshot.'
}
$moduleRootScript = Join-Path $moduleManifest.DirectoryName 'LaunchTree.psm1'
$latestSourceFile = Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'source') `
    -Recurse -File |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1
if (-not (Test-Path -LiteralPath $moduleRootScript -PathType Leaf) -or
    (Get-Item -LiteralPath $moduleRootScript).LastWriteTimeUtc -lt
        $latestSourceFile.LastWriteTimeUtc) {
    throw 'Build the module after the latest source change before capturing the Launcher.'
}

$fixtureRoot = Join-Path $env:TEMP ('LaunchTree-capture-' + [guid]::NewGuid().ToString('N'))
$managedRoot = Join-Path $fixtureRoot 'Managed'
$personalRoot = Join-Path $fixtureRoot 'Personal'
$configurationPath = Join-Path $fixtureRoot 'LaunchTree.json'
$outputPath = [IO.Path]::GetFullPath($Path)
$originalAppData = $env:APPDATA
$originalLocalAppData = $env:LOCALAPPDATA

try {
    $env:APPDATA = Join-Path $fixtureRoot 'AppData'
    $env:LOCALAPPDATA = Join-Path $fixtureRoot 'LocalAppData'
    $entertainment = New-Item -Path (Join-Path $managedRoot 'Entertainment') -ItemType Directory -Force
    $media = New-Item -Path (Join-Path $entertainment.FullName 'Media tools') -ItemType Directory
    # Enough Menu Folders that the tab strip overflows and must scroll.
    foreach ($folderName in 'Games', 'Photo editing', 'Streaming services',
        'Productivity suites', 'Video conferencing') {
        $null = New-Item -Path (Join-Path $entertainment.FullName $folderName) -ItemType Directory
    }
    $null = New-Item -Path (Join-Path $managedRoot 'Work essentials') -ItemType Directory
    $personalEntry = New-Item -Path (Join-Path $personalRoot 'Entertainment') -ItemType Directory -Force

    'Games, media, and creative tools.' |
        Set-Content -LiteralPath (Join-Path $entertainment.FullName 'description.txt') -Encoding UTF8
    'Audio and video utilities.' |
        Set-Content -LiteralPath (Join-Path $media.FullName 'description.txt') -Encoding UTF8

    $shell = New-Object -ComObject WScript.Shell
    try {
        $linkDefinitions = @(
            @{
                Path        = Join-Path $entertainment.FullName 'Paint.lnk'
                Target      = Join-Path $env:SystemRoot 'System32\mspaint.exe'
                Description = 'Create and edit pictures.'
            }
            @{
                Path        = Join-Path $entertainment.FullName 'Notepad.lnk'
                Target      = Join-Path $env:SystemRoot 'System32\notepad.exe'
                Description = 'Write a quick note.'
            }
            @{
                Path        = Join-Path $media.FullName 'Media Player.lnk'
                Target      = Join-Path $env:ProgramFiles 'Windows Media Player\wmplayer.exe'
                Description = 'Play music and video.'
            }
        )
        foreach ($definition in $linkDefinitions) {
            $shortcut = $shell.CreateShortcut($definition.Path)
            try {
                $shortcut.TargetPath = $definition.Target
                $shortcut.Description = $definition.Description
                $shortcut.Save()
            } finally {
                [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut)
            }
        }
    } finally {
        [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
    }

    @('[InternetShortcut]', 'URL=https://www.xbox.com/') |
        Set-Content -LiteralPath (Join-Path $entertainment.FullName 'Xbox.url') -Encoding ASCII
    @('[InternetShortcut]', 'URL=https://www.spotify.com/') |
        Set-Content -LiteralPath (Join-Path $personalEntry.FullName 'Spotify.url') -Encoding ASCII

    [ordered] @{
        SchemaVersion    = 1
        ManagedRoot      = $managedRoot
        PersonalRoot     = $personalRoot
        MaximumDepth     = 5
        LauncherHost     = 'PowerShell7'
        LauncherLayout   = $LauncherLayout
        DefaultSortOrder = 'NameAscending'
        CloseAfterLaunch = $true
    } | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath $configurationPath -Encoding UTF8

    $outputDirectory = Split-Path -Path $outputPath -Parent
    $null = New-Item -Path $outputDirectory -ItemType Directory -Force

    Import-Module -Name $moduleManifest.FullName -Force -ErrorAction Stop
    $effectiveConfiguration = Get-LaunchTreeConfiguration `
        -ConfigurationPath $configurationPath
    if ($effectiveConfiguration.LauncherLayout -ne $LauncherLayout) {
        throw "Built module did not load LauncherLayout '$LauncherLayout'."
    }
    $showParameters = @{
        EntryName         = 'Entertainment'
        ConfigurationPath = $configurationPath
        CapturePath       = $outputPath
    }
    Show-LaunchTree @showParameters

    Add-Type -AssemblyName System.Drawing
    $bitmap = [Drawing.Bitmap]::new($outputPath)
    try {
        if ($bitmap.Width -lt 520 -or $bitmap.Height -lt 420) {
            throw "Launcher capture is too small: $($bitmap.Width)x$($bitmap.Height)."
        }
        if ($LauncherLayout -eq 'TabbedList' -and $bitmap.Width -ge $bitmap.Height) {
            throw 'TabbedList capture must use the expected tall first-run layout.'
        }
        if ($LauncherLayout -eq 'Grid' -and $bitmap.Width -le $bitmap.Height) {
            throw 'Grid capture must use the expected wide first-run layout.'
        }

        $colors = [Collections.Generic.HashSet[int]]::new()
        $stepX = [Math]::Max(1, [int] ($bitmap.Width / 25))
        $stepY = [Math]::Max(1, [int] ($bitmap.Height / 20))
        for ($x = 0; $x -lt $bitmap.Width; $x += $stepX) {
            for ($y = 0; $y -lt $bitmap.Height; $y += $stepY) {
                [void] $colors.Add($bitmap.GetPixel($x, $y).ToArgb())
            }
        }
        $minimumSampleColors = if ($LauncherLayout -eq 'TabbedList') { 8 } else { 12 }
        if ($colors.Count -lt $minimumSampleColors) {
            throw "Launcher capture has insufficient pixel diversity: $($colors.Count)."
        }

        [PSCustomObject] @{
            Path         = $outputPath
            Width        = $bitmap.Width
            Height       = $bitmap.Height
            SampleColors = $colors.Count
            FileSize     = (Get-Item -LiteralPath $outputPath).Length
        }
    } finally {
        $bitmap.Dispose()
    }
} finally {
    $env:APPDATA = $originalAppData
    $env:LOCALAPPDATA = $originalLocalAppData
    Remove-Module -Name LaunchTree -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}