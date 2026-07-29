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

    $visibleObjects = @($Snapshot.Objects | Where-Object {
        $_.EntryName -eq $EntryName -and
        $_.ParentRelativePath -eq $CurrentRelativePath
    })

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

    [PSCustomObject] @{
        PSTypeName          = 'LaunchTree.TabbedListContent'
        CurrentName         = [string] $currentObject.Name
        CurrentRelativePath = $CurrentRelativePath
        Description         = [string] $currentObject.Description
        MenuFolders         = [object[]] $menuFolders
        LaunchItems         = [object[]] $launchItems
        VisibleCount        = $menuFolders.Count + $launchItems.Count
    }
}