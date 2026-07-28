function Get-LaunchTreeDefaultConfiguration {
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
        $PreferencePath = Join-Path -Path $roamingRoot -ChildPath 'LaunchTree.preferences.json'
    }

    [ordered] @{
        SchemaVersion    = 1
        VendorName       = $VendorName
        ManagedRoot      = Join-Path -Path $programDataRoot -ChildPath 'LaunchTree'
        PersonalRoot     = Join-Path -Path $roamingRoot -ChildPath 'LaunchTree'
        MaximumDepth     = 5
        LauncherHost     = 'WindowsPowerShell'
        SortOrder        = 'NameAscending'
        CloseAfterLaunch = $true
        Cache            = [ordered] @{
            Path           = Join-Path -Path $localRoot -ChildPath 'LaunchTree\Cache\v1'
            MaximumSizeMB  = 64
            MaximumAgeDays = 30
        }
        Diagnostics      = [ordered] @{
            LogName             = 'LaunchTree'
            SourceName          = 'LaunchTree'
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