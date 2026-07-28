function Import-LaunchTreeJson {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath
    )

    try {
        $value = Get-Content -LiteralPath $LiteralPath -Raw -Encoding UTF8 -ErrorAction Stop |
            ConvertFrom-Json -ErrorAction Stop

        [PSCustomObject] @{
            Succeeded = $true
            Value     = $value
            Message   = $null
        }
    } catch {
        $errorRecord = $_
        [PSCustomObject] @{
            Succeeded = $false
            Value     = $null
            Message   = $errorRecord.Exception.Message
        }
    }
}