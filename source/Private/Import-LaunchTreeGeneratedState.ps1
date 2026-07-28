function Import-LaunchTreeGeneratedState {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath
    )

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        return $null
    }

    $result = Import-LaunchTreeJson -LiteralPath $LiteralPath
    if (-not $result.Succeeded) {
        throw [System.IO.InvalidDataException]::new(
            "Generated State is invalid: $($result.Message)"
        )
    }
    if (-not $result.Value.PSObject.Properties['SchemaVersion'] -or
        [int] $result.Value.SchemaVersion -ne 1) {
        throw [System.IO.InvalidDataException]::new(
            'Generated State uses an unsupported schema version.'
        )
    }

    $result.Value
}