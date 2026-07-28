BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'LaunchTree activation channel' -Tag 'Unit' {
    It 'Should create a deterministic session-local channel identity' {
        $first = InModuleScope -ModuleName $moduleName {
            Get-LaunchTreeSessionIdentity
        }
        $second = InModuleScope -ModuleName $moduleName {
            Get-LaunchTreeSessionIdentity
        }

        $first.MutexName | Should -Be $second.MutexName
        $first.PipeName | Should -Be $second.PipeName
        $first.MutexName | Should -Match '^Local\\LaunchTree\.'
        $first.PipeName | Should -Match '^LaunchTree\.'
        $first.PipeName | Should -Not -Match '[\\/:*?"<>|]'
    }

    It 'Should forward one activation message through a current-user pipe' {
        $pipeName = 'LaunchTree.Test.{0}' -f [guid]::NewGuid().ToString('N')

        $message = InModuleScope -ModuleName $moduleName -Parameters @{
            TestPipeName = $pipeName
        } {
            Initialize-LaunchTreeWpf
            $server = [LaunchTree.ActivationServer]::new($TestPipeName)
            try {
                $server.Start()
                [LaunchTree.ActivationChannel]::Send(
                    $TestPipeName,
                    '{"EntryId":"example"}',
                    5000
                )
                $server.Take(5000)
            } finally {
                $server.Dispose()
            }
        }

        $message | Should -Be '{"EntryId":"example"}'
    }
}