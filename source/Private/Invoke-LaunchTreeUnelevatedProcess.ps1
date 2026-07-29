function Invoke-LaunchTreeUnelevatedProcess {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ApplicationPath,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Arguments,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $WorkingDirectory,

        [Parameter(Mandatory)]
        [int] $TimeoutMilliseconds
    )

    Initialize-LaunchTreeUnelevatedProcess
    [LaunchTree.UnelevatedProcess]::Run(
        $ApplicationPath,
        $Arguments,
        $WorkingDirectory,
        $TimeoutMilliseconds
    )
}
