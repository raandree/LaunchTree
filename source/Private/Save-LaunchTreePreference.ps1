function Save-StartMenuFolderPreference {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Private Launcher helper writes only the current user preference file.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject] $Configuration,

        [Parameter(Mandatory)]
        [ValidateSet('NameAscending', 'NameDescending')]
        [string] $SortOrder,

        [Parameter(Mandatory)]
        [double] $Width,

        [Parameter(Mandatory)]
        [double] $Height,

        [Parameter(Mandatory)]
        [double] $Left,

        [Parameter(Mandatory)]
        [double] $Top
    )

    $preference = [ordered] @{
        SchemaVersion    = 1
        SortOrder        = $SortOrder
        CloseAfterLaunch = [bool] $Configuration.CloseAfterLaunch
        Window           = [ordered] @{
            Width  = [Math]::Round($Width, 2)
            Height = [Math]::Round($Height, 2)
            Left   = [Math]::Round($Left, 2)
            Top    = [Math]::Round($Top, 2)
        }
    }
    $preferencePath = [string] $Configuration.PreferencePath
    $directory = Split-Path -Path $preferencePath -Parent
    $null = New-Item -Path $directory -ItemType Directory -Force
    $temporaryPath = "$preferencePath.$([guid]::NewGuid().ToString('N')).tmp"
    $json = $preference | ConvertTo-Json -Depth 4
    [IO.File]::WriteAllText($temporaryPath, $json, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryPath -Destination $preferencePath -Force
}