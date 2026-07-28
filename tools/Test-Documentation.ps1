[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $RepositoryRoot = (Split-Path -Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
$repositoryPath = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$documentationPaths = @(
    (Join-Path -Path $repositoryPath -ChildPath 'docs')
    (Join-Path -Path $repositoryPath -ChildPath '.memory-bank')
)

$healthScript = Join-Path -Path $HOME -ChildPath (
    '.copilot/skills/memory-bank/scripts/Test-MemoryBankHealth.ps1'
)
$health = & $healthScript -Path $repositoryPath
if (-not $health.Passed) {
    throw 'Memory Bank health validation failed.'
}

$expectedIdentifiers = [ordered] @{
    FR  = 1..33 | ForEach-Object { 'FR-{0:d3}' -f $_ }
    QR  = 1..22 | ForEach-Object { 'QR-{0:d3}' -f $_ }
    CR  = 1..12 | ForEach-Object { 'CR-{0:d3}' -f $_ }
    AS  = 1..17 | ForEach-Object { 'AS-{0:d3}' -f $_ }
    ADR = 1..10 | ForEach-Object { 'ADR-{0:d4}' -f $_ }
    OI  = 1..9 | ForEach-Object { 'OI-{0:d3}' -f $_ }
}

$definitions = @{}
$references = @{}
$markdownFiles = @(Get-ChildItem -LiteralPath $documentationPaths -Recurse -Filter '*.md' -File)

foreach ($file in $markdownFiles) {
    foreach ($line in Get-Content -LiteralPath $file.FullName -Encoding UTF8) {
        $definition = $null
        if ($line -match '^### ((?:FR|QR|CR|OI)-\d{3})(?: |:)') {
            $definition = $Matches[1]
        } elseif ($line -match '^\| (AS-\d{3}) ') {
            $definition = $Matches[1]
        } elseif ($line -match '^id: (ADR-\d{4})$') {
            $definition = $Matches[1]
        }

        if ($definition) {
            if ($definitions.ContainsKey($definition)) {
                throw "Duplicate identifier '$definition'."
            }
            $definitions[$definition] = $file.FullName
        }

        foreach ($match in [regex]::Matches($line, '(?:FR|QR|CR|AS|ADR|OI)-\d{3,4}')) {
            $references[$match.Value] = $true
        }

        foreach ($match in [regex]::Matches($line, '\[[^\]]+\]\((?<target>[^)]+)\)')) {
            $target = ($match.Groups['target'].Value -split '#', 2)[0]
            if ([string]::IsNullOrWhiteSpace($target) -or $target -match '^(?:https?|mailto):') {
                continue
            }

            $resolvedTarget = [IO.Path]::GetFullPath(
                (Join-Path -Path $file.DirectoryName -ChildPath $target)
            )
            if (-not (Test-Path -LiteralPath $resolvedTarget)) {
                throw "Broken local link '$target' in '$($file.FullName)'."
            }
        }
    }
}

foreach ($identifierType in $expectedIdentifiers.Keys) {
    foreach ($identifier in $expectedIdentifiers[$identifierType]) {
        if (-not $definitions.ContainsKey($identifier)) {
            throw "Missing definition '$identifier'."
        }
    }
}

foreach ($reference in $references.Keys) {
    if (-not $definitions.ContainsKey($reference)) {
        throw "Unresolved identifier '$reference'."
    }
}

$designPath = Join-Path -Path $repositoryPath -ChildPath 'docs/design-concept.md'
$design = Get-Content -LiteralPath $designPath -Raw -Encoding UTF8
if ($design -notmatch '> Status: SIGNED OFF') {
    throw 'The Design Concept is not signed off.'
}

$issuePath = Join-Path -Path $repositoryPath -ChildPath 'docs/open-issues.md'
$issueText = Get-Content -LiteralPath $issuePath -Raw -Encoding UTF8
foreach ($issue in $expectedIdentifiers.OI) {
    $issuePattern = '(?m)^### {0}:' -f [regex]::Escape($issue)
    if ([regex]::Matches($issueText, $issuePattern).Count -ne 1) {
        throw "Issue '$issue' must have exactly one detailed record."
    }
}

[PSCustomObject] @{
    MemoryBank         = 'Passed'
    CanonicalFiles     = $health.CanonicalFileCount
    MarkdownFiles      = $markdownFiles.Count
    ContractDefinitions = $definitions.Count
    LocalLinks         = 'Passed'
    IdentifierReferences = 'Passed'
    DesignStatus       = 'SIGNED OFF'
}