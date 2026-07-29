BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-LaunchTreeIconTimer' -Tag 'Unit' {
    BeforeEach {
        $script:timer = [PSCustomObject] @{
            IsEnabled = $false
            StartCount = 0
        }
        $script:timer | Add-Member -MemberType ScriptMethod -Name Start -Value {
            $this.StartCount++
            $this.IsEnabled = $true
        }
        $script:iconJobs = [Collections.Generic.List[object]]::new()
        [void] $script:iconJobs.Add([PSCustomObject] @{ Name = 'Pending' })
    }

    It 'Should restart icon processing when a rerender queues uncached icons' {
        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            TestTimer = $script:timer
            TestJobs  = $script:iconJobs
        } {
            Invoke-LaunchTreeIconTimer -Timer $TestTimer -IconJobs $TestJobs
        }

        $result | Should -BeTrue
        $script:timer.StartCount | Should -Be 1
        $script:timer.IsEnabled | Should -BeTrue
    }

    It 'Should not start a running timer or start during capture' {
        $script:timer.IsEnabled = $true
        $runningResult = InModuleScope -ModuleName $moduleName -Parameters @{
            TestTimer = $script:timer
            TestJobs  = $script:iconJobs
        } {
            Invoke-LaunchTreeIconTimer -Timer $TestTimer -IconJobs $TestJobs
        }

        $script:timer.IsEnabled = $false
        $captureResult = InModuleScope -ModuleName $moduleName -Parameters @{
            TestTimer = $script:timer
            TestJobs  = $script:iconJobs
        } {
            $parameters = @{
                Timer       = $TestTimer
                IconJobs    = $TestJobs
                CapturePath = 'capture.png'
            }
            Invoke-LaunchTreeIconTimer @parameters
        }

        $runningResult | Should -BeFalse
        $captureResult | Should -BeFalse
        $script:timer.StartCount | Should -Be 0
    }
}