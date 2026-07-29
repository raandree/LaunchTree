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
        [string] $SelectedRelativePath = '',

        [Parameter()]
        [switch] $Descending
    )

    if (-not $PSBoundParameters.ContainsKey('SelectedRelativePath')) {
        $SelectedRelativePath = $CurrentRelativePath
    }

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

    $selectedObject = if ($SelectedRelativePath -eq $CurrentRelativePath) {
        $currentObject
    } elseif ([string]::IsNullOrWhiteSpace($SelectedRelativePath)) {
        $entryRoot
    } else {
        @($Snapshot.Objects | Where-Object {
            $_.Kind -eq 'MenuFolder' -and
            $_.EntryName -eq $EntryName -and
            $_.RelativePath -eq $SelectedRelativePath
        })[0]
    }
    if (-not $selectedObject) {
        throw [InvalidOperationException]::new(
            "Menu Folder '$SelectedRelativePath' is not present in Entry Root '$EntryName'."
        )
    }

    $sortParameters = @{
        Property   = 'Name'
        Descending = [bool] $Descending
    }
    $menuFolders = @(
        $Snapshot.Objects |
            Where-Object {
                $_.Kind -eq 'MenuFolder' -and
                $_.EntryName -eq $EntryName -and
                $_.ParentRelativePath -eq $CurrentRelativePath
            } |
            Sort-Object @sortParameters
    )

    $selectedChildren = @($Snapshot.Objects | Where-Object {
        $_.EntryName -eq $EntryName -and
        $_.ParentRelativePath -eq $SelectedRelativePath
    })
    # The tab strip already exposes the owning Menu Folder's children.
    $childMenuFolders = @()
    if ($SelectedRelativePath -ne $CurrentRelativePath) {
        $childMenuFolders = @(
            $selectedChildren |
                Where-Object Kind -eq 'MenuFolder' |
                Sort-Object @sortParameters
        )
    }
    $launchItems = @(
        $selectedChildren |
            Where-Object Kind -eq 'LaunchItem' |
            Sort-Object @sortParameters
    )

    [PSCustomObject] @{
        PSTypeName           = 'LaunchTree.TabbedListContent'
        CurrentName          = [string] $currentObject.Name
        CurrentRelativePath  = $CurrentRelativePath
        SelectedName         = [string] $selectedObject.Name
        SelectedRelativePath = $SelectedRelativePath
        Description          = [string] $selectedObject.Description
        MenuFolders          = [object[]] $menuFolders
        ChildMenuFolders     = [object[]] $childMenuFolders
        LaunchItems          = [object[]] $launchItems
        VisibleCount         = $menuFolders.Count +
            $childMenuFolders.Count +
            $launchItems.Count
    }
}