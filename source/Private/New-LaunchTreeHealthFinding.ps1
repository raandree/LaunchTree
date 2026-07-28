function New-StartMenuFolderHealthFinding {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Creates an in-memory object and does not change system state.'
    )]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Code,

        [Parameter(Mandatory)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string] $Severity,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Message,

        [Parameter()]
        [AllowNull()]
        [string] $Path
    )

    [PSCustomObject] @{
        PSTypeName = 'StartMenuFolders.HealthFinding'
        Code       = $Code
        Severity   = $Severity
        Message    = $Message
        Path       = $Path
    }
}