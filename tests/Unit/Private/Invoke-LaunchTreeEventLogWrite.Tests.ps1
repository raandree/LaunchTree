BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-LaunchTreeEventLogWrite' -Tag 'Unit' {
    BeforeAll {
        $script:unregisteredSource = 'LaunchTreeTest{0}' -f (
            [guid]::NewGuid().ToString('N').Substring(0, 12)
        )
        $script:isElevated = [Security.Principal.WindowsPrincipal]::new(
            [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    AfterAll {
        # Removes the source again if a regression let the write register it.
        if ($script:isElevated -and
            [Diagnostics.EventLog]::SourceExists($script:unregisteredSource)) {
            [Diagnostics.EventLog]::DeleteEventSource($script:unregisteredSource)
        }
    }

    It 'Should refuse to write through a source that the log does not own' {
        $write = {
            InModuleScope -ModuleName $moduleName -Parameters @{
                TestSourceName = $script:unregisteredSource
            } {
                $parameters = @{
                    LogName    = 'LaunchTree'
                    SourceName = $TestSourceName
                    Message    = 'Registration guard test.'
                    EntryType  = [Diagnostics.EventLogEntryType]::Information
                    EventId    = 1001
                }
                Invoke-LaunchTreeEventLogWrite @parameters
            }
        }

        $write | Should -Throw -ExpectedMessage (
            "*is not registered for log 'LaunchTree'*"
        )

        if ($script:isElevated) {
            [Diagnostics.EventLog]::SourceExists($script:unregisteredSource) |
                Should -BeFalse -Because 'a write must never register a source'
        }
    }

    It 'Should report the failed write as a non-terminating diagnostic loss' {
        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            TestSourceName = $script:unregisteredSource
        } {
            $parameters = @{
                Configuration = [PSCustomObject] @{
                    Diagnostics = [PSCustomObject] @{
                        LogName    = 'LaunchTree'
                        SourceName = $TestSourceName
                    }
                }
                EventId       = 1001
                Level         = 'Warning'
                Operation     = 'Configuration'
                Message       = 'Registration guard test.'
            }
            Write-LaunchTreeEvent @parameters
        }

        $result | Should -BeFalse
    }
}
