function Show-StartMenuFolder {
    <#
        .SYNOPSIS
            Opens a recursive StartMenuFolders WPF Launcher.

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

        .PARAMETER GeneratedStatePath
            Overrides the Generated State path used with EntryId.

        .PARAMETER CapturePath
            Renders the Launcher to a PNG and self-closes for visual validation.

        .EXAMPLE
            Show-StartMenuFolder -EntryName 'Entertainment'

            Opens the Entertainment Entry Root.
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

        [Parameter(ParameterSetName = 'ByEntryId')]
        [ValidateNotNullOrEmpty()]
        [string] $GeneratedStatePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $CapturePath
    )

    if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne
        [Threading.ApartmentState]::STA) {
        throw [System.Threading.ThreadStateException]::new(
            'Show-StartMenuFolder requires an STA PowerShell host.'
        )
    }

    $configurationParameters = @{}
    if ($PSBoundParameters.ContainsKey('ConfigurationPath')) {
        $configurationParameters.ConfigurationPath = $ConfigurationPath
    }
    $configuration = Get-StartMenuFolderConfiguration @configurationParameters
    $activationServer = $null
    $sessionMutex = $null
    $ownsMutex = $false
    if ($PSCmdlet.ParameterSetName -eq 'ByEntryId') {
        if (-not $PSBoundParameters.ContainsKey('GeneratedStatePath')) {
            $stateDirectory = Split-Path -Path $configuration.ConfigurationPath -Parent
            $GeneratedStatePath = Join-Path -Path $stateDirectory -ChildPath (
                'StartMenuFolders.generated.json'
            )
        }
        if (-not $CapturePath) {
            Initialize-StartMenuFolderWpf
            $sessionIdentity = Get-StartMenuFolderSessionIdentity
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
                    [StartMenuFolders.ActivationChannel]::Send(
                        $sessionIdentity.PipeName,
                        $activationMessage,
                        5000
                    )
                    return
                } finally {
                    $sessionMutex.Dispose()
                }
            }
            $activationServer = [StartMenuFolders.ActivationServer]::new(
                $sessionIdentity.PipeName
            )
            $activationServer.Start()
        }
    }

    try {
        $snapshot = Get-StartMenuFolderContentSnapshot -Configuration $configuration
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
        $entryReference = Resolve-StartMenuFolderEntry @resolveParameters
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
        }
        Show-StartMenuFolderWindow @windowParameters
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