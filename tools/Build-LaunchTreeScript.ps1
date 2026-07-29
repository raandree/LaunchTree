<#
    .SYNOPSIS
        Generates the single-file LaunchTree script from the module source.

    .DESCRIPTION
        Concatenates every private and public function in the module source
        into one self-contained script that exposes the same logic without
        installing a module. The script is generated rather than maintained by
        hand so the single-file delivery cannot drift from the module.

    .PARAMETER SourcePath
        Specifies the module source directory to read functions from.

    .PARAMETER OutputPath
        Specifies the single-file script to create.

    .PARAMETER Version
        Specifies the version recorded in the generated script. Defaults to the
        built module version when one is available.

    .EXAMPLE
        .\Build-LaunchTreeScript.ps1

        Generates output\LaunchTree.ps1 from the current module source.
#>
[CmdletBinding(SupportsShouldProcess)]
[OutputType([PSCustomObject])]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $SourcePath = (
        Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'source'
    ),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $OutputPath = (
        Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) `
            -ChildPath 'output\LaunchTree.ps1'
    ),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $Version
)

$ErrorActionPreference = 'Stop'

if (-not $PSBoundParameters.ContainsKey('Version')) {
    $builtManifest = Get-ChildItem -Path (
        Join-Path -Path (Split-Path -Path $OutputPath -Parent) -ChildPath 'module\LaunchTree'
    ) -Recurse -Filter 'LaunchTree.psd1' -ErrorAction SilentlyContinue |
        Sort-Object -Property FullName -Descending |
        Select-Object -First 1
    $Version = if ($builtManifest) {
        (Import-PowerShellDataFile -LiteralPath $builtManifest.FullName).ModuleVersion
    } else {
        '0.0.0'
    }
}

$functionFiles = @(
    foreach ($directory in @('Private', 'Public')) {
        $directoryPath = Join-Path -Path $SourcePath -ChildPath $directory
        Get-ChildItem -LiteralPath $directoryPath -Filter '*.ps1' -File |
            Sort-Object -Property Name
    }
)
if ($functionFiles.Count -eq 0) {
    throw [System.IO.FileNotFoundException]::new(
        'No module source functions were found.',
        $SourcePath
    )
}

$publicNames = @(
    Get-ChildItem -LiteralPath (Join-Path -Path $SourcePath -ChildPath 'Public') `
        -Filter '*.ps1' -File |
        Sort-Object -Property Name |
        ForEach-Object { $_.BaseName }
)

$header = @'
<#
    .SYNOPSIS
        Self-contained LaunchTree delivery that needs no installed module.

    .DESCRIPTION
        Contains the complete LaunchTree logic in one script. Dot-source it to
        expose every LaunchTree command in the current session, or use -Command
        to run a single operation. This file is generated from the module
        source by tools\Build-LaunchTreeScript.ps1; edit the module source
        instead of this script.

        Reconciliation performed by this script points its Start Entries at this
        script file, so keep it at a stable machine-wide path such as
        %ProgramFiles%\LaunchTree\LaunchTree.ps1.

    .PARAMETER Command
        Specifies the operation to run. Omit it and dot-source the script to
        load the commands instead.

    .PARAMETER Force
        Suppresses confirmation for the Update and Remove commands.

    .EXAMPLE
        . .\LaunchTree.ps1
        Update-LaunchTree -Confirm:$false

        Loads every command into the session and reconciles Start Entries.

    .EXAMPLE
        .\LaunchTree.ps1 -Command Update -Force

        Reconciles Start Entries without loading the commands.

    .EXAMPLE
        .\LaunchTree.ps1 -Command Show -EntryName 'LaunchTree Demo'

        Opens an Entry Root in the WPF Launcher.
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet(
        'Show',
        'Update',
        'Test',
        'GetConfiguration',
        'GetDiagnostic',
        'ExportSupportBundle',
        'Remove',
        'EventLogProbe'
    )]
    [string] $Command,

    [Parameter()]
    [guid] $EntryId,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $EntryName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigurationPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ManagedRoot,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $PersonalRoot,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $GeneratedStatePath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $StartMenuPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $PreferencePath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $CachePath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $CapturePath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $Path,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $LogName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $SourceName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $Nonce,

    [Parameter()]
    [datetime] $Since,

    [Parameter()]
    [int[]] $EventId,

    [Parameter()]
    [switch] $SkipEventLog,

    [Parameter()]
    [switch] $SkipEventLogRegistration,

    [Parameter()]
    [switch] $Force
)

$script:LaunchTreeStandalonePath = if ($PSCommandPath) {
    $PSCommandPath
} else {
    $MyInvocation.MyCommand.Path
}
$script:LaunchTreeStandaloneVersion = '__LAUNCHTREE_VERSION__'
'@

$header = $header.Replace('__LAUNCHTREE_VERSION__', $Version)

$footer = @'

$script:LaunchTreeCommandMap = @{
    Show                = 'Show-LaunchTree'
    Update              = 'Update-LaunchTree'
    Test                = 'Test-LaunchTree'
    GetConfiguration    = 'Get-LaunchTreeConfiguration'
    GetDiagnostic       = 'Get-LaunchTreeDiagnostic'
    ExportSupportBundle = 'Export-LaunchTreeSupportBundle'
    Remove              = 'Remove-LaunchTree'
}

if (-not $Command) {
    return
}

if ($Command -eq 'EventLogProbe') {
    exit (Invoke-LaunchTreeEventLogAccessProbe -LogName $LogName `
            -SourceName $SourceName -Nonce $Nonce)
}

$targetCommand = $script:LaunchTreeCommandMap[$Command]
$targetParameters = (Get-Command -Name $targetCommand -CommandType Function).Parameters
$unsupportedParameters = @(
    $PSBoundParameters.Keys |
        Where-Object { $_ -notin @('Command', 'Force') } |
        Where-Object { -not $targetParameters.ContainsKey($_) } |
        Sort-Object
)
if ($unsupportedParameters.Count -gt 0) {
    throw [System.ArgumentException]::new(
        "Command '$Command' does not support: $($unsupportedParameters -join ', ')."
    )
}

$splat = @{}
foreach ($parameterName in $PSBoundParameters.Keys) {
    if ($targetParameters.ContainsKey($parameterName)) {
        $splat[$parameterName] = $PSBoundParameters[$parameterName]
    }
}
if ($Force -and $targetParameters.ContainsKey('Confirm')) {
    $splat['Confirm'] = $false
}

& $targetCommand @splat
'@

$builder = [System.Text.StringBuilder]::new()
[void] $builder.AppendLine($header)
[void] $builder.AppendLine()
[void] $builder.AppendLine('#region LaunchTree functions')
foreach ($functionFile in $functionFiles) {
    [void] $builder.AppendLine()
    [void] $builder.AppendLine("# ---- $($functionFile.BaseName) ----")
    [void] $builder.AppendLine(
        (Get-Content -LiteralPath $functionFile.FullName -Raw).TrimEnd()
    )
}
[void] $builder.AppendLine()
[void] $builder.AppendLine('#endregion LaunchTree functions')
[void] $builder.AppendLine($footer)

$content = $builder.ToString()

$parseErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseInput(
    $content, [ref] $null, [ref] $parseErrors
)
if ($parseErrors.Count -gt 0) {
    throw [System.InvalidOperationException]::new(
        "The generated script has $($parseErrors.Count) parse error(s): " +
        ($parseErrors[0].Message)
    )
}

if ($PSCmdlet.ShouldProcess($OutputPath, 'Write single-file LaunchTree script')) {
    $outputDirectory = Split-Path -Path $OutputPath -Parent
    $null = New-Item -Path $outputDirectory -ItemType Directory -Force
    [IO.File]::WriteAllText($OutputPath, $content, [Text.UTF8Encoding]::new($false))
}

[PSCustomObject] @{
    Path          = $OutputPath
    Version       = $Version
    FunctionCount = $functionFiles.Count
    PublicCommand = $publicNames
    Bytes         = $content.Length
}
