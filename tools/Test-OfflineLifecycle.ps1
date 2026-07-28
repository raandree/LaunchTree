[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $RepositoryRoot = (Split-Path -Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne
    [Threading.ApartmentState]::STA) {
    throw 'Test-OfflineLifecycle.ps1 requires an STA PowerShell host.'
}

$builtModuleRoot = Join-Path $RepositoryRoot 'output\module\LaunchTree'
$builtManifest = Get-ChildItem -LiteralPath $builtModuleRoot -Recurse -Filter (
    'LaunchTree.psd1'
) | Sort-Object FullName -Descending | Select-Object -First 1
if (-not $builtManifest) {
    throw 'Build the module before running the offline lifecycle validator.'
}

$fixture = Join-Path $env:TEMP (
    'LaunchTree-offline-{0}' -f [guid]::NewGuid().ToString('N')
)
$moduleDestination = Join-Path $fixture (
    'Modules\LaunchTree\{0}' -f $builtManifest.Directory.Name
)
$originalLocalAppData = $env:LOCALAPPDATA

try {
    $null = New-Item -Path $moduleDestination -ItemType Directory -Force
    $copyParameters = @{
        Path        = Join-Path $builtManifest.Directory.FullName '*'
        Destination = $moduleDestination
        Recurse     = $true
        Force       = $true
    }
    Copy-Item @copyParameters
    $env:LOCALAPPDATA = Join-Path $fixture 'LocalAppData'

    $copiedManifest = Join-Path $moduleDestination 'LaunchTree.psd1'
    Import-Module $copiedManifest -Force -ErrorAction Stop

    $managedRoot = Join-Path $fixture 'Managed'
    $personalRoot = Join-Path $fixture 'Personal'
    $entryParameters = @{
        Path     = Join-Path $managedRoot 'Entertainment'
        ItemType = 'Directory'
        Force    = $true
    }
    $entry = New-Item @entryParameters
    $nestedParameters = @{
        Path     = Join-Path $entry.FullName 'Media'
        ItemType = 'Directory'
    }
    $nested = New-Item @nestedParameters
    @('[InternetShortcut]', 'URL=https://www.xbox.com/') |
        Set-Content (Join-Path $entry.FullName 'Xbox.url') -Encoding ASCII
    @('[InternetShortcut]', 'URL=https://www.spotify.com/') |
        Set-Content (Join-Path $nested.FullName 'Spotify.url') -Encoding ASCII

    $configurationPath = Join-Path $fixture 'LaunchTree.json'
    $statePath = Join-Path $fixture 'LaunchTree.generated.json'
    $programsPath = Join-Path $fixture 'Programs'
    $capturePath = Join-Path $fixture 'Launcher.png'
    @{
        SchemaVersion = 1
        ManagedRoot   = $managedRoot
        PersonalRoot  = $personalRoot
        MaximumDepth  = 5
        LauncherHost  = 'PowerShell7'
    } | ConvertTo-Json -Depth 4 |
        Set-Content $configurationPath -Encoding UTF8

    $updateParameters = @{
        ConfigurationPath        = $configurationPath
        GeneratedStatePath       = $statePath
        StartMenuPath             = $programsPath
        SkipEventLogRegistration = $true
        Confirm                   = $false
    }
    $update = Update-LaunchTree @updateParameters

    $healthParameters = @{
        ConfigurationPath = $configurationPath
        GeneratedStatePath = $statePath
        StartMenuPath       = $programsPath
        SkipEventLog        = $true
    }
    $health = Test-LaunchTree @healthParameters
    if ($health.Status -ne 'Healthy') {
        throw "Offline health is '$($health.Status)'."
    }

    $showParameters = @{
        EntryName         = 'Entertainment'
        ConfigurationPath = $configurationPath
        CapturePath       = $capturePath
    }
    Show-LaunchTree @showParameters
    if (-not (Test-Path $capturePath -PathType Leaf)) {
        throw 'Offline Launcher capture was not created.'
    }

    $cachePath = (
        Get-LaunchTreeConfiguration -ConfigurationPath $configurationPath
    ).Cache.Path
    $removeParameters = @{
        ConfigurationPath = $configurationPath
        GeneratedStatePath = $statePath
        CachePath           = $cachePath
        SkipEventLog        = $true
        Confirm             = $false
    }
    $remove = Remove-LaunchTree @removeParameters

    if (Test-Path $statePath) {
        throw 'Generated State remains after removal.'
    }
    if (Get-ChildItem $programsPath -Filter '*.lnk' -ErrorAction SilentlyContinue) {
        throw 'Start Entries remain after removal.'
    }
    if (-not (Test-Path $managedRoot -PathType Container)) {
        throw 'The Managed Root was removed.'
    }
    if (-not (Test-Path $configurationPath -PathType Leaf)) {
        throw 'Machine configuration was removed.'
    }

    [PSCustomObject] @{
        ModuleSource       = 'FileCopy'
        ModuleVersion      = $builtManifest.Directory.Name
        UpdateAdded        = $update.Added.Count
        Health             = $health.Status
        CaptureBytes       = (Get-Item $capturePath).Length
        RemovalSucceeded   = $remove.Succeeded
        RuntimeDependencies = 0
    }
} finally {
    $env:LOCALAPPDATA = $originalLocalAppData
    Remove-Module LaunchTree -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}