function Export-LaunchTreeSupportBundle {
    <#
        .SYNOPSIS
            Exports a redacted LaunchTree Support Bundle.

        .DESCRIPTION
            Creates a ZIP archive containing effective configuration summaries,
            health results, cache metadata, and redacted diagnostic events. The
            archive excludes Launch Item targets, arguments, and URL queries.

        .PARAMETER Path
            Specifies the ZIP archive path to create or replace.

        .PARAMETER ConfigurationPath
            Specifies an alternate machine configuration JSON file.

        .PARAMETER ManagedRoot
            Overrides the Managed Root that supplies Entry Roots.

        .PARAMETER PersonalRoot
            Overrides the Personal Root merged into matching Entry Roots.

        .EXAMPLE
            Export-LaunchTreeSupportBundle -Path C:\Temp\LaunchTree.zip

            Exports a redacted Support Bundle to the requested path.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ManagedRoot,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $PersonalRoot
    )

    $outputPath = [IO.Path]::GetFullPath($Path)
    if (-not $PSCmdlet.ShouldProcess($outputPath, 'Export redacted Support Bundle')) {
        return
    }

    $configurationParameters = @{}
    if ($PSBoundParameters.ContainsKey('ConfigurationPath')) {
        $configurationParameters.ConfigurationPath = $ConfigurationPath
    }
    if ($PSBoundParameters.ContainsKey('ManagedRoot')) {
        $configurationParameters.ManagedRoot = $ManagedRoot
    }
    if ($PSBoundParameters.ContainsKey('PersonalRoot')) {
        $configurationParameters.PersonalRoot = $PersonalRoot
    }
    $configuration = Get-LaunchTreeConfiguration @configurationParameters
    $health = Test-LaunchTree @configurationParameters
    $diagnostics = @(Get-LaunchTreeDiagnostic -LogName $configuration.Diagnostics.LogName)

    $temporaryPath = Join-Path $env:TEMP (
        'LaunchTree-support-{0}' -f [guid]::NewGuid().ToString('N')
    )
    $null = New-Item -Path $temporaryPath -ItemType Directory -Force
    try {
        $configurationSummary = [ordered] @{
            VendorName        = $configuration.VendorName
            ManagedRoot       = $configuration.ManagedRoot
            PersonalRoot      = $configuration.PersonalRoot
            ConfigurationPath = $configuration.ConfigurationPath
            PreferencePath    = $configuration.PreferencePath
            Cache             = $configuration.Cache
            Diagnostics       = $configuration.Diagnostics
        }
        $files = [ordered] @{
            'configuration.json' = $configurationSummary
            'health.json'        = $health
            'diagnostics.json'   = $diagnostics
        }
        foreach ($fileName in $files.Keys) {
            $json = $files[$fileName] | ConvertTo-Json -Depth 8
            $redactedJson = ConvertTo-LaunchTreeRedactedText -InputObject $json
            $filePath = Join-Path $temporaryPath $fileName
            [IO.File]::WriteAllText($filePath, $redactedJson, [Text.UTF8Encoding]::new($false))
        }

        $outputDirectory = Split-Path -Path $outputPath -Parent
        $null = New-Item -Path $outputDirectory -ItemType Directory -Force
        if (Test-Path -LiteralPath $outputPath -PathType Leaf) {
            Remove-Item -LiteralPath $outputPath -Force
        }
        Compress-Archive -Path (Join-Path $temporaryPath '*') -DestinationPath $outputPath -Force
    } catch {
        $bundleError = $_
        $eventParameters = @{
            Configuration = $configuration
            EventId       = 1601
            Level         = 'Error'
            Operation     = 'SupportBundle'
            Message       = $bundleError.Exception.Message
            Path          = $outputPath
            ErrorCode     = $bundleError.FullyQualifiedErrorId
        }
        $null = Write-LaunchTreeEvent @eventParameters
        throw
    } finally {
        Remove-Item -LiteralPath $temporaryPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    $outputPath
}