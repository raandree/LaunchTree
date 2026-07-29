BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-LaunchTreeStandardUserEventProbe' -Tag 'Unit' {
    BeforeAll {
        $script:configuration = [PSCustomObject] @{
            Diagnostics = [PSCustomObject] @{
                LogName    = 'LaunchTree'
                SourceName = 'LaunchTree'
            }
        }
    }

    It 'Should return an unverified result instead of throwing when the process cannot start' {
        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            Configuration = $script:configuration
        } {
            param($Configuration)
            Mock Invoke-LaunchTreeUnelevatedProcess {
                throw [InvalidOperationException]::new(
                    'Could not start the standard-user probe process.'
                )
            }
            Invoke-LaunchTreeStandardUserEventProbe -Configuration $Configuration `
                -LauncherHostPath 'C:\host.exe'
        }

        $result.PSObject.TypeNames | Should -Contain 'LaunchTree.EventProbeResult'
        $result.Verified | Should -BeFalse
        $result.Reason | Should -Match 'could not be started'
    }

    It 'Should report verified when the probe exits with zero' {
        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            Configuration = $script:configuration
        } {
            param($Configuration)
            Mock Invoke-LaunchTreeUnelevatedProcess { 0 }
            Invoke-LaunchTreeStandardUserEventProbe -Configuration $Configuration `
                -LauncherHostPath 'C:\host.exe'
        }

        $result.Verified | Should -BeTrue
    }

    It 'Should report unverified when the probe exits non-zero' {
        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            Configuration = $script:configuration
        } {
            param($Configuration)
            Mock Invoke-LaunchTreeUnelevatedProcess { 11 }
            Invoke-LaunchTreeStandardUserEventProbe -Configuration $Configuration `
                -LauncherHostPath 'C:\host.exe'
        }

        $result.Verified | Should -BeFalse
        $result.Reason | Should -Match 'exit code 11'
    }

    It 'Should report unverified when the probe runs elevated' {
        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            Configuration = $script:configuration
        } {
            param($Configuration)
            Mock Invoke-LaunchTreeUnelevatedProcess { 10 }
            Invoke-LaunchTreeStandardUserEventProbe -Configuration $Configuration `
                -LauncherHostPath 'C:\host.exe'
        }

        $result.Verified | Should -BeFalse
        $result.Reason | Should -Match 'ran elevated'
    }
}
