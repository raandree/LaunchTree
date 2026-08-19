Describe 'Show-LaunchTreeWindow' -Tag 'Unit' {
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
}