BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Write-LaunchTreeEvent' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName $moduleName -CommandName Invoke-LaunchTreeEventLogWrite
        $script:configuration = [PSCustomObject] @{
            Diagnostics = [PSCustomObject] @{
                LogName    = 'LaunchTree'
                SourceName = 'LaunchTree'
            }
        }
    }

    It 'Should write a structured redacted event through the cross-edition core' {
        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            TestConfiguration = $script:configuration
        } {
            $parameters = @{
                Configuration = $TestConfiguration
                EventId       = 1201
                Level         = 'Error'
                Operation     = 'LaunchItem'
                Message       = 'Failed https://example.test/path?token=secret'
                Path          = 'https://example.test/source?pathSecret=hidden'
            }
            Write-LaunchTreeEvent @parameters
        }

        $result | Should -BeTrue
        $assertion = @{
            ModuleName      = $moduleName
            CommandName     = 'Invoke-LaunchTreeEventLogWrite'
            Times           = 1
            Exactly         = $true
            ParameterFilter = {
                $LogName -eq 'LaunchTree' -and
                $SourceName -eq 'LaunchTree' -and
                $EventId -eq 1201 -and
                $EntryType -eq [Diagnostics.EventLogEntryType]::Error -and
                $Message -match '"EventSchemaVersion":1' -and
                $Message -notmatch 'token=secret' -and
                $Message -notmatch 'pathSecret=hidden' -and
                $Message -match '\?\[redacted\]'
            }
        }
        Should -Invoke @assertion
    }
}