function Get-LaunchTreeTabbedListContent {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject] $Snapshot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $EntryName,

        [Parameter()]
        [AllowEmptyString()]
        [string] $CurrentRelativePath = '',

        [Parameter()]
        [AllowEmptyString()]
        [string] $SearchText = '',

        [Parameter()]
        [switch] $Descending
    )

    $entryRoot = @($Snapshot.EntryRoots | Where-Object Name -eq $EntryName)[0]
    if (-not $entryRoot) {
        throw [InvalidOperationException]::new(
            "Entry Root '$EntryName' is not present in the Content Snapshot."
        )
    }

    $currentObject = if ([string]::IsNullOrWhiteSpace($CurrentRelativePath)) {
        $entryRoot
    } else {
        @($Snapshot.Objects | Where-Object {
            $_.Kind -eq 'MenuFolder' -and
            $_.EntryName -eq $EntryName -and
            $_.RelativePath -eq $CurrentRelativePath
        })[0]
    }
    if (-not $currentObject) {
        throw [InvalidOperationException]::new(
            "Menu Folder '$CurrentRelativePath' is not present in Entry Root '$EntryName'."
        )
    }

    $normalizedSearchText = $SearchText.Trim()
    $isSearching = -not [string]::IsNullOrWhiteSpace($normalizedSearchText)
    $visibleObjects = if ($isSearching) {
        @($Snapshot.Objects | Where-Object {
            $_.Name.IndexOf(
                $normalizedSearchText,
                [StringComparison]::CurrentCultureIgnoreCase
            ) -ge 0
        })
    } else {
        @($Snapshot.Objects | Where-Object {
            $_.EntryName -eq $EntryName -and
            $_.ParentRelativePath -eq $CurrentRelativePath
        })
    }

    $sortParameters = @{
        Property   = 'Name'
        Descending = [bool] $Descending
    }
    $menuFolders = @(
        $visibleObjects |
            Where-Object Kind -eq 'MenuFolder' |
            Sort-Object @sortParameters
    )
    $launchItems = @(
        $visibleObjects |
            Where-Object Kind -eq 'LaunchItem' |
            Sort-Object @sortParameters
    )
    $pathSeparator = '>'
    $menuFolderTabs = @(
        foreach ($menuFolder in $menuFolders) {
            $context = if ($isSearching) {
                '{0} {1} {2} | {3}' -f @(
                    $menuFolder.EntryName
                    $pathSeparator
                    $menuFolder.RelativePath
                    $menuFolder.ContentSource
                )
            } else {
                ''
            }
            [PSCustomObject] @{
                Header  = [string] $menuFolder.Name
                Context = $context
                Item    = $menuFolder
            }
        }
    )

    [PSCustomObject] @{
        PSTypeName          = 'LaunchTree.TabbedListContent'
        CurrentName         = [string] $currentObject.Name
        CurrentRelativePath = $CurrentRelativePath
        Description         = [string] $currentObject.Description
        MenuFolders         = [object[]] $menuFolders
        MenuFolderTabs      = [object[]] $menuFolderTabs
        LaunchItems         = [object[]] $launchItems
        VisibleCount        = $menuFolders.Count + $launchItems.Count
        IsSearching         = $isSearching
    }
}