function Get-StartMenuFolderDefaultConfiguration {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseOutputTypeCorrectly',
        '',
        Justification = 'The ordered literal returns the declared OrderedDictionary type.'
    )]
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $VendorName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationPath,

        [Parameter()]
        [AllowNull()]
        [string] $PreferencePath
    )

    $programDataRoot = Join-Path -Path $env:ProgramData -ChildPath $VendorName
    $roamingRoot = Join-Path -Path $env:APPDATA -ChildPath $VendorName
    $localRoot = Join-Path -Path $env:LOCALAPPDATA -ChildPath $VendorName

    if ([string]::IsNullOrWhiteSpace($PreferencePath)) {
        $PreferencePath = Join-Path -Path $roamingRoot -ChildPath 'StartMenuFolders.preferences.json'
    }

    [ordered] @{
        SchemaVersion    = 1
        VendorName       = $VendorName
        ManagedRoot      = Join-Path -Path $programDataRoot -ChildPath 'StartMenuFolders'
        PersonalRoot     = Join-Path -Path $roamingRoot -ChildPath 'StartMenuFolders'
        MaximumDepth     = 5
        LauncherHost     = 'WindowsPowerShell'
        SortOrder        = 'NameAscending'
        CloseAfterLaunch = $true
        Cache            = [ordered] @{
            Path           = Join-Path -Path $localRoot -ChildPath 'StartMenuFolders\Cache\v1'
            MaximumSizeMB  = 64
            MaximumAgeDays = 30
        }
        Diagnostics      = [ordered] @{
            LogName             = 'StartMenuFolders'
            SourceName          = 'StartMenuFolders'
            MaximumLogSizeMB    = 25
            TargetRetentionDays = 30
        }
        Window           = [ordered] @{
            Width  = $null
            Height = $null
            Left   = $null
            Top    = $null
        }
        ConfigurationPath = $ConfigurationPath
        PreferencePath    = $PreferencePath
    }
}