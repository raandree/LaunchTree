function ConvertTo-StartMenuFolderRedactedText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string] $InputObject
    )

    process {
        [regex]::Replace(
            $InputObject,
            '(?i)(https?://[^\s?"''<>]+)\?[^\s"''<>]+',
            '$1?[redacted]'
        )
    }
}