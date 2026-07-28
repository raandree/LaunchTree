function Resolve-StartMenuFolderEntry {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [guid] $EntryId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ManagedRoot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $GeneratedStatePath
    )

    $state = Import-StartMenuFolderGeneratedState -LiteralPath $GeneratedStatePath
    if (-not $state) {
        throw [System.IO.FileNotFoundException]::new(
            'Generated State is required to resolve an Entry ID.',
            $GeneratedStatePath
        )
    }

    $expectedRoot = [IO.Path]::GetFullPath($ManagedRoot).TrimEnd('\', '/')
    $stateRoot = [IO.Path]::GetFullPath([string] $state.ManagedRoot).TrimEnd('\', '/')
    if (-not $expectedRoot.Equals($stateRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw [System.Security.SecurityException]::new(
            'Generated State does not match the configured Managed Root.'
        )
    }

    $matchingEntry = @($state.StartEntries | Where-Object {
        [guid] $_.EntryId -eq $EntryId
    }) | Select-Object -First 1
    if (-not $matchingEntry) {
        throw [System.Collections.Generic.KeyNotFoundException]::new(
            "Entry ID '$EntryId' is not present in Generated State."
        )
    }

    $entryRootPath = [IO.Path]::GetFullPath([string] $matchingEntry.EntryRootPath)
    $requiredPrefix = $expectedRoot + [IO.Path]::DirectorySeparatorChar
    if (-not $entryRootPath.StartsWith($requiredPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw [System.Security.SecurityException]::new(
            'The Entry Root is outside the configured Managed Root.'
        )
    }
    if (-not (Test-Path -LiteralPath $entryRootPath -PathType Container)) {
        throw [System.IO.DirectoryNotFoundException]::new(
            "The Entry Root '$entryRootPath' does not exist."
        )
    }

    [PSCustomObject] @{
        PSTypeName    = 'StartMenuFolders.EntryReference'
        EntryId       = $EntryId
        Name          = [string] $matchingEntry.Name
        EntryRootPath = $entryRootPath
    }
}