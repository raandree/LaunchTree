BeforeAll {
    $script:moduleName = 'StartMenuFolders'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'StartMenuFolder activation channel' -Tag 'Unit' {
    It 'Should create a deterministic session-local channel identity' {
        $first = InModuleScope -ModuleName $moduleName {
            Get-StartMenuFolderSessionIdentity
        }
        $second = InModuleScope -ModuleName $moduleName {
            Get-StartMenuFolderSessionIdentity
        }

        $first.MutexName | Should -Be $second.MutexName
        $first.PipeName | Should -Be $second.PipeName
        $first.MutexName | Should -Match '^Local\\StartMenuFolders\.'
        $first.PipeName | Should -Match '^StartMenuFolders\.'
        $first.PipeName | Should -Not -Match '[\\/:*?"<>|]'
    }

    It 'Should forward one activation message through a current-user pipe' {
        $pipeName = 'StartMenuFolders.Test.{0}' -f [guid]::NewGuid().ToString('N')

        $message = InModuleScope -ModuleName $moduleName -Parameters @{
            TestPipeName = $pipeName
        } {
            Initialize-StartMenuFolderWpf
            $server = [StartMenuFolders.ActivationServer]::new($TestPipeName)
            try {
                $server.Start()
                [StartMenuFolders.ActivationChannel]::Send(
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