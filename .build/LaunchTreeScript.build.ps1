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
