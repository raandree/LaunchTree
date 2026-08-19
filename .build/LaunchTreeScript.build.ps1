function Test-LaunchTreeWindowsBuildHost {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows
}

task Build_Single_File_Script {
    . Set-SamplerTaskVariable -AsNewBuild

    $generatorPath = Join-Path -Path $BuildRoot -ChildPath 'tools\Build-LaunchTreeScript.ps1'
    $scriptOutputPath = Join-Path -Path $OutputDirectory -ChildPath "$ProjectName.ps1"

    $result = & $generatorPath -SourcePath $SourcePath -OutputPath $scriptOutputPath `
        -Version $ModuleVersion

    Write-Build DarkGray "`tGenerated single-file script '$($result.Path)'."
    Write-Build DarkGray (
        "`tEmbedded $($result.FunctionCount) functions, " +
        "$($result.LineCount) lines, $($result.Bytes) bytes."
    )
}

task Build_Minimal_Single_File_Script {
    . Set-SamplerTaskVariable -AsNewBuild

    $generatorPath = Join-Path -Path $BuildRoot -ChildPath 'tools\Build-LaunchTreeScript.ps1'
    $scriptOutputPath = Join-Path -Path $OutputDirectory -ChildPath "$ProjectName.Minimal.ps1"

    $result = & $generatorPath -SourcePath $SourcePath -OutputPath $scriptOutputPath `
        -Version $ModuleVersion -Variant Minimal

    Write-Build DarkGray "`tGenerated minimal single-file script '$($result.Path)'."
    Write-Build DarkGray (
        "`tEmbedded $($result.FunctionCount) functions, " +
        "$($result.LineCount) lines, $($result.Bytes) bytes."
    )
}

task Build_Single_File_Executable {
    . Set-SamplerTaskVariable -AsNewBuild

    if (-not (Test-LaunchTreeWindowsBuildHost)) {
        Write-Build Yellow "`tSkipped: a Windows executable can only be compiled on Windows."
        return
    }

    $generatorPath = Join-Path -Path $BuildRoot -ChildPath 'tools\Build-LaunchTreeExecutable.ps1'
    $scriptPath = Join-Path -Path $OutputDirectory -ChildPath "$ProjectName.ps1"
    $executablePath = Join-Path -Path $OutputDirectory -ChildPath "$ProjectName.exe"

    $result = & $generatorPath -ScriptPath $scriptPath -OutputPath $executablePath `
        -Version $ModuleVersion

    Write-Build DarkGray "`tCompiled executable '$($result.Path)'."
    Write-Build DarkGray (
        "`tSubsystem $($result.Subsystem), version $($result.AssemblyVersion), " +
        "$($result.Bytes) bytes."
    )
}

task Build_Minimal_Single_File_Executable {
    . Set-SamplerTaskVariable -AsNewBuild

    if (-not (Test-LaunchTreeWindowsBuildHost)) {
        Write-Build Yellow "`tSkipped: a Windows executable can only be compiled on Windows."
        return
    }

    $generatorPath = Join-Path -Path $BuildRoot -ChildPath 'tools\Build-LaunchTreeExecutable.ps1'
    $scriptPath = Join-Path -Path $OutputDirectory -ChildPath "$ProjectName.Minimal.ps1"
    $executablePath = Join-Path -Path $OutputDirectory -ChildPath "$ProjectName.Minimal.exe"

    $result = & $generatorPath -ScriptPath $scriptPath -OutputPath $executablePath `
        -Version $ModuleVersion -Variant Minimal

    Write-Build DarkGray "`tCompiled minimal executable '$($result.Path)'."
    Write-Build DarkGray (
        "`tSubsystem $($result.Subsystem), version $($result.AssemblyVersion), " +
        "$($result.Bytes) bytes."
    )
}
