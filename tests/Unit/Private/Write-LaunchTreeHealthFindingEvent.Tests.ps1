BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Write-LaunchTreeHealthFindingEvent' -Tag 'Unit' {
    It 'Should map supported content findings to their stable event IDs' {
        Mock -ModuleName $moduleName -CommandName Write-LaunchTreeEvent -MockWith {
            $true
        }
        $configuration = [PSCustomObject] @{
            Diagnostics = [PSCustomObject] @{ SourceName = 'LaunchTree' }
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
            Write-LaunchTreeHealthFindingEvent @parameters
        }

        $result | Should -BeTrue
        $assertion = @{
            ModuleName      = $moduleName
            CommandName     = 'Write-LaunchTreeEvent'
            Times           = 1
            Exactly         = $true
            ParameterFilter = { $EventId -eq 1104 }
        }
        Should -Invoke @assertion
    }
}