BeforeAll {
    $script:moduleName = 'StartMenuFolders'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Write-StartMenuFolderEvent' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName $moduleName -CommandName Invoke-StartMenuFolderEventLogWrite
        $script:configuration = [PSCustomObject] @{
            Diagnostics = [PSCustomObject] @{
                LogName    = 'StartMenuFolders'
                SourceName = 'StartMenuFolders'
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
            Write-StartMenuFolderEvent @parameters
        }

        $result | Should -BeTrue
        $assertion = @{
            ModuleName      = $moduleName
            CommandName     = 'Invoke-StartMenuFolderEventLogWrite'
            Times           = 1
            Exactly         = $true
            ParameterFilter = {
                $SourceName -eq 'StartMenuFolders' -and
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