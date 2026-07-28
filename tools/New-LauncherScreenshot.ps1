[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $Path = (Join-Path $PSScriptRoot '../docs/images/wpf/launcher-default.png')
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Path $PSScriptRoot -Parent
$moduleManifest = Get-ChildItem -LiteralPath (
    Join-Path $repositoryRoot 'output/module/LaunchTree'
) -Recurse -Filter 'LaunchTree.psd1' |
    Sort-Object FullName -Descending |
    Select-Object -First 1
if (-not $moduleManifest) {
    throw 'Build the module before generating a Launcher screenshot.'
}

$fixtureRoot = Join-Path $env:TEMP ('LaunchTree-capture-' + [guid]::NewGuid().ToString('N'))
$managedRoot = Join-Path $fixtureRoot 'Managed'
$personalRoot = Join-Path $fixtureRoot 'Personal'
$configurationPath = Join-Path $fixtureRoot 'LaunchTree.json'
$outputPath = [IO.Path]::GetFullPath($Path)
$originalLocalAppData = $env:LOCALAPPDATA

try {
    $env:LOCALAPPDATA = Join-Path $fixtureRoot 'LocalAppData'
    $entertainment = New-Item -Path (Join-Path $managedRoot 'Entertainment') -ItemType Directory -Force
    $media = New-Item -Path (Join-Path $entertainment.FullName 'Media tools') -ItemType Directory
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
        DefaultSortOrder = 'NameAscending'
        CloseAfterLaunch = $true
    } | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath $configurationPath -Encoding UTF8

    $outputDirectory = Split-Path -Path $outputPath -Parent
    $null = New-Item -Path $outputDirectory -ItemType Directory -Force

    Import-Module -Name $moduleManifest.FullName -Force -ErrorAction Stop
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

        $colors = [Collections.Generic.HashSet[int]]::new()
        $stepX = [Math]::Max(1, [int] ($bitmap.Width / 25))
        $stepY = [Math]::Max(1, [int] ($bitmap.Height / 20))
        for ($x = 0; $x -lt $bitmap.Width; $x += $stepX) {
            for ($y = 0; $y -lt $bitmap.Height; $y += $stepY) {
                [void] $colors.Add($bitmap.GetPixel($x, $y).ToArgb())
            }
        }
        if ($colors.Count -lt 12) {
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
    $env:LOCALAPPDATA = $originalLocalAppData
    Remove-Module -Name LaunchTree -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}