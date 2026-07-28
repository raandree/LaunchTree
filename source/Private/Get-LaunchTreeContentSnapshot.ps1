function Get-LaunchTreeContentSnapshot {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject] $Configuration
    )

    $entryRoots = [System.Collections.Generic.List[object]]::new()
    $objects = [System.Collections.Generic.List[object]]::new()
    $healthFindings = [System.Collections.Generic.List[object]]::new()

    if (-not (Test-Path -LiteralPath $Configuration.ManagedRoot -PathType Container)) {
        $findingParameters = @{
            Code     = 'ManagedRootInaccessible'
            Severity = 'Error'
            Message  = 'The Managed Root does not exist or is inaccessible.'
            Path     = $Configuration.ManagedRoot
        }
        [void] $healthFindings.Add((New-LaunchTreeHealthFinding @findingParameters))
    } else {
        try {
            $managedEntries = @(
                Get-ChildItem -LiteralPath $Configuration.ManagedRoot -Directory -Force -ErrorAction Stop |
                    Where-Object {
                        ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0
                    }
            )
        } catch {
            $errorRecord = $_
            $managedEntries = @()
            $findingParameters = @{
                Code     = 'ManagedRootInaccessible'
                Severity = 'Error'
                Message  = $errorRecord.Exception.Message
                Path     = $Configuration.ManagedRoot
            }
            [void] $healthFindings.Add((New-LaunchTreeHealthFinding @findingParameters))
        }

        foreach ($managedEntry in $managedEntries) {
            $descriptionPath = Join-Path -Path $managedEntry.FullName -ChildPath 'description.txt'
            $description = $null
            try {
                $description = Get-LaunchTreeDescription -LiteralPath $descriptionPath
            } catch {
                $errorRecord = $_
                $findingParameters = @{
                    Code     = 'DescriptionUnavailable'
                    Severity = 'Warning'
                    Message  = $errorRecord.Exception.Message
                    Path     = $descriptionPath
                }
                [void] $healthFindings.Add((New-LaunchTreeHealthFinding @findingParameters))
            }

            $personalEntryPath = Join-Path -Path $Configuration.PersonalRoot -ChildPath $managedEntry.Name
            [void] $entryRoots.Add([PSCustomObject] @{
                PSTypeName   = 'LaunchTree.EntryRoot'
                Name         = $managedEntry.Name
                Description  = $description
                ManagedPath  = $managedEntry.FullName
                PersonalPath = if (Test-Path -LiteralPath $personalEntryPath -PathType Container) {
                    $personalEntryPath
                } else {
                    $null
                }
                Depth        = 1
            })

            $managedFragmentParameters = @{
                SourceRoot    = $managedEntry.FullName
                EntryName     = $managedEntry.Name
                ContentSource = 'Managed'
                MaximumDepth  = $Configuration.MaximumDepth
            }
            $managedFragment = Get-LaunchTreeSourceContent @managedFragmentParameters
            foreach ($object in @($managedFragment.Objects)) {
                [void] $objects.Add($object)
            }
            foreach ($finding in @($managedFragment.HealthFindings)) {
                [void] $healthFindings.Add($finding)
            }

            if (Test-Path -LiteralPath $personalEntryPath -PathType Container) {
                $personalEntry = Get-Item -LiteralPath $personalEntryPath -Force
                if (($personalEntry.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
                    $personalFragmentParameters = @{
                        SourceRoot    = $personalEntryPath
                        EntryName     = $managedEntry.Name
                        ContentSource = 'Personal'
                        MaximumDepth  = $Configuration.MaximumDepth
                    }
                    $personalFragment = Get-LaunchTreeSourceContent @personalFragmentParameters
                    foreach ($object in @($personalFragment.Objects)) {
                        [void] $objects.Add($object)
                    }
                    foreach ($finding in @($personalFragment.HealthFindings)) {
                        [void] $healthFindings.Add($finding)
                    }
                }
            }
        }
    }

    $mergedObjects = [System.Collections.Generic.List[object]]::new()
    $folderByPath = [Collections.Generic.Dictionary[string, object]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    foreach ($contentObject in $objects) {
        if ($contentObject.Kind -ne 'MenuFolder') {
            [void] $mergedObjects.Add($contentObject)
            continue
        }

        $folderKey = '{0}|{1}' -f $contentObject.EntryName, $contentObject.RelativePath
        if (-not $folderByPath.ContainsKey($folderKey)) {
            $folderByPath[$folderKey] = $contentObject
            [void] $mergedObjects.Add($contentObject)
            continue
        }

        $existingFolder = $folderByPath[$folderKey]
        $existingFolder.ContentSource = 'Managed+Personal'
        if ([string]::IsNullOrWhiteSpace($existingFolder.Description) -and
            -not [string]::IsNullOrWhiteSpace($contentObject.Description)) {
            $existingFolder.Description = $contentObject.Description
        }
    }

    foreach ($finding in $healthFindings) {
        $eventParameters = @{
            Configuration = $Configuration
            HealthFinding = $finding
        }
        $null = Write-LaunchTreeHealthFindingEvent @eventParameters
    }

    $descending = $Configuration.SortOrder -eq 'NameDescending'
    [PSCustomObject] @{
        PSTypeName     = 'LaunchTree.ContentSnapshot'
        CreatedAtUtc   = [DateTime]::UtcNow
        EntryRoots     = [object[]] @($entryRoots | Sort-Object -Property Name -Descending:$descending)
        Objects        = [object[]] @($mergedObjects | Sort-Object -Property Name -Descending:$descending)
        HealthFindings = [object[]] $healthFindings
    }
}