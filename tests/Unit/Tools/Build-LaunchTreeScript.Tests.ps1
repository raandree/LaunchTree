BeforeAll {
    $script:repositoryRoot = "$PSScriptRoot\..\..\.." | Convert-Path
    $script:generatorPath = Join-Path -Path $script:repositoryRoot `
        -ChildPath 'tools\Build-LaunchTreeScript.ps1'
    $script:sourcePath = Join-Path -Path $script:repositoryRoot -ChildPath 'source'
}

Describe 'Build-LaunchTreeScript' -Tag 'Unit' {
    BeforeAll {
        $script:outputPath = Join-Path -Path $TestDrive -ChildPath 'LaunchTree.ps1'
        $script:result = & $script:generatorPath -SourcePath $script:sourcePath `
            -OutputPath $script:outputPath -Version '9.9.9'
        $script:content = Get-Content -LiteralPath $script:outputPath -Raw
    }

    It 'Should generate a parsable single-file script' {
        $script:outputPath | Should -Exist

        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:outputPath, [ref] $null, [ref] $parseErrors
        )

        $parseErrors | Should -BeNullOrEmpty
    }

    It 'Should embed every private and public module function' {
        $expected = @(
            Get-ChildItem -Path (Join-Path $script:sourcePath 'Private') -Filter '*.ps1' -File
            Get-ChildItem -Path (Join-Path $script:sourcePath 'Public') -Filter '*.ps1' -File
        )

        $script:result.FunctionCount | Should -Be $expected.Count
        foreach ($file in $expected) {
            $script:content | Should -Match "function $($file.BaseName)\b"
        }
    }

    It 'Should record the requested version for standalone runtime context' {
        $script:result.Version | Should -Be '9.9.9'
        $script:content | Should -Match "LaunchTreeStandaloneVersion = '9\.9\.9'"
        $script:content | Should -Match 'LaunchTreeStandalonePath'
    }

    It 'Should expose every exported command through the dispatch map' {
        $manifestPath = Join-Path -Path $script:sourcePath -ChildPath 'LaunchTree.psd1'
        $exported = (Import-PowerShellDataFile -LiteralPath $manifestPath).FunctionsToExport

        foreach ($commandName in $exported) {
            $script:content | Should -Match ([regex]::Escape("'$commandName'"))
        }
    }

    It 'Should resolve a standalone runtime context without an imported module' {
        $probe = {
            param($ScriptPath)
            . $ScriptPath
            $context = Get-LaunchTreeRuntimeContext
            [PSCustomObject] @{
                HostKind        = $context.HostKind
                Version         = $context.Version
                LauncherPath    = $context.LauncherPath
                LauncherCommand = $context.LauncherCommand
                ProbeCommand    = $context.ProbeCommand
            }
        }

        $context = & $probe $script:outputPath

        $context.HostKind | Should -Be 'Script'
        $context.Version | Should -Be '9.9.9'
        $context.LauncherPath | Should -Be $script:outputPath
        $context.LauncherCommand | Should -Be 'Show'
        $context.ProbeCommand | Should -Be 'EventLogProbe'
    }
}
