function Show-LaunchTree {
    <#
        .SYNOPSIS
            Opens a recursive LaunchTree WPF Launcher.

        .DESCRIPTION
            Resolves an opaque Entry ID or Entry Root name, creates one merged
            Content Snapshot, and opens a Windows-themed WPF Launcher with
            search, navigation, Shell-native invocation, high-resolution icons,
            keyboard support, and right-click suppression.

        .PARAMETER EntryId
            Specifies the opaque Entry ID stored in Generated State.

        .PARAMETER EntryName
            Specifies an Entry Root by name for administration and capture.

        .PARAMETER ConfigurationPath
            Specifies the machine configuration JSON file to read.

        .PARAMETER ManagedRoot
            Overrides the Managed Root that supplies Entry Roots.

        .PARAMETER PersonalRoot
            Overrides the Personal Root merged into matching Entry Roots.

        .PARAMETER GeneratedStatePath
            Overrides the Generated State path used with EntryId.

        .PARAMETER CapturePath
            Renders the Launcher to a PNG and self-closes for visual validation.

        .PARAMETER CloseAfterLaunch
            Closes the Launcher after a Launch Item starts. Omit it to keep the
            Launcher open so more items can be started from the same window.

        .EXAMPLE
            Show-LaunchTree -EntryName 'Entertainment'

            Opens the Entertainment Entry Root.

        .EXAMPLE
            Show-LaunchTree -EntryName 'Programs' -ManagedRoot C:\Menus\Contoso

            Opens an Entry Root below a Managed Root supplied for this call.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByEntryId')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByEntryId')]
        [guid] $EntryId,

        [Parameter(Mandatory, ParameterSetName = 'ByEntryName')]
        [ValidateNotNullOrEmpty()]
        [string] $EntryName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ManagedRoot,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $PersonalRoot,

        [Parameter(ParameterSetName = 'ByEntryId')]
        [ValidateNotNullOrEmpty()]
        [string] $GeneratedStatePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $CapturePath,

        [Parameter()]
        [switch] $CloseAfterLaunch
    )

    if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne
        [Threading.ApartmentState]::STA) {
        throw [System.Threading.ThreadStateException]::new(
            'Show-LaunchTree requires an STA PowerShell host.'
        )
    }
    $startupStopwatch = [Diagnostics.Stopwatch]::StartNew()

    $configurationParameters = @{}
    if ($PSBoundParameters.ContainsKey('ConfigurationPath')) {
        $configurationParameters.ConfigurationPath = $ConfigurationPath
    }
    if ($PSBoundParameters.ContainsKey('ManagedRoot')) {
        $configurationParameters.ManagedRoot = $ManagedRoot
    }
    if ($PSBoundParameters.ContainsKey('PersonalRoot')) {
        $configurationParameters.PersonalRoot = $PersonalRoot
    }
    if ($PSBoundParameters.ContainsKey('CloseAfterLaunch')) {
        $configurationParameters.CloseAfterLaunch = $CloseAfterLaunch
    }
    $configuration = Get-LaunchTreeConfiguration @configurationParameters
    if (-not $configuration.IsValid) {
        $schemaFinding = $configuration.HealthFindings |
            Where-Object Code -eq 'ConfigurationSchemaUnsupported' |
            Select-Object -First 1
        $errorParameters = @{
            Title       = 'Configuration is not supported'
            Message     = $schemaFinding.Message
            CapturePath = $CapturePath
        }
        Show-LaunchTreeErrorWindow @errorParameters
        return
    }
    $activationServer = $null
    $sessionMutex = $null
    $ownsMutex = $false
    if ($PSCmdlet.ParameterSetName -eq 'ByEntryId') {
        if (-not $PSBoundParameters.ContainsKey('GeneratedStatePath')) {
            $stateDirectory = Split-Path -Path $configuration.ConfigurationPath -Parent
            $GeneratedStatePath = Join-Path -Path $stateDirectory -ChildPath (
                'LaunchTree.generated.json'
            )
        }
        if (-not $CapturePath) {
            Initialize-LaunchTreeWpf
            $sessionIdentity = Get-LaunchTreeSessionIdentity
            $createdNew = $false
            $sessionMutex = [Threading.Mutex]::new(
                $true,
                $sessionIdentity.MutexName,
                [ref] $createdNew
            )
            $ownsMutex = $createdNew
            if (-not $createdNew) {
                try {
                    $activationMessage = [ordered] @{
                        EntryId            = $EntryId.ToString()
                        ConfigurationPath  = $configuration.ConfigurationPath
                        GeneratedStatePath = $GeneratedStatePath
                    } | ConvertTo-Json -Compress
                    [LaunchTree.ActivationChannel]::Send(
                        $sessionIdentity.PipeName,
                        $activationMessage,
                        5000
                    )
                    return
                } finally {
                    $sessionMutex.Dispose()
                }
            }
            $activationServer = [LaunchTree.ActivationServer]::new(
                $sessionIdentity.PipeName
            )
            $activationServer.Start()
        }
    }

    try {
        $snapshot = Get-LaunchTreeContentSnapshot -Configuration $configuration
        if (@($snapshot.HealthFindings | Where-Object Severity -eq 'Error').Count -gt 0) {
            throw [System.InvalidOperationException]::new(
                'The Launcher cannot open because the Managed Root is unhealthy.'
            )
        }

        if ($PSCmdlet.ParameterSetName -eq 'ByEntryId') {
        $resolveParameters = @{
            EntryId            = $EntryId
            ManagedRoot        = $configuration.ManagedRoot
            GeneratedStatePath = $GeneratedStatePath
        }
        $entryReference = Resolve-LaunchTreeEntry @resolveParameters
        $EntryName = $entryReference.Name
        } elseif ($snapshot.EntryRoots.Name -notcontains $EntryName) {
            throw [System.Collections.Generic.KeyNotFoundException]::new(
                "Entry Root '$EntryName' was not found."
            )
        }

        $windowParameters = @{
            Configuration     = $configuration
            Snapshot          = $snapshot
            EntryName         = $EntryName
            CapturePath       = $CapturePath
            ActivationServer  = $activationServer
            GeneratedStatePath = $GeneratedStatePath
            StartupStopwatch  = $startupStopwatch
        }
        Show-LaunchTreeWindow @windowParameters
    } finally {
        if ($activationServer) {
            $activationServer.Dispose()
        }
        if ($sessionMutex) {
            if ($ownsMutex) {
                $sessionMutex.ReleaseMutex()
            }
            $sessionMutex.Dispose()
        }
    }
}