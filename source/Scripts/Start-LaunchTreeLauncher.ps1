[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [guid] $EntryId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigurationPath
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'LaunchTree.psd1'
Import-Module -Name $modulePath -Force -ErrorAction Stop

$parameters = @{
    EntryId           = $EntryId
    ConfigurationPath = $ConfigurationPath
}
Show-LaunchTree @parameters