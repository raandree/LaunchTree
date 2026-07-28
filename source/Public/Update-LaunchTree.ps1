function Update-StartMenuFolder {
    <#
        .SYNOPSIS
            Reconciles module-owned Start Entries with current Entry Roots.

        .DESCRIPTION
            Creates, updates, and removes only module-owned Start Entries as an
            all-or-nothing transaction. Entry IDs remain stable while an Entry
            Root path remains unchanged, and unowned shortcut collisions abort
            before any mutation occurs.

        .PARAMETER ConfigurationPath
            Specifies the machine configuration JSON file to read.

        .PARAMETER StartMenuPath
            Overrides the machine-wide Start Programs directory. Deployment
            normally uses the Windows Common Programs known folder.

        .PARAMETER GeneratedStatePath
            Overrides the module ownership-record path.

        .PARAMETER SkipEventLogRegistration
            Skips diagnostics registration only when deployment has already
            provisioned and validated the required event log contract.

        .EXAMPLE
            Update-StartMenuFolder -Confirm:$false

            Reconciles Start Entries from the default Managed Root.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $StartMenuPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $GeneratedStatePath,

        [Parameter()]
        [switch] $SkipEventLogRegistration
    )

    $configurationParameters = @{}
    if ($PSBoundParameters.ContainsKey('ConfigurationPath')) {
        $configurationParameters.ConfigurationPath = $ConfigurationPath
    }
    $configuration = Get-StartMenuFolderConfiguration @configurationParameters
    if (-not $configuration.IsValid) {
        $schemaFinding = $configuration.HealthFindings |
            Where-Object Code -eq 'ConfigurationSchemaUnsupported' |
            Select-Object -First 1
        throw [System.IO.InvalidDataException]::new($schemaFinding.Message)
    }

    if (-not $PSBoundParameters.ContainsKey('ConfigurationPath')) {
        $ConfigurationPath = $configuration.ConfigurationPath
    }
    if (-not $PSBoundParameters.ContainsKey('StartMenuPath')) {
        $StartMenuPath = [Environment]::GetFolderPath(
            [Environment+SpecialFolder]::CommonPrograms
        )
    }
    if (-not $PSBoundParameters.ContainsKey('GeneratedStatePath')) {
        $stateDirectory = Split-Path -Path $ConfigurationPath -Parent
        $GeneratedStatePath = Join-Path -Path $stateDirectory -ChildPath (
            'StartMenuFolders.generated.json'
        )
    }

    $snapshot = Get-StartMenuFolderContentSnapshot -Configuration $configuration
    if (@($snapshot.HealthFindings | Where-Object Severity -eq 'Error').Count -gt 0) {
        throw [System.InvalidOperationException]::new(
            'Reconciliation cannot continue while the Content Snapshot is unhealthy.'
        )
    }

    $moduleBase = $ExecutionContext.SessionState.Module.ModuleBase
    $bootstrapPath = Join-Path -Path $moduleBase -ChildPath (
        'Scripts\Start-StartMenuFolderLauncher.ps1'
    )
    if (-not (Test-Path -LiteralPath $bootstrapPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new(
            'The packaged Launcher bootstrap is missing.',
            $bootstrapPath
        )
    }

    $launcherHostPath = Get-StartMenuFolderLauncherHostPath -LauncherHost (
        $configuration.LauncherHost
    )
    if (-not $SkipEventLogRegistration) {
        Register-StartMenuFolderEventLog -Configuration $configuration
    }

    $previousState = Import-StartMenuFolderGeneratedState -LiteralPath $GeneratedStatePath
    $previousEntries = if ($previousState -and
        $previousState.PSObject.Properties['StartEntries']) {
        @($previousState.StartEntries | Where-Object { $null -ne $_ })
    } else {
        @()
    }
    $previousByRoot = [Collections.Generic.Dictionary[string, object]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    $ownedShortcutPaths = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    foreach ($entry in $previousEntries) {
        if ($entry.EntryRootPath) {
            $previousByRoot[[IO.Path]::GetFullPath([string] $entry.EntryRootPath)] = $entry
        }
        if ($entry.ShortcutPath) {
            [void] $ownedShortcutPaths.Add([IO.Path]::GetFullPath([string] $entry.ShortcutPath))
        }
    }

    $desiredEntries = [System.Collections.Generic.List[object]]::new()
    foreach ($entryRoot in $snapshot.EntryRoots) {
        $normalizedRoot = [IO.Path]::GetFullPath($entryRoot.ManagedPath)
        $shortcutPath = Join-Path -Path $StartMenuPath -ChildPath (
            '{0}.lnk' -f $entryRoot.Name
        )
        $normalizedShortcut = [IO.Path]::GetFullPath($shortcutPath)

        if ((Test-Path -LiteralPath $normalizedShortcut -PathType Leaf) -and
            -not $ownedShortcutPaths.Contains($normalizedShortcut)) {
            throw [System.InvalidOperationException]::new(
                "An unowned Start shortcut collides with Entry Root '$($entryRoot.Name)'."
            )
        }

        $entryId = if ($previousByRoot.ContainsKey($normalizedRoot)) {
            [guid] $previousByRoot[$normalizedRoot].EntryId
        } else {
            [guid]::NewGuid()
        }
        $definition = [ordered] @{
            EntryId           = $entryId.ToString()
            EntryRootPath     = $normalizedRoot
            ShortcutPath      = $normalizedShortcut
            LauncherHostPath  = $launcherHostPath
            BootstrapPath     = $bootstrapPath
            ConfigurationPath = [IO.Path]::GetFullPath($ConfigurationPath)
            Description       = [string] $entryRoot.Description
        }
        $definitionHash = Get-StartMenuFolderDefinitionHash -Definition $definition

        [void] $desiredEntries.Add([PSCustomObject] @{
            EntryId        = $entryId.ToString()
            Name           = $entryRoot.Name
            EntryRootPath  = $normalizedRoot
            ShortcutPath   = $normalizedShortcut
            DefinitionHash = $definitionHash
            Description    = [string] $entryRoot.Description
        })
    }

    $desiredPaths = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    foreach ($entry in $desiredEntries) {
        [void] $desiredPaths.Add($entry.ShortcutPath)
    }

    $added = [System.Collections.Generic.List[string]]::new()
    $updated = [System.Collections.Generic.List[string]]::new()
    $removed = [System.Collections.Generic.List[string]]::new()
    $changedEntries = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in $desiredEntries) {
        $previousEntry = if ($previousByRoot.ContainsKey($entry.EntryRootPath)) {
            $previousByRoot[$entry.EntryRootPath]
        } else {
            $null
        }

        if (-not $previousEntry -or -not (Test-Path -LiteralPath $entry.ShortcutPath -PathType Leaf)) {
            [void] $added.Add($entry.ShortcutPath)
            [void] $changedEntries.Add($entry)
        } elseif ($previousEntry.DefinitionHash -ne $entry.DefinitionHash) {
            [void] $updated.Add($entry.ShortcutPath)
            [void] $changedEntries.Add($entry)
        }
    }
    foreach ($entry in $previousEntries) {
        $normalizedPath = [IO.Path]::GetFullPath([string] $entry.ShortcutPath)
        if (-not $desiredPaths.Contains($normalizedPath)) {
            [void] $removed.Add($normalizedPath)
        }
    }

    $result = [PSCustomObject] @{
        PSTypeName = 'StartMenuFolders.ReconciliationResult'
        Succeeded  = $true
        Added      = [string[]] $added
        Updated    = [string[]] $updated
        Removed    = [string[]] $removed
    }

    $changeCount = $added.Count + $updated.Count + $removed.Count
    if ($changeCount -eq 0) {
        $eventParameters = @{
            Configuration = $configuration
            EventId       = 1302
            Level         = 'Information'
            Operation     = 'Reconciliation'
            Message       = 'Reconciliation completed with no changes.'
            Path          = $GeneratedStatePath
        }
        $null = Write-StartMenuFolderEvent @eventParameters
        return $result
    }
    if (-not $PSCmdlet.ShouldProcess($StartMenuPath, "Reconcile $changeCount Start Entries")) {
        return $result
    }

    $stateDirectory = Split-Path -Path $GeneratedStatePath -Parent
    $null = New-Item -Path $stateDirectory -ItemType Directory -Force
    $null = New-Item -Path $StartMenuPath -ItemType Directory -Force
    $transactionPath = Join-Path -Path $stateDirectory -ChildPath (
        '.startmenufolders-{0}' -f [guid]::NewGuid().ToString('N')
    )
    $stagingPath = Join-Path -Path $transactionPath -ChildPath 'staging'
    $backupPath = Join-Path -Path $transactionPath -ChildPath 'backup'
    $null = New-Item -Path $stagingPath -ItemType Directory -Force
    $null = New-Item -Path $backupPath -ItemType Directory -Force

    $backupMap = @{}
    $newPaths = [System.Collections.Generic.List[string]]::new()
    $stateBackupPath = Join-Path -Path $backupPath -ChildPath 'GeneratedState.json'
    try {
        foreach ($entry in $changedEntries) {
            $stagedShortcut = Join-Path -Path $stagingPath -ChildPath (
                '{0}.lnk' -f $entry.EntryId
            )
            $shortcutParameters = @{
                LiteralPath       = $stagedShortcut
                LauncherHostPath  = $launcherHostPath
                BootstrapPath     = $bootstrapPath
                EntryId           = [guid] $entry.EntryId
                ConfigurationPath = [IO.Path]::GetFullPath($ConfigurationPath)
                WorkingDirectory  = $moduleBase
                Description       = $entry.Description
            }
            New-StartMenuFolderStartEntry @shortcutParameters
            $entry | Add-Member -NotePropertyName StagedShortcut -NotePropertyValue $stagedShortcut
        }

        $module = $ExecutionContext.SessionState.Module
        $newState = [ordered] @{
            SchemaVersion       = 1
            ModuleVersion       = $module.Version.ToString()
            ConfigurationPath   = [IO.Path]::GetFullPath($ConfigurationPath)
            ManagedRoot         = [IO.Path]::GetFullPath($configuration.ManagedRoot)
            LastReconciledAtUtc = [DateTime]::UtcNow.ToString('o')
            StartEntries        = @($desiredEntries | Select-Object (
                'EntryId', 'Name', 'EntryRootPath', 'ShortcutPath', 'DefinitionHash'
            ))
        }
        $stagedStatePath = Join-Path -Path $stagingPath -ChildPath 'GeneratedState.json'
        $stateJson = $newState | ConvertTo-Json -Depth 6
        [IO.File]::WriteAllText($stagedStatePath, $stateJson, [Text.UTF8Encoding]::new($false))

        $affectedPaths = [System.Collections.Generic.List[string]]::new()
        foreach ($changedEntry in $changedEntries) {
            [void] $affectedPaths.Add($changedEntry.ShortcutPath)
        }
        foreach ($removedPath in $removed) {
            [void] $affectedPaths.Add($removedPath)
        }
        foreach ($affectedPath in $affectedPaths) {
            if (Test-Path -LiteralPath $affectedPath -PathType Leaf) {
                $backupFile = Join-Path -Path $backupPath -ChildPath (
                    '{0}.lnk' -f [guid]::NewGuid().ToString('N')
                )
                Copy-Item -LiteralPath $affectedPath -Destination $backupFile -Force
                $backupMap[$affectedPath] = $backupFile
            } else {
                [void] $newPaths.Add($affectedPath)
            }
        }
        if (Test-Path -LiteralPath $GeneratedStatePath -PathType Leaf) {
            Copy-Item -LiteralPath $GeneratedStatePath -Destination $stateBackupPath -Force
        }

        foreach ($entry in $changedEntries) {
            Copy-Item -LiteralPath $entry.StagedShortcut -Destination $entry.ShortcutPath -Force
        }
        foreach ($stalePath in $removed) {
            Remove-Item -LiteralPath $stalePath -Force -ErrorAction Stop
        }
        Copy-Item -LiteralPath $stagedStatePath -Destination $GeneratedStatePath -Force
    } catch {
        $errorRecord = $_
        foreach ($path in $newPaths) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
        foreach ($path in $backupMap.Keys) {
            Copy-Item -LiteralPath $backupMap[$path] -Destination $path -Force
        }
        if (Test-Path -LiteralPath $stateBackupPath -PathType Leaf) {
            Copy-Item -LiteralPath $stateBackupPath -Destination $GeneratedStatePath -Force
        } else {
            Remove-Item -LiteralPath $GeneratedStatePath -Force -ErrorAction SilentlyContinue
        }
        $eventParameters = @{
            Configuration = $configuration
            EventId       = 1301
            Level         = 'Error'
            Operation     = 'Reconciliation'
            Message       = $errorRecord.Exception.Message
            Path          = $GeneratedStatePath
            ErrorCode     = $errorRecord.FullyQualifiedErrorId
        }
        $null = Write-StartMenuFolderEvent @eventParameters
        throw $errorRecord
    } finally {
        Remove-Item -LiteralPath $transactionPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    $eventParameters = @{
        Configuration = $configuration
        EventId       = 1302
        Level         = 'Information'
        Operation     = 'Reconciliation'
        Message       = "Reconciliation completed with $changeCount changes."
        Path          = $GeneratedStatePath
    }
    $null = Write-StartMenuFolderEvent @eventParameters
    $result
}