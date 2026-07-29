function Get-LaunchTreeNavigationState {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Back', 'SelectTab', 'SelectFolder', 'ActivateEntry')]
        [string] $Action,

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
        [AllowNull()]
        [PSCustomObject] $Folder,

        [Parameter()]
        [AllowNull()]
        [string] $ActivatedEntryName
    )

    if (-not $PSBoundParameters.ContainsKey('SelectedRelativePath')) {
        $SelectedRelativePath = $CurrentRelativePath
    }

    $targetEntryName = $EntryName
    $targetRelativePath = $CurrentRelativePath
    $targetSelectedRelativePath = $SelectedRelativePath
    switch ($Action) {
        'Back' {
            if ($SelectedRelativePath -ne $CurrentRelativePath) {
                $targetSelectedRelativePath = $CurrentRelativePath
                break
            }

            $parentPath = [IO.Path]::GetDirectoryName($CurrentRelativePath)
            $targetRelativePath = if ($parentPath) { $parentPath } else { '' }
            $targetSelectedRelativePath = $targetRelativePath
        }
        'SelectTab' {
            if (-not $Folder) {
                $targetSelectedRelativePath = $CurrentRelativePath
                break
            }

            if ([string]::IsNullOrWhiteSpace([string] $Folder.EntryName) -or
                [string]::IsNullOrWhiteSpace([string] $Folder.RelativePath)) {
                throw [InvalidOperationException]::new(
                    'A selected Menu Folder tab requires an Entry Root and relative path.'
                )
            }
            $targetEntryName = [string] $Folder.EntryName
            $targetSelectedRelativePath = [string] $Folder.RelativePath
        }
        'SelectFolder' {
            if (-not $Folder -or
                [string]::IsNullOrWhiteSpace([string] $Folder.EntryName) -or
                [string]::IsNullOrWhiteSpace([string] $Folder.RelativePath)) {
                throw [InvalidOperationException]::new(
                    'Selected Menu Folder navigation requires an Entry Root and relative path.'
                )
            }
            $targetEntryName = [string] $Folder.EntryName
            $targetSelectedRelativePath = [string] $Folder.RelativePath
            $parentPath = [IO.Path]::GetDirectoryName($targetSelectedRelativePath)
            $targetRelativePath = if ($parentPath) { $parentPath } else { '' }
        }
        'ActivateEntry' {
            if ([string]::IsNullOrWhiteSpace($ActivatedEntryName)) {
                throw [InvalidOperationException]::new(
                    'Entry Root activation requires an Entry Root name.'
                )
            }
            $targetEntryName = $ActivatedEntryName
            $targetRelativePath = ''
            $targetSelectedRelativePath = ''
        }
    }

    [PSCustomObject] @{
        PSTypeName           = 'LaunchTree.NavigationState'
        EntryName            = $targetEntryName
        RelativePath         = $targetRelativePath
        SelectedRelativePath = $targetSelectedRelativePath
        ClearSearch          = $true
        BackEnabled          = -not (
            [string]::IsNullOrWhiteSpace($targetRelativePath) -and
            $targetSelectedRelativePath -eq $targetRelativePath
        )
    }
}