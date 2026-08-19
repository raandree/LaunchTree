function Get-LaunchTreeConfiguration {
    <#
        .SYNOPSIS
            Returns the effective LaunchTree configuration without reading JSON.

        .DESCRIPTION
            Replaces the module command in the Minimal single-file script. The
            machine configuration and the user preference file are both JSON,
            which the Minimal delivery deliberately omits, so this override
            returns the built-in defaults with the caller's root overrides
            applied. The result is always valid and carries no Health Finding.

            The returned shape must stay identical to the module command; a
            unit test compares both property sets.

        .PARAMETER VendorName
            Specifies the directory-name segment used to derive default paths.

        .PARAMETER ConfigurationPath
            Accepted for signature compatibility. The file is never read.

        .PARAMETER ManagedRoot
            Overrides the Managed Root that supplies Entry Roots.

        .PARAMETER PersonalRoot
            Overrides the Personal Root merged into matching Entry Roots.

        .PARAMETER PreferencePath
            Accepted for signature compatibility. The file is never read.

        .PARAMETER CloseAfterLaunch
            Overrides whether the Launcher closes after a Launch Item starts.

        .EXAMPLE
            Get-LaunchTreeConfiguration -ManagedRoot C:\Menus\Contoso

            Returns the defaults with the supplied Managed Root applied.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $VendorName = 'LaunchTree',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ManagedRoot,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $PersonalRoot,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $PreferencePath,

        [Parameter()]
        [switch] $CloseAfterLaunch
    )

    if (-not $PSBoundParameters.ContainsKey('ConfigurationPath')) {
        $vendorProgramData = Join-Path -Path $env:ProgramData -ChildPath $VendorName
        $ConfigurationPath = Join-Path -Path $vendorProgramData -ChildPath 'LaunchTree.json'
    }

    $defaultParameters = @{
        VendorName        = $VendorName
        ConfigurationPath = $ConfigurationPath
        PreferencePath    = $PreferencePath
    }
    $configuration = Get-LaunchTreeDefaultConfiguration @defaultParameters

    foreach ($rootName in 'ManagedRoot', 'PersonalRoot') {
        if (-not $PSBoundParameters.ContainsKey($rootName)) {
            continue
        }

        $overridePath = [Environment]::ExpandEnvironmentVariables(
            [string] $PSBoundParameters[$rootName]
        )
        if (-not [IO.Path]::IsPathRooted($overridePath)) {
            throw [System.ArgumentException]::new(
                "$rootName must resolve to an absolute path.",
                $rootName
            )
        }

        $configuration[$rootName] = $overridePath
    }

    if ($PSBoundParameters.ContainsKey('CloseAfterLaunch')) {
        $configuration['CloseAfterLaunch'] = [bool] $CloseAfterLaunch
    }

    [PSCustomObject] @{
        PSTypeName        = 'LaunchTree.Configuration'
        IsValid           = $true
        SchemaVersion     = $configuration.SchemaVersion
        VendorName        = $configuration.VendorName
        ManagedRoot       = $configuration.ManagedRoot
        PersonalRoot      = $configuration.PersonalRoot
        MaximumDepth      = $configuration.MaximumDepth
        LauncherHost      = $configuration.LauncherHost
        LauncherLayout    = $configuration.LauncherLayout
        SortOrder         = $configuration.SortOrder
        CloseAfterLaunch  = $configuration.CloseAfterLaunch
        Cache             = [PSCustomObject] $configuration.Cache
        Diagnostics       = [PSCustomObject] $configuration.Diagnostics
        Window            = [PSCustomObject] $configuration.Window
        ConfigurationPath = $configuration.ConfigurationPath
        PreferencePath    = $configuration.PreferencePath
        HealthFindings    = [object[]] @()
    }
}
