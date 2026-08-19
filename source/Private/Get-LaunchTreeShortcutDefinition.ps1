function Get-LaunchTreeShortcutDefinition {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $EntryRootPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LauncherHostPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LauncherPath,

        [Parameter()]
        [AllowNull()]
        [string] $LauncherCommand,

        [Parameter()]
        [switch] $CloseAfterLaunch
    )

    $expandedPath = [Environment]::ExpandEnvironmentVariables($EntryRootPath).Trim().Trim('"')
    if ([string]::IsNullOrWhiteSpace($expandedPath)) {
        throw [System.ArgumentException]::new(
            'Enter the folder of the Entry Root the shortcut should open.',
            'EntryRootPath'
        )
    }

    $isUncPath = $expandedPath.StartsWith('\\')
    $trimmedPath = $expandedPath.TrimEnd('\', '/')
    if (-not [IO.Path]::IsPathRooted($trimmedPath)) {
        throw [System.ArgumentException]::new(
            "'$expandedPath' is not an absolute path.",
            'EntryRootPath'
        )
    }

    # Split-Path throws on a bare drive specifier, and the .NET path helpers
    # disagree between editions about the parent of a UNC share, so split here.
    $separatorIndex = $trimmedPath.LastIndexOfAny([char[]] @('\', '/'))
    $entryName = if ($separatorIndex -ge 0) {
        $trimmedPath.Substring($separatorIndex + 1)
    } else {
        ''
    }
    $managedRoot = if ($separatorIndex -ge 0) {
        $trimmedPath.Substring(0, $separatorIndex)
    } else {
        ''
    }
    if ($managedRoot.EndsWith(':')) {
        $managedRoot += '\'
    }
    if ([string]::IsNullOrWhiteSpace($entryName) -or
        [string]::IsNullOrWhiteSpace($managedRoot)) {
        throw [System.ArgumentException]::new(
            "'$expandedPath' has no parent folder to use as the Managed Root.",
            'EntryRootPath'
        )
    }

    # A UNC Managed Root needs a server and a share; \\server alone is not one.
    if ($isUncPath) {
        $rootSegments = @(
            $managedRoot.TrimStart('\') -split '\\+' | Where-Object { $_ }
        )
        if ($rootSegments.Count -lt 2) {
            throw [System.ArgumentException]::new(
                "'$expandedPath' must name a server, a share, and the Entry Root folder.",
                'EntryRootPath'
            )
        }
    }

    $argumentParts = [System.Collections.Generic.List[string]]::new()
    foreach ($part in @(
            '-NoLogo'
            '-NoProfile'
            '-NonInteractive'
            '-WindowStyle'
            'Hidden'
            '-ExecutionPolicy'
            'Bypass'
            '-STA'
            '-File'
            (ConvertTo-LaunchTreeCommandLineArgument -Value $LauncherPath)
        )) {
        [void] $argumentParts.Add($part)
    }
    if (-not [string]::IsNullOrWhiteSpace($LauncherCommand)) {
        [void] $argumentParts.Add('-Command')
        [void] $argumentParts.Add(
            (ConvertTo-LaunchTreeCommandLineArgument -Value $LauncherCommand)
        )
    }
    foreach ($part in @(
            '-ManagedRoot'
            (ConvertTo-LaunchTreeCommandLineArgument -Value $managedRoot)
            '-EntryName'
            (ConvertTo-LaunchTreeCommandLineArgument -Value $entryName)
        )) {
        [void] $argumentParts.Add($part)
    }
    if ($CloseAfterLaunch) {
        [void] $argumentParts.Add('-CloseAfterLaunch')
    }

    $fileNameStem = $entryName
    foreach ($invalidCharacter in [IO.Path]::GetInvalidFileNameChars()) {
        $fileNameStem = $fileNameStem.Replace($invalidCharacter, '_')
    }
    if ([string]::IsNullOrWhiteSpace($fileNameStem)) {
        $fileNameStem = 'LaunchTree'
    }

    [PSCustomObject] @{
        PSTypeName       = 'LaunchTree.ShortcutDefinition'
        ManagedRoot      = $managedRoot
        EntryName        = $entryName
        TargetPath       = $LauncherHostPath
        Arguments        = $argumentParts -join ' '
        WorkingDirectory = Split-Path -Path $LauncherPath -Parent
        FileName         = "$fileNameStem.lnk"
        CloseAfterLaunch = [bool] $CloseAfterLaunch
    }
}
