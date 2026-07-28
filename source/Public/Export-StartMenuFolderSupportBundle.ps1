function Export-StartMenuFolderSupportBundle {
    <#
        .SYNOPSIS
            Exports a redacted StartMenuFolders Support Bundle.

        .DESCRIPTION
            Creates a ZIP archive containing effective configuration summaries,
            health results, cache metadata, and redacted diagnostic events. The
            archive excludes Launch Item targets, arguments, and URL queries.

        .PARAMETER Path
            Specifies the ZIP archive path to create or replace.

        .PARAMETER ConfigurationPath
            Specifies an alternate machine configuration JSON file.

        .EXAMPLE
            Export-StartMenuFolderSupportBundle -Path C:\Temp\StartMenuFolders.zip

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
        [string] $ConfigurationPath
    )

    $outputPath = [IO.Path]::GetFullPath($Path)
    if (-not $PSCmdlet.ShouldProcess($outputPath, 'Export redacted Support Bundle')) {
        return
    }

    $configurationParameters = @{}
    if ($PSBoundParameters.ContainsKey('ConfigurationPath')) {
        $configurationParameters.ConfigurationPath = $ConfigurationPath
    }
    $configuration = Get-StartMenuFolderConfiguration @configurationParameters
    $healthParameters = @{}
    if ($PSBoundParameters.ContainsKey('ConfigurationPath')) {
        $healthParameters.ConfigurationPath = $ConfigurationPath
    }
    $health = Test-StartMenuFolder @healthParameters
    $diagnostics = @(Get-StartMenuFolderDiagnostic -LogName $configuration.Diagnostics.LogName)

    $temporaryPath = Join-Path $env:TEMP (
        'StartMenuFolders-support-{0}' -f [guid]::NewGuid().ToString('N')
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
            $redactedJson = ConvertTo-StartMenuFolderRedactedText -InputObject $json
            $filePath = Join-Path $temporaryPath $fileName
            [IO.File]::WriteAllText($filePath, $redactedJson, [Text.UTF8Encoding]::new($false))
        }

        $outputDirectory = Split-Path -Path $outputPath -Parent
        $null = New-Item -Path $outputDirectory -ItemType Directory -Force
        if (Test-Path -LiteralPath $outputPath -PathType Leaf) {
            Remove-Item -LiteralPath $outputPath -Force
        }
        Compress-Archive -Path (Join-Path $temporaryPath '*') -DestinationPath $outputPath -Force
    } finally {
        Remove-Item -LiteralPath $temporaryPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    $outputPath
}