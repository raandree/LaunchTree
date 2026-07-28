BeforeAll {
    $script:moduleName = 'StartMenuFolders'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-StartMenuFolderDiagnostic' -Tag 'Unit' {
    It 'Should return structured events with URL query strings redacted' {
        Mock -ModuleName $moduleName -CommandName Get-WinEvent -MockWith {
            [PSCustomObject] @{
                Id          = 1201
                Level       = 2
                LevelDisplayName = 'Error'
                TimeCreated = [DateTime]::UtcNow
                Message     = 'Failed https://example.test/path?token=secret&user=one'
                ProviderName = 'StartMenuFolders'
                LogName     = 'StartMenuFolders'
            }
        }

        $result = Get-StartMenuFolderDiagnostic -LogName 'StartMenuFolders'

        $result | Should -HaveCount 1
        $result[0].PSObject.TypeNames | Should -Contain 'StartMenuFolders.DiagnosticEvent'
        $result[0].EventId | Should -Be 1201
        $result[0].Message | Should -Not -Match 'token=secret'
        $result[0].Message | Should -Match '\?\[redacted\]'
    }
}