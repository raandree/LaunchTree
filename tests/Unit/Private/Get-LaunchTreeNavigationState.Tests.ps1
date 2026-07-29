BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-LaunchTreeNavigationState' -Tag 'Unit' {
    It 'Should select a Menu Folder from another Entry Root and clear search' {
        $folder = [PSCustomObject] @{
            EntryName    = 'Entry B'
            RelativePath = 'Catalog\Tools'
        }

        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            TestFolder = $folder
        } {
            $parameters = @{
                Action              = 'SelectFolder'
                EntryName           = 'Entry A'
                CurrentRelativePath = 'Operations'
                Folder              = $TestFolder
            }
            Get-LaunchTreeNavigationState @parameters
        }

        $result.EntryName | Should -Be 'Entry B'
        $result.RelativePath | Should -Be 'Catalog\Tools'
        $result.ClearSearch | Should -BeTrue
        $result.BackEnabled | Should -BeTrue
    }

    It 'Should navigate Back to <ExpectedPath>' -TestCases @(
        @{ CurrentPath = 'Operations\Admin'; ExpectedPath = 'Operations'; BackEnabled = $true }
        @{ CurrentPath = 'Operations'; ExpectedPath = ''; BackEnabled = $false }
    ) {
        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            TestCurrentPath = $CurrentPath
        } {
            $parameters = @{
                Action              = 'Back'
                EntryName           = 'Entry A'
                CurrentRelativePath = $TestCurrentPath
            }
            Get-LaunchTreeNavigationState @parameters
        }

        $result.EntryName | Should -Be 'Entry A'
        $result.RelativePath | Should -Be $ExpectedPath
        $result.ClearSearch | Should -BeTrue
        $result.BackEnabled | Should -Be $BackEnabled
    }

    It 'Should reset navigation when another Entry Root activates' {
        $result = InModuleScope -ModuleName $moduleName {
            $parameters = @{
                Action              = 'ActivateEntry'
                EntryName           = 'Entry A'
                CurrentRelativePath = 'Operations\Admin'
                ActivatedEntryName  = 'Entry B'
            }
            Get-LaunchTreeNavigationState @parameters
        }

        $result.EntryName | Should -Be 'Entry B'
        $result.RelativePath | Should -BeNullOrEmpty
        $result.ClearSearch | Should -BeTrue
        $result.BackEnabled | Should -BeFalse
    }
}