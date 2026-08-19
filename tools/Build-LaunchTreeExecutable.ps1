<#
    .SYNOPSIS
        Compiles a generated single-file LaunchTree script into an executable.

    .DESCRIPTION
        Embeds the generated script as a managed resource in a small .NET
        Framework host that runs it in an STA PowerShell runspace, so the
        executable exposes the same parameter surface as the script it was
        built from and still needs nothing installed on the target machine.

        The host source is compiled with the in-box .NET Framework C# compiler.
        No external module or SDK is involved, so the executable is generated
        the same way the single-file script is.

        The Full variant is a console application that hides a console it
        created for itself, so a Start Entry or a double click shows no console
        window while a terminal still sees the output. The Minimal variant is a
        windows application, because it only opens the Launcher.

    .PARAMETER ScriptPath
        Specifies the generated single-file script to embed.

    .PARAMETER OutputPath
        Specifies the executable to create. Defaults to the script path with an
        .exe extension.

    .PARAMETER Version
        Specifies the version recorded in the executable file details.

    .PARAMETER Variant
        Specifies which delivery to compile: Full or Minimal.

    .PARAMETER IconPath
        Specifies the application icon to embed.

    .PARAMETER HostSourcePath
        Specifies the C# host source compiled around the embedded script.

    .PARAMETER BootstrapPath
        Specifies the PowerShell bootstrap the compiled host runs to bind the
        command line to the embedded script.

    .EXAMPLE
        .\Build-LaunchTreeExecutable.ps1 -ScriptPath ..\output\LaunchTree.ps1

        Compiles output\LaunchTree.exe from the full single-file script.

    .EXAMPLE
        .\Build-LaunchTreeExecutable.ps1 -ScriptPath ..\output\LaunchTree.Minimal.ps1 -Variant Minimal

        Compiles the Launcher-only output\LaunchTree.Minimal.exe.
#>
[CmdletBinding(SupportsShouldProcess)]
[OutputType([PSCustomObject])]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ScriptPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $OutputPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $Version = '0.0.0',

    [Parameter()]
    [ValidateSet('Full', 'Minimal')]
    [string] $Variant = 'Full',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $IconPath = (
        Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) `
            -ChildPath 'source\Assets\LaunchTree.ico'
    ),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $HostSourcePath = (
        Join-Path -Path $PSScriptRoot -ChildPath 'StandaloneHost\LaunchTreeStandaloneHost.cs'
    ),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $BootstrapPath = (
        Join-Path -Path $PSScriptRoot -ChildPath 'StandaloneHost\Invoke-LaunchTreeEmbeddedScript.ps1'
    )
)

$ErrorActionPreference = 'Stop'

$script:ScriptResourceName = 'LaunchTree.EmbeddedScript.ps1'
$script:BootstrapResourceName = 'LaunchTree.Bootstrap.ps1'

function Get-LaunchTreeCompilerPath {
    <#
        .SYNOPSIS
            Returns the in-box .NET Framework C# compiler.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $frameworkRoot = Join-Path -Path $env:WINDIR -ChildPath 'Microsoft.NET'
    $candidates = @(
        Join-Path -Path $frameworkRoot -ChildPath 'Framework64\v4.0.30319\csc.exe'
        Join-Path -Path $frameworkRoot -ChildPath 'Framework\v4.0.30319\csc.exe'
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    throw [System.IO.FileNotFoundException]::new(
        'The in-box .NET Framework 4 C# compiler was not found; the executable cannot be built.',
        $candidates[0]
    )
}

function Get-LaunchTreeAutomationReferencePath {
    <#
        .SYNOPSIS
            Returns the .NET Framework System.Management.Automation assembly.

        .DESCRIPTION
            The compiled host targets .NET Framework, so it must reference the
            Windows PowerShell assembly from the global assembly cache even when
            the build itself runs under PowerShell 7.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $cachePath = Join-Path -Path $env:WINDIR `
        -ChildPath 'Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation'

    if (Test-Path -LiteralPath $cachePath -PathType Container) {
        $assembly = Get-ChildItem -LiteralPath $cachePath -Directory |
            Where-Object { $_.Name -like 'v4.0_*' } |
            Sort-Object -Property Name -Descending |
            ForEach-Object {
                Join-Path -Path $_.FullName -ChildPath 'System.Management.Automation.dll'
            } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            Select-Object -First 1

        if ($assembly) {
            return $assembly
        }
    }

    throw [System.IO.FileNotFoundException]::new(
        'The Windows PowerShell reference assembly was not found; the executable cannot be built.',
        $cachePath
    )
}

function ConvertTo-LaunchTreeAssemblyVersion {
    <#
        .SYNOPSIS
            Reduces a semantic version to the four-part assembly version.

        .PARAMETER Version
            Specifies the version to convert.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Version
    )

    $numericPart = ($Version -split '[-+]')[0]
    $segments = @(
        @($numericPart -split '\.' | Where-Object { $_ -match '^\d+$' } | Select-Object -First 3)
    )
    while ($segments.Count -lt 3) {
        $segments += '0'
    }

    '{0}.{1}.{2}.0' -f $segments[0], $segments[1], $segments[2]
}

$resolvedScriptPath = (Resolve-Path -LiteralPath $ScriptPath).Path
$resolvedHostSourcePath = (Resolve-Path -LiteralPath $HostSourcePath).Path
$resolvedBootstrapPath = (Resolve-Path -LiteralPath $BootstrapPath).Path
$resolvedIconPath = (Resolve-Path -LiteralPath $IconPath).Path

if (-not $OutputPath) {
    $OutputPath = [IO.Path]::ChangeExtension($resolvedScriptPath, '.exe')
}

$compilerPath = Get-LaunchTreeCompilerPath
$automationReferencePath = Get-LaunchTreeAutomationReferencePath
$assemblyVersion = ConvertTo-LaunchTreeAssemblyVersion -Version $Version

$isMinimal = $Variant -eq 'Minimal'
$target = if ($isMinimal) { 'winexe' } else { 'exe' }
$title = if ($isMinimal) { 'LaunchTree Launcher' } else { 'LaunchTree' }
$description = if ($isMinimal) {
    'Opens an Entry Root in the LaunchTree Launcher.'
} else {
    'Self-contained LaunchTree delivery that needs no installed module.'
}

$hostSource = (Get-Content -LiteralPath $resolvedHostSourcePath -Raw).
    Replace('__TITLE__', $title).
    Replace('__PRODUCT__', 'LaunchTree').
    Replace('__DESCRIPTION__', $description).
    Replace('__COMPANY__', 'LaunchTree').
    Replace('__COPYRIGHT__', 'Licensed under the MIT License.').
    Replace('__ASSEMBLY_VERSION__', $assemblyVersion).
    Replace('__INFORMATIONAL_VERSION__', $Version).
    Replace('__SCRIPT_RESOURCE_NAME__', $script:ScriptResourceName).
    Replace('__BOOTSTRAP_RESOURCE_NAME__', $script:BootstrapResourceName).
    Replace('__HIDE_OWN_CONSOLE__', $(if ($isMinimal) { 'false' } else { 'true' }))

if ($hostSource -match '__[A-Z_]+__') {
    throw [System.InvalidOperationException]::new(
        "The compiled host source still contains the placeholder '$($Matches[0])'."
    )
}

if (-not $PSCmdlet.ShouldProcess($OutputPath, 'Compile LaunchTree executable')) {
    return
}

$outputDirectory = Split-Path -Path $OutputPath -Parent
$null = New-Item -Path $outputDirectory -ItemType Directory -Force

$workingDirectory = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath (
    'launchtree-exe-{0}' -f [guid]::NewGuid().ToString('N')
)
$null = New-Item -Path $workingDirectory -ItemType Directory -Force

try {
    $sourceFile = Join-Path -Path $workingDirectory -ChildPath 'LaunchTreeStandaloneHost.cs'
    [IO.File]::WriteAllText($sourceFile, $hostSource, [Text.UTF8Encoding]::new($true))

    # The host reads the resource with encoding detection, so keep the byte order mark.
    $resourceFile = Join-Path -Path $workingDirectory -ChildPath $script:ScriptResourceName
    $scriptContent = [IO.File]::ReadAllText($resolvedScriptPath)
    [IO.File]::WriteAllText($resourceFile, $scriptContent, [Text.UTF8Encoding]::new($true))

    $bootstrapFile = Join-Path -Path $workingDirectory -ChildPath $script:BootstrapResourceName
    $bootstrapContent = [IO.File]::ReadAllText($resolvedBootstrapPath)
    [IO.File]::WriteAllText($bootstrapFile, $bootstrapContent, [Text.UTF8Encoding]::new($true))

    $compilerArguments = @(
        '/nologo'
        '/nowarn:162'
        '/optimize+'
        '/platform:anycpu'
        "/target:$target"
        "/out:$OutputPath"
        "/win32icon:$resolvedIconPath"
        "/reference:$automationReferencePath"
        '/reference:System.dll'
        "/resource:$resourceFile,$($script:ScriptResourceName)"
        "/resource:$bootstrapFile,$($script:BootstrapResourceName)"
        $sourceFile
    )

    $compilerOutput = & $compilerPath @compilerArguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw [System.InvalidOperationException]::new(
            "The C# compiler failed with exit code $LASTEXITCODE`n" +
            (($compilerOutput | Out-String).Trim())
        )
    }

    if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new(
            'The C# compiler reported success but wrote no executable.',
            $OutputPath
        )
    }

    # Running without a command loads and parses the whole embedded script and returns,
    # so a broken embedding or a broken host fails the build instead of the first user.
    $smokeProcess = Start-Process -FilePath $OutputPath -PassThru -WindowStyle Hidden
    if (-not $smokeProcess.WaitForExit(120000)) {
        $smokeProcess.Kill()
        throw [System.TimeoutException]::new(
            "The generated executable '$OutputPath' did not exit within 120 seconds."
        )
    }

    if ($smokeProcess.ExitCode -ne 0) {
        throw [System.InvalidOperationException]::new(
            "The generated executable '$OutputPath' exited with code $($smokeProcess.ExitCode)."
        )
    }

    $versionInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo($OutputPath)
    if ($versionInfo.ProductName -ne 'LaunchTree') {
        throw [System.InvalidOperationException]::new(
            "The generated executable reports product '$($versionInfo.ProductName)'."
        )
    }

    [PSCustomObject] @{
        Path            = $OutputPath
        Variant         = $Variant
        Version         = $Version
        AssemblyVersion = $assemblyVersion
        Subsystem       = $target
        ScriptPath      = $resolvedScriptPath
        Bytes           = (Get-Item -LiteralPath $OutputPath).Length
    }
} finally {
    Remove-Item -LiteralPath $workingDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
