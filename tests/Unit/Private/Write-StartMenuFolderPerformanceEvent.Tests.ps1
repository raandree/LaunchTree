BeforeAll {
    $script:moduleName = 'StartMenuFolders'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Write-StartMenuFolderPerformanceEvent' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName $moduleName -CommandName Write-StartMenuFolderEvent -MockWith {
            $true
        }
        $script:configuration = [PSCustomObject] @{
            Diagnostics = [PSCustomObject] @{ SourceName = 'StartMenuFolders' }
        }
    }

    It 'Should emit startup event 1501 only above 500 milliseconds' {
        $results = InModuleScope -ModuleName $moduleName -Parameters @{
            TestConfiguration = $script:configuration
        } {
            $startupParameters = @{
                Configuration = $TestConfiguration
                Metric        = 'Startup'
            }
            @(
                Write-StartMenuFolderPerformanceEvent @startupParameters -Value 499
                Write-StartMenuFolderPerformanceEvent @startupParameters -Value 501
            )
        }

        $results | Should -Be @($false, $true)
        $assertion = @{
            ModuleName      = $moduleName
            CommandName     = 'Write-StartMenuFolderEvent'
            Times           = 1
            Exactly         = $true
            ParameterFilter = { $EventId -eq 1501 }
        }
        Should -Invoke @assertion
    }

    It 'Should map interaction and working-set breaches to 1502 and 1503' {
        InModuleScope -ModuleName $moduleName -Parameters @{
            TestConfiguration = $script:configuration
        } {
            $interactionParameters = @{
                Configuration = $TestConfiguration
                Metric        = 'Interaction'
                Value         = 101
            }
            Write-StartMenuFolderPerformanceEvent @interactionParameters
            $workingSetParameters = @{
                Configuration = $TestConfiguration
                Metric        = 'WorkingSetMB'
                Value         = 201
            }
            Write-StartMenuFolderPerformanceEvent @workingSetParameters
        }

        $interactionAssertion = @{
            ModuleName      = $moduleName
            CommandName     = 'Write-StartMenuFolderEvent'
            Times           = 1
            Exactly         = $true
            ParameterFilter = { $EventId -eq 1502 }
        }
        Should -Invoke @interactionAssertion
        $workingSetAssertion = @{
            ModuleName      = $moduleName
            CommandName     = 'Write-StartMenuFolderEvent'
            Times           = 1
            Exactly         = $true
            ParameterFilter = { $EventId -eq 1503 }
        }
        Should -Invoke @workingSetAssertion
    }
}