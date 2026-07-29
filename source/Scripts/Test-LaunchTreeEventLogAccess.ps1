[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $LogName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $SourceName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Nonce
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'LaunchTree.psd1'
Import-Module -Name $modulePath -Force -ErrorAction Stop

$module = Get-Module -Name 'LaunchTree'
$exitCode = & $module {
    param($ProbeLogName, $ProbeSourceName, $ProbeNonce)
    Invoke-LaunchTreeEventLogAccessProbe -LogName $ProbeLogName `
        -SourceName $ProbeSourceName -Nonce $ProbeNonce
} $LogName $SourceName $Nonce

exit $exitCode