Describe 'Show-LaunchTreeWindow' -Tag 'Unit' {
    It 'Should assign the Launcher taskbar identity when the native window is created' {
        $projectPath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..'
        $windowSourcePath = Join-Path -Path $projectPath -ChildPath (
            'source\Private\Show-LaunchTreeWindow.ps1'
        )
        $windowSource = Get-Content -LiteralPath $windowSourcePath -Raw

        $windowSource | Should -Match '\$window\.Add_SourceInitialized\('
        $windowSource | Should -Match '\[LaunchTree\.NativeWindow\]::SetAppUserModelId\('
        $windowSource | Should -Match "'LaunchTree\.Launcher'"
    }

    It 'Should not show Content Source metadata below compact row labels' {
        $projectPath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..'
        $windowSourcePath = Join-Path -Path $projectPath -ChildPath (
            'source\Private\Show-LaunchTreeWindow.ps1'
        )
        $parseErrors = $null
        $tokens = $null
        $windowAst = [Management.Automation.Language.Parser]::ParseFile(
            $windowSourcePath,
            [ref] $tokens,
            [ref] $parseErrors
        )
        $detailAssignment = $windowAst.Find({
            param($ast)

            $ast -is [Management.Automation.Language.AssignmentStatementAst] -and
            $ast.Left.Extent.Text -eq '$detail.Text'
        }, $true)

        $parseErrors | Should -BeNullOrEmpty
        $detailAssignment | Should -Not -BeNullOrEmpty
        $detailAssignment.Right.Extent.Text | Should -Not -Match '\$item\.ContentSource'
    }

    It 'Should offer the shortcut wizard from the title bar' {
        $projectPath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..'
        $windowSourcePath = Join-Path -Path $projectPath -ChildPath (
            'source\Private\Show-LaunchTreeWindow.ps1'
        )
        $windowSource = Get-Content -LiteralPath $windowSourcePath -Raw

        $windowSource | Should -Match (
            '\$wizardButton = \[System\.Windows\.Controls\.Button\]::new\(\)'
        )
        $windowSource | Should -Match '\$wizardButton\.Content = \[char\] 0xE713'
        $windowSource | Should -Match 'Show-LaunchTreeShortcutWizard @wizardParameters'
    }
}