function ConvertTo-StartMenuFolderCommandLineArgument {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Value
    )

    if ($Value.Contains('"')) {
        throw [System.ArgumentException]::new(
            'A Windows command-line argument cannot contain an unescaped double quote.',
            'Value'
        )
    }

    $escapedValue = [regex]::Replace($Value, '(\+)$', '$1$1')
    '"{0}"' -f $escapedValue
}