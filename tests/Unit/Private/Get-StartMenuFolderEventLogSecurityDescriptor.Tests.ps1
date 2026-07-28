BeforeAll {
    $script:moduleName = 'StartMenuFolders'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-StartMenuFolderEventLogSecurityDescriptor' -Tag 'Unit' {
    It 'Should grant Interactive Users read and write without clear access' {
        $descriptor = InModuleScope -ModuleName $moduleName {
            Get-StartMenuFolderEventLogSecurityDescriptor
        }

        $descriptor | Should -Be (
            'O:BAG:SYD:(A;;0x7;;;SY)(A;;0x7;;;BA)(A;;0x3;;;IU)'
        )
        $descriptor | Should -Not -Match '0x7;;;IU'
    }

    It 'Should validate only read and write access without clear rights' {
        $results = InModuleScope -ModuleName $moduleName {
            @(
                Test-StartMenuFolderInteractiveEventAccess -SecurityDescriptor (
                    'O:BAG:SYD:(A;;0x7;;;SY)(A;;0x7;;;BA)(A;;0x3;;;IU)'
                )
                Test-StartMenuFolderInteractiveEventAccess -SecurityDescriptor (
                    'O:BAG:SYD:(A;;0x7;;;SY)(A;;0x1;;;IU)'
                )
                Test-StartMenuFolderInteractiveEventAccess -SecurityDescriptor (
                    'O:BAG:SYD:(A;;0x7;;;SY)(A;;0x7;;;IU)'
                )
            )
        }

        $results | Should -Be @($true, $false, $false)
    }

    It 'Should compile the linked-token process runner on the current edition' {
        $typeName = InModuleScope -ModuleName $moduleName {
            Initialize-StartMenuFolderUnelevatedProcess
            [StartMenuFolders.UnelevatedProcess].FullName
        }

        $typeName | Should -Be 'StartMenuFolders.UnelevatedProcess'
    }
}