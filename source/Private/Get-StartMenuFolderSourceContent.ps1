function Get-StartMenuFolderSourceContent {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SourceRoot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $EntryName,

        [Parameter(Mandatory)]
        [ValidateSet('Managed', 'Personal')]
        [string] $ContentSource,

        [Parameter(Mandatory)]
        [ValidateRange(1, 32)]
        [int] $MaximumDepth
    )

    $objects = [System.Collections.Generic.List[object]]::new()
    $healthFindings = [System.Collections.Generic.List[object]]::new()

    $walkDirectory = {
        param(
            [string] $CurrentPath,
            [int] $CurrentDepth,
            [string] $ParentRelativePath,
            [string] $SnapshotSourceRoot,
            [string] $SnapshotEntryName,
            [string] $SnapshotContentSource,
            [int] $SnapshotMaximumDepth
        )

        try {
            $children = @(Get-ChildItem -LiteralPath $CurrentPath -Force -ErrorAction Stop)
        } catch {
            $errorRecord = $_
            $findingCode = if ($errorRecord.Exception -is [IO.PathTooLongException]) {
                'HostPathLimitExceeded'
            } else {
                'ContentPathInaccessible'
            }
            $findingParameters = @{
                Code     = $findingCode
                Severity = 'Warning'
                Message  = $errorRecord.Exception.Message
                Path     = $CurrentPath
            }
            [void] $healthFindings.Add((New-StartMenuFolderHealthFinding @findingParameters))
            return
        }

        foreach ($directory in @($children | Where-Object { $_.PSIsContainer })) {
            if (($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                $findingParameters = @{
                    Code     = 'ReparsePointIgnored'
                    Severity = 'Warning'
                    Message  = 'Directory reparse points are not traversed.'
                    Path     = $directory.FullName
                }
                [void] $healthFindings.Add((New-StartMenuFolderHealthFinding @findingParameters))
                continue
            }

            $childDepth = $CurrentDepth + 1
            if ($childDepth -gt $SnapshotMaximumDepth) {
                $findingParameters = @{
                    Code     = 'MaximumDepthExceeded'
                    Severity = 'Warning'
                    Message  = "Content exceeds maximum depth $SnapshotMaximumDepth."
                    Path     = $directory.FullName
                }
                [void] $healthFindings.Add((New-StartMenuFolderHealthFinding @findingParameters))
                continue
            }

            $relativePath = $directory.FullName.Substring($SnapshotSourceRoot.Length).TrimStart('\', '/')
            $descriptionPath = Join-Path -Path $directory.FullName -ChildPath 'description.txt'
            $description = $null
            try {
                $description = Get-StartMenuFolderDescription -LiteralPath $descriptionPath
            } catch {
                $errorRecord = $_
                $findingParameters = @{
                    Code     = 'DescriptionUnavailable'
                    Severity = 'Warning'
                    Message  = $errorRecord.Exception.Message
                    Path     = $descriptionPath
                }
                [void] $healthFindings.Add((New-StartMenuFolderHealthFinding @findingParameters))
            }

            [void] $objects.Add([PSCustomObject] @{
                PSTypeName         = 'StartMenuFolders.MenuFolder'
                Kind               = 'MenuFolder'
                Name               = $directory.Name
                Description        = $description
                Extension          = $null
                FullPath           = $directory.FullName
                RelativePath       = $relativePath
                ParentRelativePath = $ParentRelativePath
                EntryName          = $SnapshotEntryName
                ContentSource      = $SnapshotContentSource
                Depth              = $childDepth
            })

            $walkArguments = @(
                $directory.FullName
                $childDepth
                $relativePath
                $SnapshotSourceRoot
                $SnapshotEntryName
                $SnapshotContentSource
                $SnapshotMaximumDepth
            )
            & $walkDirectory @walkArguments
        }

        foreach ($file in @($children | Where-Object { -not $_.PSIsContainer })) {
            if ($file.Name -ieq 'description.txt') {
                continue
            }

            $extension = $file.Extension.ToLowerInvariant()
            if ($extension -notin @('.lnk', '.url')) {
                continue
            }

            $detail = Get-StartMenuFolderLaunchItemDetail -LiteralPath $file.FullName
            if (-not $detail.Succeeded) {
                $findingParameters = @{
                    Code     = $detail.Code
                    Severity = 'Warning'
                    Message  = $detail.Message
                    Path     = $file.FullName
                }
                [void] $healthFindings.Add((New-StartMenuFolderHealthFinding @findingParameters))
                continue
            }

            $relativePath = $file.FullName.Substring($SnapshotSourceRoot.Length).TrimStart('\', '/')
            [void] $objects.Add([PSCustomObject] @{
                PSTypeName         = 'StartMenuFolders.LaunchItem'
                Kind               = 'LaunchItem'
                Name               = $file.BaseName
                Description        = $detail.Description
                Extension          = $extension
                FullPath           = $file.FullName
                RelativePath       = $relativePath
                ParentRelativePath = $ParentRelativePath
                EntryName          = $SnapshotEntryName
                ContentSource      = $SnapshotContentSource
                Depth              = $CurrentDepth
            })
        }
    }

    & $walkDirectory $SourceRoot 1 '' $SourceRoot $EntryName $ContentSource $MaximumDepth

    [PSCustomObject] @{
        Objects        = [object[]] $objects
        HealthFindings = [object[]] $healthFindings
    }
}