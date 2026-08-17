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

    It 'Should expose the CR-013 root overrides on the standalone parameter surface' {
        $script:content | Should -Match '\[string\] \$ManagedRoot'
        $script:content | Should -Match '\[string\] \$PersonalRoot'
    }

    It 'Should keep the comment-based help of every embedded function' {
        $tokens = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:outputPath, [ref] $tokens, [ref] $null
        )

        @($tokens | Where-Object { $_.Kind -eq 'Comment' }).Count |
            Should -BeGreaterThan 1
    }

    It 'Should reject a parameter the selected command does not support' {
        $unsupported = @{
            Command = 'GetConfiguration'
            Path    = Join-Path $TestDrive 'bundle.zip'
        }

        { & $script:outputPath @unsupported } |
            Should -Throw -ExpectedMessage '*does not support*Path*'
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

Describe 'Build-LaunchTreeScript minimal variant' -Tag 'Unit' {
    BeforeAll {
        $script:minimalPath = Join-Path -Path $TestDrive -ChildPath 'LaunchTree.Minimal.ps1'
        $script:minimalResult = & $script:generatorPath -SourcePath $script:sourcePath `
            -OutputPath $script:minimalPath -Version '9.9.9' -Variant Minimal
        $script:minimalContent = Get-Content -LiteralPath $script:minimalPath -Raw
        $script:minimalAst = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:minimalPath, [ref] $null, [ref] $null
        )
    }

    It 'Should generate a parsable minimal script' {
        $script:minimalPath | Should -Exist
        $script:minimalResult.Variant | Should -Be 'Minimal'

        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:minimalPath, [ref] $null, [ref] $parseErrors
        )

        $parseErrors | Should -BeNullOrEmpty
    }

    It 'Should embed the functions the Launcher call needs' {
        $expected = @(
            'Show-LaunchTree'
            'Show-LaunchTreeWindow'
            'Get-LaunchTreeConfiguration'
            'Get-LaunchTreeContentSnapshot'
            'Get-LaunchTreeRuntimeContext'
            'Invoke-LaunchTreeLaunchItem'
        )

        foreach ($commandName in $expected) {
            $script:minimalContent | Should -Match "function $commandName\b"
        }
    }

    It 'Should omit every function the Launcher call does not need' {
        $unexpected = @(
            'Update-LaunchTree'
            'Test-LaunchTree'
            'Remove-LaunchTree'
            'Get-LaunchTreeDiagnostic'
            'Export-LaunchTreeSupportBundle'
            'New-LaunchTreeStartEntry'
            'Register-LaunchTreeEventLog'
            'Invoke-LaunchTreeEventLogAccessProbe'
        )

        foreach ($commandName in $unexpected) {
            $script:minimalContent | Should -Not -Match "function $commandName\b"
        }

        $allFunctions = @(
            Get-ChildItem -Path (Join-Path $script:sourcePath 'Private') -Filter '*.ps1' -File
            Get-ChildItem -Path (Join-Path $script:sourcePath 'Public') -Filter '*.ps1' -File
        )
        $script:minimalResult.FunctionCount | Should -BeLessThan $allFunctions.Count
    }

    It 'Should invoke no LaunchTree command it does not embed' {
        $defined = @(
            $script:minimalAst.FindAll(
                {
                    param($node)
                    $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
                },
                $true
            ).Name
        )
        $invoked = @(
            $script:minimalAst.FindAll(
                {
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst]
                },
                $true
            ) |
                ForEach-Object { $_.GetCommandName() } |
                Where-Object { $_ -like '*-LaunchTree*' } |
                Sort-Object -Unique
        )

        $invoked | Should -Not -BeNullOrEmpty
        @($invoked | Where-Object { $_ -notin $defined }) | Should -BeNullOrEmpty
    }

    It 'Should expose only the parameters the supported call needs' {
        $parameterNames = @(
            $script:minimalAst.ParamBlock.Parameters.Name.VariablePath.UserPath | Sort-Object
        )

        $parameterNames | Should -Be @('Command', 'EntryName', 'ManagedRoot')
    }

    It 'Should accept only the Show command' {
        $commandParameter = $script:minimalAst.ParamBlock.Parameters |
            Where-Object { $_.Name.VariablePath.UserPath -eq 'Command' }
        $validateSet = $commandParameter.Attributes |
            Where-Object { $_.TypeName.FullName -eq 'ValidateSet' }

        @($validateSet.PositionalArguments.Value) | Should -Be @('Show')
    }

    It 'Should resolve a standalone runtime context without an imported module' {
        $probe = {
            param($ScriptPath)
            . $ScriptPath
            Get-LaunchTreeRuntimeContext
        }

        $context = & $probe $script:minimalPath

        $context.HostKind | Should -Be 'Script'
        $context.Version | Should -Be '9.9.9'
        $context.LauncherPath | Should -Be $script:minimalPath
    }

    It 'Should strip every comment except the requires statement' {
        $tokens = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:minimalPath, [ref] $tokens, [ref] $null
        )
        $comments = @(
            $tokens |
                Where-Object { $_.Kind -eq 'Comment' -and $_.Text -notmatch '^\s*#requires' }
        )

        $comments | Should -BeNullOrEmpty
        $script:minimalContent | Should -Match '#Requires -Version 5\.1'
    }

    It 'Should keep every blank line that belongs to a multi-line string' {
        $tokens = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:minimalPath, [ref] $tokens, [ref] $null
        )
        $protectedLine = [System.Collections.Generic.HashSet[int]]::new()
        foreach ($token in $tokens) {
            if ($token.Kind -notin @('NewLine', 'LineContinuation', 'Comment') -and
                $token.Extent.EndLineNumber -gt $token.Extent.StartLineNumber) {
                $token.Extent.StartLineNumber..$token.Extent.EndLineNumber |
                    ForEach-Object { $null = $protectedLine.Add($_) }
            }
        }

        $lines = $script:minimalContent -split "\r?\n"
        $strayBlank = @(
            1..$lines.Count |
                Where-Object { $lines[$_ - 1].Trim() -eq '' } |
                Where-Object { -not $protectedLine.Contains($_) }
        )

        # The trailing newline leaves one empty final line.
        $strayBlank.Count | Should -BeLessOrEqual 1
        $script:minimalResult.LineCount | Should -BeLessThan 3600
    }
}
