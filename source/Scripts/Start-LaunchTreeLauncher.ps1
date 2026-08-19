[CmdletBinding(DefaultParameterSetName = 'ByEntryId')]
param(
    [Parameter(Mandatory, ParameterSetName = 'ByEntryId')]
    [guid] $EntryId,

    [Parameter(Mandatory, ParameterSetName = 'ByEntryId')]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigurationPath,

    [Parameter(Mandatory, ParameterSetName = 'ByEntryName')]
    [ValidateNotNullOrEmpty()]
    [string] $EntryName,

    [Parameter(Mandatory, ParameterSetName = 'ByEntryName')]
    [ValidateNotNullOrEmpty()]
    [string] $ManagedRoot,

    [Parameter(ParameterSetName = 'ByEntryName')]
    [switch] $CloseAfterLaunch
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'LaunchTree.psd1'
Import-Module -Name $modulePath -Force -ErrorAction Stop

$parameters = if ($PSCmdlet.ParameterSetName -eq 'ByEntryId') {
    @{
        EntryId           = $EntryId
        ConfigurationPath = $ConfigurationPath
    }
} else {
    @{
        EntryName        = $EntryName
        ManagedRoot      = $ManagedRoot
        CloseAfterLaunch = $CloseAfterLaunch
    }
}
Show-LaunchTree @parameters