function Get-LaunchTreeConfiguration {
    <#
        .SYNOPSIS
            Reads the effective LaunchTree configuration.

        .DESCRIPTION
            Combines validated machine configuration with allowed user
            preferences and safe defaults. The command is read-only and returns
            structured Health Findings for values that require fallback.

        .PARAMETER VendorName
            Specifies the directory-name segment used to derive default paths.

        .PARAMETER ConfigurationPath
            Specifies an alternate machine configuration JSON file to read.

        .PARAMETER ManagedRoot
            Overrides the Managed Root that supplies Entry Roots. The value
            takes precedence over the machine configuration file.

        .PARAMETER PersonalRoot
            Overrides the Personal Root merged into matching Entry Roots. The
            value takes precedence over the machine configuration file.

        .PARAMETER PreferencePath
            Specifies an alternate user preference JSON file to read.

        .PARAMETER CloseAfterLaunch
            Overrides whether the Launcher closes after a Launch Item starts.
            The value takes precedence over the machine configuration file and
            the user preference file.

        .EXAMPLE
            Get-LaunchTreeConfiguration

            Returns effective settings from the default machine and user paths.

        .EXAMPLE
            Get-LaunchTreeConfiguration -ConfigurationPath C:\Config\LaunchTree.json

            Reads machine settings from an explicitly supplied file.

        .EXAMPLE
            Get-LaunchTreeConfiguration -ManagedRoot C:\Menus\Contoso

            Resolves settings against a Managed Root supplied for this call.
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

    $healthFindings = [System.Collections.Generic.List[object]]::new()
    $configurationIsValid = $true
    $skipPreferences = $false
    if (-not $PSBoundParameters.ContainsKey('ConfigurationPath')) {
        $vendorProgramData = Join-Path -Path $env:ProgramData -ChildPath $VendorName
        $ConfigurationPath = Join-Path -Path $vendorProgramData -ChildPath 'LaunchTree.json'
    }

    $machineData = $null
    if (Test-Path -LiteralPath $ConfigurationPath -PathType Leaf) {
        $machineResult = Import-LaunchTreeJson -LiteralPath $ConfigurationPath
        if ($machineResult.Succeeded) {
            $machineData = $machineResult.Value
        } else {
            $findingParameters = @{
                Code     = 'ConfigurationInvalidJson'
                Severity = 'Warning'
                Message  = $machineResult.Message
                Path     = $ConfigurationPath
            }
            [void] $healthFindings.Add((New-LaunchTreeHealthFinding @findingParameters))
        }
    }

    if ($machineData -and $machineData.PSObject.Properties['SchemaVersion']) {
        $schemaVersion = $machineData.SchemaVersion
        if (($schemaVersion -is [int]) -or ($schemaVersion -is [long])) {
            if ([int] $schemaVersion -ne 1) {
                $findingParameters = @{
                    Code     = 'ConfigurationSchemaUnsupported'
                    Severity = 'Error'
                    Message  = "Unsupported configuration schema version '$schemaVersion'."
                    Path     = $ConfigurationPath
                }
                [void] $healthFindings.Add(
                    (New-LaunchTreeHealthFinding @findingParameters)
                )
                $configurationIsValid = $false
                $skipPreferences = $true
                $machineData = $null
            }
        } else {
            $findingParameters = @{
                Code     = 'ConfigurationSchemaInvalid'
                Severity = 'Warning'
                Message  = 'SchemaVersion must be an integer. Defaults were used.'
                Path     = $ConfigurationPath
            }
            [void] $healthFindings.Add((New-LaunchTreeHealthFinding @findingParameters))
            $machineData = $null
        }
    }

    $effectiveVendorName = $VendorName
    if ($machineData -and $machineData.PSObject.Properties['VendorName']) {
        $candidateVendorName = [string] $machineData.VendorName
        $invalidCharacters = [IO.Path]::GetInvalidFileNameChars()
        $isInvalidVendorName = [string]::IsNullOrWhiteSpace($candidateVendorName) -or
            [IO.Path]::IsPathRooted($candidateVendorName) -or
            $candidateVendorName -in @('.', '..') -or
            $candidateVendorName.Contains('\') -or
            $candidateVendorName.Contains('/') -or
            $candidateVendorName.IndexOfAny($invalidCharacters) -ge 0

        if ($isInvalidVendorName) {
            $findingParameters = @{
                Code     = 'VendorNameInvalid'
                Severity = 'Warning'
                Message  = 'VendorName is not a valid directory-name segment.'
                Path     = $ConfigurationPath
            }
            [void] $healthFindings.Add((New-LaunchTreeHealthFinding @findingParameters))
        } else {
            $effectiveVendorName = $candidateVendorName
        }
    }

    $defaultParameters = @{
        VendorName       = $effectiveVendorName
        ConfigurationPath = $ConfigurationPath
        PreferencePath    = $PreferencePath
    }
    $configuration = Get-LaunchTreeDefaultConfiguration @defaultParameters

    if ($machineData) {
        foreach ($rootName in 'ManagedRoot', 'PersonalRoot') {
            if ($machineData.PSObject.Properties[$rootName]) {
                $candidatePath = [Environment]::ExpandEnvironmentVariables(
                    [string] $machineData.$rootName
                )
                if ([IO.Path]::IsPathRooted($candidatePath)) {
                    $configuration[$rootName] = $candidatePath
                } else {
                    $findingParameters = @{
                        Code     = "${rootName}Invalid"
                        Severity = 'Warning'
                        Message  = "$rootName must resolve to an absolute path."
                        Path     = $ConfigurationPath
                    }
                    [void] $healthFindings.Add(
                        (New-LaunchTreeHealthFinding @findingParameters)
                    )
                }
            }
        }

        if ($machineData.PSObject.Properties['MaximumDepth']) {
            $maximumDepth = $machineData.MaximumDepth
            if ((($maximumDepth -is [int]) -or ($maximumDepth -is [long])) -and
                $maximumDepth -ge 1 -and $maximumDepth -le 32) {
                $configuration['MaximumDepth'] = [int] $maximumDepth
            } else {
                $findingParameters = @{
                    Code     = 'MaximumDepthInvalid'
                    Severity = 'Warning'
                    Message  = 'MaximumDepth must be an integer from 1 through 32.'
                    Path     = $ConfigurationPath
                }
                [void] $healthFindings.Add((New-LaunchTreeHealthFinding @findingParameters))
            }
        }

        if ($machineData.PSObject.Properties['LauncherHost']) {
            if ($machineData.LauncherHost -in @('WindowsPowerShell', 'PowerShell7')) {
                $configuration['LauncherHost'] = [string] $machineData.LauncherHost
            } else {
                $findingParameters = @{
                    Code     = 'LauncherHostInvalid'
                    Severity = 'Warning'
                    Message  = 'LauncherHost must be WindowsPowerShell or PowerShell7.'
                    Path     = $ConfigurationPath
                }
                [void] $healthFindings.Add((New-LaunchTreeHealthFinding @findingParameters))
            }
        }

        if ($machineData.PSObject.Properties['LauncherLayout']) {
            if ($machineData.LauncherLayout -in @('Grid', 'TabbedList')) {
                $configuration['LauncherLayout'] = [string] $machineData.LauncherLayout
            } else {
                $findingParameters = @{
                    Code     = 'LauncherLayoutInvalid'
                    Severity = 'Warning'
                    Message  = 'LauncherLayout must be Grid or TabbedList.'
                    Path     = $ConfigurationPath
                }
                [void] $healthFindings.Add((New-LaunchTreeHealthFinding @findingParameters))
            }
        }

        if ($machineData.PSObject.Properties['DefaultSortOrder']) {
            if ($machineData.DefaultSortOrder -in @('NameAscending', 'NameDescending')) {
                $configuration['SortOrder'] = [string] $machineData.DefaultSortOrder
            } else {
                $findingParameters = @{
                    Code     = 'DefaultSortOrderInvalid'
                    Severity = 'Warning'
                    Message  = 'DefaultSortOrder must be NameAscending or NameDescending.'
                    Path     = $ConfigurationPath
                }
                [void] $healthFindings.Add((New-LaunchTreeHealthFinding @findingParameters))
            }
        }

        if ($machineData.PSObject.Properties['CloseAfterLaunch']) {
            if ($machineData.CloseAfterLaunch -is [bool]) {
                $configuration['CloseAfterLaunch'] = $machineData.CloseAfterLaunch
            } else {
                $findingParameters = @{
                    Code     = 'CloseAfterLaunchInvalid'
                    Severity = 'Warning'
                    Message  = 'CloseAfterLaunch must be a Boolean value.'
                    Path     = $ConfigurationPath
                }
                [void] $healthFindings.Add((New-LaunchTreeHealthFinding @findingParameters))
            }
        }

        if ($machineData.PSObject.Properties['Cache'] -and $machineData.Cache) {
            if ($machineData.Cache.PSObject.Properties['MaximumSizeMB']) {
                $maximumSize = $machineData.Cache.MaximumSizeMB
                if ((($maximumSize -is [int]) -or ($maximumSize -is [long])) -and
                    $maximumSize -ge 16 -and $maximumSize -le 256) {
                    $configuration.Cache['MaximumSizeMB'] = [int] $maximumSize
                } else {
                    $findingParameters = @{
                        Code     = 'CacheMaximumSizeInvalid'
                        Severity = 'Warning'
                        Message  = 'Cache.MaximumSizeMB must be an integer from 16 through 256.'
                        Path     = $ConfigurationPath
                    }
                    [void] $healthFindings.Add(
                        (New-LaunchTreeHealthFinding @findingParameters)
                    )
                }
            }
            if ($machineData.Cache.PSObject.Properties['MaximumAgeDays']) {
                $maximumAge = $machineData.Cache.MaximumAgeDays
                if ((($maximumAge -is [int]) -or ($maximumAge -is [long])) -and
                    $maximumAge -ge 1 -and $maximumAge -le 90) {
                    $configuration.Cache['MaximumAgeDays'] = [int] $maximumAge
                } else {
                    $findingParameters = @{
                        Code     = 'CacheMaximumAgeInvalid'
                        Severity = 'Warning'
                        Message  = 'Cache.MaximumAgeDays must be an integer from 1 through 90.'
                        Path     = $ConfigurationPath
                    }
                    [void] $healthFindings.Add(
                        (New-LaunchTreeHealthFinding @findingParameters)
                    )
                }
            }
        }

        if ($machineData.PSObject.Properties['Diagnostics'] -and
            $machineData.Diagnostics) {
            foreach ($nameProperty in @{
                LogName    = 'DiagnosticsLogNameInvalid'
                SourceName = 'DiagnosticsSourceNameInvalid'
            }.GetEnumerator()) {
                if ($machineData.Diagnostics.PSObject.Properties[$nameProperty.Key]) {
                    $candidateName = [string] $machineData.Diagnostics.($nameProperty.Key)
                    if ([string]::IsNullOrWhiteSpace($candidateName)) {
                        $findingParameters = @{
                            Code     = $nameProperty.Value
                            Severity = 'Warning'
                            Message  = "Diagnostics.$($nameProperty.Key) must not be empty."
                            Path     = $ConfigurationPath
                        }
                        [void] $healthFindings.Add(
                            (New-LaunchTreeHealthFinding @findingParameters)
                        )
                    } else {
                        $configuration.Diagnostics[$nameProperty.Key] = $candidateName
                    }
                }
            }

            if ($machineData.Diagnostics.PSObject.Properties['MaximumLogSizeMB']) {
                $maximumLogSize = $machineData.Diagnostics.MaximumLogSizeMB
                if ((($maximumLogSize -is [int]) -or ($maximumLogSize -is [long])) -and
                    $maximumLogSize -ge 1 -and $maximumLogSize -le 128) {
                    $configuration.Diagnostics['MaximumLogSizeMB'] = [int] $maximumLogSize
                } else {
                    $findingParameters = @{
                        Code     = 'DiagnosticsMaximumLogSizeInvalid'
                        Severity = 'Warning'
                        Message  = 'Diagnostics.MaximumLogSizeMB must be an integer from 1 through 128.'
                        Path     = $ConfigurationPath
                    }
                    [void] $healthFindings.Add(
                        (New-LaunchTreeHealthFinding @findingParameters)
                    )
                }
            }

            if ($machineData.Diagnostics.PSObject.Properties['TargetRetentionDays']) {
                $retentionDays = $machineData.Diagnostics.TargetRetentionDays
                if ((($retentionDays -is [int]) -or ($retentionDays -is [long])) -and
                    $retentionDays -ge 1 -and $retentionDays -le 90) {
                    $configuration.Diagnostics['TargetRetentionDays'] = [int] $retentionDays
                } else {
                    $findingParameters = @{
                        Code     = 'DiagnosticsRetentionInvalid'
                        Severity = 'Warning'
                        Message  = 'Diagnostics.TargetRetentionDays must be an integer from 1 through 90.'
                        Path     = $ConfigurationPath
                    }
                    [void] $healthFindings.Add(
                        (New-LaunchTreeHealthFinding @findingParameters)
                    )
                }
            }
        }
    }

    $rootOverrides = [ordered] @{
        ManagedRoot  = $ManagedRoot
        PersonalRoot = $PersonalRoot
    }
    foreach ($rootName in $rootOverrides.Keys) {
        if (-not $PSBoundParameters.ContainsKey($rootName)) {
            continue
        }

        $overridePath = [Environment]::ExpandEnvironmentVariables(
            [string] $rootOverrides[$rootName]
        )
        if (-not [IO.Path]::IsPathRooted($overridePath)) {
            throw [System.ArgumentException]::new(
                "$rootName must resolve to an absolute path.",
                $rootName
            )
        }

        $configuration[$rootName] = $overridePath
    }

    $resolvedPreferencePath = $configuration.PreferencePath
    if (-not $skipPreferences -and
        (Test-Path -LiteralPath $resolvedPreferencePath -PathType Leaf)) {
        $preferenceResult = Import-LaunchTreeJson -LiteralPath $resolvedPreferencePath
        if (-not $preferenceResult.Succeeded) {
            $findingParameters = @{
                Code     = 'PreferenceInvalidJson'
                Severity = 'Warning'
                Message  = $preferenceResult.Message
                Path     = $resolvedPreferencePath
            }
            [void] $healthFindings.Add((New-LaunchTreeHealthFinding @findingParameters))
        } else {
            $preferenceData = $preferenceResult.Value
            $preferenceSchemaIsValid = $true
            if ($preferenceData.PSObject.Properties['SchemaVersion']) {
                $preferenceSchema = $preferenceData.SchemaVersion
                $preferenceSchemaIsValid = (
                    (($preferenceSchema -is [int]) -or ($preferenceSchema -is [long])) -and
                    ([int] $preferenceSchema -eq 1)
                )
            }

            if (-not $preferenceSchemaIsValid) {
                $findingParameters = @{
                    Code     = 'PreferenceSchemaInvalid'
                    Severity = 'Warning'
                    Message  = 'User preference schema version is unsupported.'
                    Path     = $resolvedPreferencePath
                }
                [void] $healthFindings.Add((New-LaunchTreeHealthFinding @findingParameters))
            } else {
                if ($preferenceData.PSObject.Properties['SortOrder'] -and
                    $preferenceData.SortOrder -in @('NameAscending', 'NameDescending')) {
                    $configuration['SortOrder'] = [string] $preferenceData.SortOrder
                }
                if ($preferenceData.PSObject.Properties['CloseAfterLaunch'] -and
                    $preferenceData.CloseAfterLaunch -is [bool]) {
                    $configuration['CloseAfterLaunch'] = $preferenceData.CloseAfterLaunch
                }
                if ($preferenceData.PSObject.Properties['Window'] -and $preferenceData.Window) {
                    foreach ($windowProperty in 'Width', 'Height', 'Left', 'Top') {
                        if ($preferenceData.Window.PSObject.Properties[$windowProperty]) {
                            $windowValue = $preferenceData.Window.$windowProperty
                            if ($null -eq $windowValue -or
                                ($windowValue -is [int]) -or
                                ($windowValue -is [long]) -or
                                ($windowValue -is [double])) {
                                $configuration.Window[$windowProperty] = $windowValue
                            }
                        }
                    }
                }
            }
        }
    }

    if ($PSBoundParameters.ContainsKey('CloseAfterLaunch')) {
        $configuration['CloseAfterLaunch'] = [bool] $CloseAfterLaunch
    }

    $result = [PSCustomObject] @{
        PSTypeName        = 'LaunchTree.Configuration'
        IsValid           = $configurationIsValid
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
        HealthFindings    = [object[]] $healthFindings
    }

    foreach ($finding in $healthFindings) {
        $eventParameters = @{
            Configuration = $result
            EventId       = 1001
            Level         = if ($finding.Severity -eq 'Error') { 'Error' } else { 'Warning' }
            Operation     = 'Configuration'
            Message       = [string] $finding.Message
            Path          = [string] $finding.Path
            ErrorCode     = [string] $finding.Code
        }
        $null = Write-LaunchTreeEvent @eventParameters
    }

    $result
}