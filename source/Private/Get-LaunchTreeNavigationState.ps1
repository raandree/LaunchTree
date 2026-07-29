function Get-LaunchTreeNavigationState {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Back', 'SelectFolder', 'ActivateEntry')]
        [string] $Action,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $EntryName,

        [Parameter()]
        [AllowEmptyString()]
        [string] $CurrentRelativePath = '',

        [Parameter()]
        [AllowNull()]
        [PSCustomObject] $Folder,

        [Parameter()]
        [AllowNull()]
        [string] $ActivatedEntryName
    )

    $targetEntryName = $EntryName
    $targetRelativePath = $CurrentRelativePath
    switch ($Action) {
        'Back' {
            $parentPath = [IO.Path]::GetDirectoryName($CurrentRelativePath)
            $targetRelativePath = if ($parentPath) { $parentPath } else { '' }
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
            $targetRelativePath = [string] $Folder.RelativePath
        }
        'ActivateEntry' {
            if ([string]::IsNullOrWhiteSpace($ActivatedEntryName)) {
                throw [InvalidOperationException]::new(
                    'Entry Root activation requires an Entry Root name.'
                )
            }
            $targetEntryName = $ActivatedEntryName
            $targetRelativePath = ''
        }
    }

    [PSCustomObject] @{
        PSTypeName   = 'LaunchTree.NavigationState'
        EntryName    = $targetEntryName
        RelativePath = $targetRelativePath
        ClearSearch  = $true
        BackEnabled  = -not [string]::IsNullOrWhiteSpace($targetRelativePath)
    }
}