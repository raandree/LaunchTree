BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-LaunchTreeTabbedListContent' -Tag 'Unit' {
    BeforeAll {
        $script:snapshot = [PSCustomObject] @{
            EntryRoots = @(
                [PSCustomObject] @{
                    Name        = 'Entry A'
                    Description = 'Entry A description'
                }
                [PSCustomObject] @{
                    Name        = 'Entry B'
                    Description = 'Entry B description'
                }
            )
            Objects   = @(
                [PSCustomObject] @{
                    Kind               = 'MenuFolder'
                    Name               = 'Tools'
                    Description        = 'Tools description'
                    RelativePath       = 'Tools'
                    ParentRelativePath = ''
                    EntryName          = 'Entry A'
                    ContentSource      = 'Managed'
                }
                [PSCustomObject] @{
                    Kind               = 'MenuFolder'
                    Name               = 'Operations'
                    Description        = 'Operations description'
                    RelativePath       = 'Operations'
                    ParentRelativePath = ''
                    EntryName          = 'Entry A'
                    ContentSource      = 'Managed'
                }
                [PSCustomObject] @{
                    Kind               = 'MenuFolder'
                    Name               = 'Admin'
                    Description        = 'Admin description'
                    RelativePath       = 'Operations\Admin'
                    ParentRelativePath = 'Operations'
                    EntryName          = 'Entry A'
                    ContentSource      = 'Managed'
                }
                [PSCustomObject] @{
                    Kind               = 'LaunchItem'
                    Name               = 'Portal'
                    Description        = 'Entry portal'
                    RelativePath       = 'Portal.url'
                    ParentRelativePath = ''
                    EntryName          = 'Entry A'
                }
                [PSCustomObject] @{
                    Kind               = 'LaunchItem'
                    Name               = 'Dashboard'
                    Description        = 'Operations dashboard'
                    RelativePath       = 'Operations\Dashboard.url'
                    ParentRelativePath = 'Operations'
                    EntryName          = 'Entry A'
                }
                [PSCustomObject] @{
                    Kind               = 'LaunchItem'
                    Name               = 'Portal B'
                    Description        = 'Other portal'
                    RelativePath       = 'Portal B.url'
                    ParentRelativePath = ''
                    EntryName          = 'Entry B'
                }
            )
        }
    }

    It 'Should separate FR-011 root tabs and Launch Item rows with the Entry Root description' {
        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            TestSnapshot = $script:snapshot
        } {
            Get-LaunchTreeTabbedListContent -Snapshot $TestSnapshot -EntryName 'Entry A'
        }

        $result.CurrentName | Should -Be 'Entry A'
        $result.Description | Should -Be 'Entry A description'
        $result.MenuFolders.Name | Should -Be @('Operations', 'Tools')
        $result.LaunchItems.Name | Should -Be @('Portal')
        $result.VisibleCount | Should -Be 3
    }

    It 'Should expose nested Menu Folders as tabs and the active Menu Folder description' {
        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            TestSnapshot = $script:snapshot
        } {
            $parameters = @{
                Snapshot            = $TestSnapshot
                EntryName           = 'Entry A'
                CurrentRelativePath = 'Operations'
            }
            Get-LaunchTreeTabbedListContent @parameters
        }

        $result.CurrentName | Should -Be 'Operations'
        $result.Description | Should -Be 'Operations description'
        $result.MenuFolders.Name | Should -Be @('Admin')
        $result.LaunchItems.Name | Should -Be @('Dashboard')
    }

    It 'Should independently sort FR-013 tabs and rows in descending name order' {
        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            TestSnapshot = $script:snapshot
        } {
            $parameters = @{
                Snapshot   = $TestSnapshot
                EntryName  = 'Entry A'
                Descending = $true
            }
            Get-LaunchTreeTabbedListContent @parameters
        }

        $result.MenuFolders.Name | Should -Be @('Tools', 'Operations')
        $result.LaunchItems.Name | Should -Be @('Portal')
        $result.VisibleCount | Should -Be 3
    }
}