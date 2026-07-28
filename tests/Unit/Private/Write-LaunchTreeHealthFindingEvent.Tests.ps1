BeforeAll {
    $script:moduleName = 'StartMenuFolders'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Write-StartMenuFolderHealthFindingEvent' -Tag 'Unit' {
    It 'Should map supported content findings to their stable event IDs' {
        Mock -ModuleName $moduleName -CommandName Write-StartMenuFolderEvent -MockWith {
            $true
        }
        $configuration = [PSCustomObject] @{
            Diagnostics = [PSCustomObject] @{ SourceName = 'StartMenuFolders' }
        }
        $finding = [PSCustomObject] @{
            Code     = 'UrlSchemeRejected'
            Severity = 'Warning'
            Message  = 'Rejected.'
            Path     = 'C:\Managed\Blocked.url'
        }

        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            TestConfiguration = $configuration
            TestFinding       = $finding
        } {
            $parameters = @{
                Configuration = $TestConfiguration
                HealthFinding = $TestFinding
            }
            Write-StartMenuFolderHealthFindingEvent @parameters
        }

        $result | Should -BeTrue
        $assertion = @{
            ModuleName      = $moduleName
            CommandName     = 'Write-StartMenuFolderEvent'
            Times           = 1
            Exactly         = $true
            ParameterFilter = { $EventId -eq 1104 }
        }
        Should -Invoke @assertion
    }
}