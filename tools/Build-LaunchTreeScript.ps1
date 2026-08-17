<#
    .SYNOPSIS
        Generates the single-file LaunchTree script from the module source.

    .DESCRIPTION
        Concatenates the private and public functions in the module source into
        one self-contained script that exposes the same logic without
        installing a module. The script is generated rather than maintained by
        hand so the single-file delivery cannot drift from the module.

        The Full variant embeds every function and exposes every command. The
        Minimal variant embeds only the functions Show-LaunchTree reaches and
        exposes only the parameters that opening an Entry Root needs.

    .PARAMETER SourcePath
        Specifies the module source directory to read functions from.

    .PARAMETER OutputPath
        Specifies the single-file script to create. Defaults to
        output\LaunchTree.ps1 or output\LaunchTree.Minimal.ps1 depending on the
        selected variant.

    .PARAMETER Version
        Specifies the version recorded in the generated script. Defaults to the
        built module version when one is available.

    .PARAMETER Variant
        Specifies which delivery to generate: Full or Minimal.

    .EXAMPLE
        .\Build-LaunchTreeScript.ps1

        Generates output\LaunchTree.ps1 from the current module source.

    .EXAMPLE
        .\Build-LaunchTreeScript.ps1 -Variant Minimal

        Generates the Launcher-only output\LaunchTree.Minimal.ps1.
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
    [string] $OutputPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $Version,

    [Parameter()]
    [ValidateSet('Full', 'Minimal')]
    [string] $Variant = 'Full'
)

$ErrorActionPreference = 'Stop'

# Entry point of the Minimal variant; its call graph decides what gets embedded.
$minimalEntryPoint = 'Show-LaunchTree'

function Get-LaunchTreeFunctionClosure {
    <#
        .SYNOPSIS
            Returns the entry points plus every module function they reach.

        .PARAMETER FunctionFile
            Specifies the module source function files to analyze.

        .PARAMETER EntryPoint
            Specifies the function names to start the traversal from.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]] $FunctionFile,

        [Parameter(Mandatory)]
        [string[]] $EntryPoint
    )

    $callMap = @{}
    foreach ($file in $FunctionFile) {
        $fileAst = [System.Management.Automation.Language.Parser]::ParseFile(
            $file.FullName, [ref] $null, [ref] $null
        )
        $callMap[$file.BaseName] = @(
            $fileAst.FindAll(
                {
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst]
                },
                $true
            ) |
                ForEach-Object { $_.GetCommandName() } |
                Where-Object { $_ }
        )
    }

    $closure = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $pending = [System.Collections.Generic.Queue[string]]::new()
    foreach ($name in $EntryPoint) {
        $pending.Enqueue($name)
    }

    while ($pending.Count -gt 0) {
        $name = $pending.Dequeue()
        if (-not $callMap.ContainsKey($name) -or -not $closure.Add($name)) {
            continue
        }

        foreach ($call in $callMap[$name]) {
            if ($callMap.ContainsKey($call) -and -not $closure.Contains($call)) {
                $pending.Enqueue($call)
            }
        }
    }

    , ([string[]] $closure)
}

function Get-LaunchTreeTokenSignature {
    <#
        .SYNOPSIS
            Returns the code-bearing token stream used to prove two scripts are
            semantically identical.

        .PARAMETER Content
            Specifies the script text to tokenize.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content
    )

    $contentTokens = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput(
        $Content, [ref] $contentTokens, [ref] $null
    )

    , [string[]] @(
        $contentTokens |
            Where-Object { $_.Kind -notin @('Comment', 'NewLine') } |
            ForEach-Object { '{0}:{1}' -f $_.Kind, $_.Text }
    )
}

function ConvertTo-LaunchTreeCompactScript {
    <#
        .SYNOPSIS
            Returns the script text without its comments or their blank lines.

        .DESCRIPTION
            Deletes every comment except a #Requires statement, then drops
            whitespace-only lines that no multi-line string owns. The caller
            verifies the result against the original token signature.

        .PARAMETER Content
            Specifies the generated script text to reduce.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Content
    )

    $contentTokens = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput(
        $Content, [ref] $contentTokens, [ref] $null
    )

    $builder = [System.Text.StringBuilder]::new($Content)
    $removable = @(
        $contentTokens |
            Where-Object { $_.Kind -eq 'Comment' -and $_.Text -notmatch '^\s*#requires' } |
            Sort-Object -Property { $_.Extent.StartOffset } -Descending
    )
    foreach ($token in $removable) {
        $null = $builder.Remove(
            $token.Extent.StartOffset,
            $token.Extent.EndOffset - $token.Extent.StartOffset
        )
    }

    $reduced = $builder.ToString()

    $reducedTokens = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput(
        $reduced, [ref] $reducedTokens, [ref] $null
    )

    # A here-string owns its blank lines; dropping one would change its value.
    $protectedLine = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($token in $reducedTokens) {
        if ($token.Kind -notin @('NewLine', 'LineContinuation', 'Comment') -and
            $token.Extent.EndLineNumber -gt $token.Extent.StartLineNumber) {
            for (
                $line = $token.Extent.StartLineNumber
                $line -le $token.Extent.EndLineNumber
                $line++
            ) {
                $null = $protectedLine.Add($line)
            }
        }
    }

    $reducedLines = $reduced -split "\r?\n"
    $keptLines = @(
        for ($index = 0; $index -lt $reducedLines.Count; $index++) {
            if ($reducedLines[$index].Trim() -ne '' -or
                $protectedLine.Contains($index + 1)) {
                $reducedLines[$index]
            }
        }
    )

    ($keptLines -join "`r`n") + "`r`n"
}

if (-not $PSBoundParameters.ContainsKey('OutputPath')) {
    $outputFileName = if ($Variant -eq 'Minimal') {
        'LaunchTree.Minimal.ps1'
    } else {
        'LaunchTree.ps1'
    }
    $OutputPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) `
        -ChildPath "output\$outputFileName"
}

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

$moduleFunctionNames = @($functionFiles.BaseName)

if ($Variant -eq 'Minimal') {
    $includedNames = Get-LaunchTreeFunctionClosure -FunctionFile $functionFiles `
        -EntryPoint $minimalEntryPoint
    $functionFiles = @($functionFiles | Where-Object { $_.BaseName -in $includedNames })
}

$publicNames = @(
    Get-ChildItem -LiteralPath (Join-Path -Path $SourcePath -ChildPath 'Public') `
        -Filter '*.ps1' -File |
        Sort-Object -Property Name |
        ForEach-Object { $_.BaseName } |
        Where-Object { $_ -in $functionFiles.BaseName }
)

$fullHeader = @'
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

$minimalHeader = @'
<#
    .SYNOPSIS
        Minimal self-contained LaunchTree delivery that only opens the Launcher.

    .DESCRIPTION
        Contains only the LaunchTree logic that Show-LaunchTree needs, so it is
        markedly smaller than the full single-file script. Reconciliation,
        health checks, diagnostics, Support Bundle export, removal, and the
        Event Log probe are not part of this delivery; use the full script or
        the module for those. This file is generated from the module source by
        tools\Build-LaunchTreeScript.ps1 -Variant Minimal; edit the module
        source instead of this script.

    .PARAMETER Command
        Specifies the operation to run. Only Show is supported. Omit it and
        dot-source the script to load the embedded commands instead.

    .PARAMETER EntryName
        Specifies the Entry Root to open.

    .PARAMETER ManagedRoot
        Overrides the Managed Root that supplies Entry Roots.

    .EXAMPLE
        .\LaunchTree.Minimal.ps1 -Command Show -ManagedRoot D:\temp\ -EntryName Programs

        Opens the Programs Entry Root below the supplied Managed Root.
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Show')]
    [string] $Command,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $EntryName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ManagedRoot
)

$script:LaunchTreeStandalonePath = if ($PSCommandPath) {
    $PSCommandPath
} else {
    $MyInvocation.MyCommand.Path
}
$script:LaunchTreeStandaloneVersion = '__LAUNCHTREE_VERSION__'
'@

$fullFooter = @'

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

$minimalFooter = @'

if (-not $Command) {
    return
}

$splat = @{}
foreach ($parameterName in @('EntryName', 'ManagedRoot')) {
    if ($PSBoundParameters.ContainsKey($parameterName)) {
        $splat[$parameterName] = $PSBoundParameters[$parameterName]
    }
}

Show-LaunchTree @splat
'@

$header = if ($Variant -eq 'Minimal') { $minimalHeader } else { $fullHeader }
$footer = if ($Variant -eq 'Minimal') { $minimalFooter } else { $fullFooter }
$header = $header.Replace('__LAUNCHTREE_VERSION__', $Version)

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

$tokens = $null
$parseErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseInput(
    $content, [ref] $tokens, [ref] $parseErrors
)
if ($parseErrors.Count -gt 0) {
    throw [System.InvalidOperationException]::new(
        "The generated script has $($parseErrors.Count) parse error(s): " +
        ($parseErrors[0].Message)
    )
}

# A dropped function may still be reached through a name held in a string, which
# the call-graph traversal cannot see, so verify the result over the real code.
$executableText = -join @(
    $tokens | Where-Object { $_.Kind -ne 'Comment' } | ForEach-Object { "$($_.Text)`n" }
)
$omittedReferences = @(
    $moduleFunctionNames |
        Where-Object { $_ -notin $functionFiles.BaseName } |
        Where-Object { $executableText -match "\b$([regex]::Escape($_))\b" } |
        Sort-Object
)
if ($omittedReferences.Count -gt 0) {
    throw [System.InvalidOperationException]::new(
        "The generated script references omitted function(s): " +
        "$($omittedReferences -join ', ')."
    )
}

if ($Variant -eq 'Minimal') {
    $originalSignature = Get-LaunchTreeTokenSignature -Content $content
    $content = ConvertTo-LaunchTreeCompactScript -Content $content
    $reducedSignature = Get-LaunchTreeTokenSignature -Content $content

    if (Compare-Object -ReferenceObject $originalSignature `
            -DifferenceObject $reducedSignature -SyncWindow 0) {
        throw [System.InvalidOperationException]::new(
            'Comment removal changed the generated script beyond its comments.'
        )
    }

    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput(
        $content, [ref] $null, [ref] $parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw [System.InvalidOperationException]::new(
            "Comment removal broke the generated script: $($parseErrors[0].Message)"
        )
    }
}

if ($PSCmdlet.ShouldProcess($OutputPath, 'Write single-file LaunchTree script')) {
    $outputDirectory = Split-Path -Path $OutputPath -Parent
    $null = New-Item -Path $outputDirectory -ItemType Directory -Force
    [IO.File]::WriteAllText($OutputPath, $content, [Text.UTF8Encoding]::new($false))
}

[PSCustomObject] @{
    Path          = $OutputPath
    Variant       = $Variant
    Version       = $Version
    FunctionCount = $functionFiles.Count
    PublicCommand = $publicNames
    Bytes         = $content.Length
    LineCount     = ($content -split "\r?\n").Count
}
