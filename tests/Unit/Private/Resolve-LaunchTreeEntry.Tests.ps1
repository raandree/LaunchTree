BeforeAll {
    $script:moduleName = 'StartMenuFolders'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Resolve-StartMenuFolderEntry' -Tag 'Unit' {
    BeforeEach {
        $script:entryId = [guid]::NewGuid()
        $script:managedRoot = Join-Path -Path $TestDrive -ChildPath 'Managed'
        $script:entryRoot = Join-Path -Path $script:managedRoot -ChildPath 'Developer Tools'
        $script:generatedStatePath = Join-Path -Path $TestDrive -ChildPath 'Generated.json'
        $null = New-Item -Path $script:entryRoot -ItemType Directory -Force
        [ordered] @{
            SchemaVersion = 1
            ManagedRoot   = $script:managedRoot
            StartEntries  = @(
                [ordered] @{
                    EntryId       = $script:entryId.ToString()
                    Name          = 'Developer Tools'
                    EntryRootPath = $script:entryRoot
                    ShortcutPath  = Join-Path $TestDrive 'Developer Tools.lnk'
                }
            )
        } | ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath $script:generatedStatePath -Encoding UTF8
    }

    It 'Should resolve a known Entry ID only when the Managed Root matches' {
        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            TestEntryId = $script:entryId
            TestRoot    = $script:managedRoot
            TestState   = $script:generatedStatePath
        } {
            $parameters = @{
                EntryId            = $TestEntryId
                ManagedRoot        = $TestRoot
                GeneratedStatePath = $TestState
            }
            Resolve-StartMenuFolderEntry @parameters
        }

        $result.Name | Should -Be 'Developer Tools'
        $result.EntryRootPath | Should -Be $script:entryRoot
    }

    It 'Should reject an unknown Entry ID' {
        {
            InModuleScope -ModuleName $moduleName -Parameters @{
                TestEntryId = [guid]::NewGuid()
                TestRoot    = $script:managedRoot
                TestState   = $script:generatedStatePath
            } {
                $parameters = @{
                    EntryId            = $TestEntryId
                    ManagedRoot        = $TestRoot
                    GeneratedStatePath = $TestState
                }
                Resolve-StartMenuFolderEntry @parameters
            }
        } | Should -Throw -ExpectedMessage '*Entry ID*'
    }

    It 'Should reject Generated State for another Managed Root' {
        {
            InModuleScope -ModuleName $moduleName -Parameters @{
                TestEntryId = $script:entryId
                TestRoot    = Join-Path $TestDrive 'OtherRoot'
                TestState   = $script:generatedStatePath
            } {
                $parameters = @{
                    EntryId            = $TestEntryId
                    ManagedRoot        = $TestRoot
                    GeneratedStatePath = $TestState
                }
                Resolve-StartMenuFolderEntry @parameters
            }
        } | Should -Throw -ExpectedMessage '*Managed Root*'
    }

    It 'Should reject an Entry Root path outside the bound Managed Root' {
        $outsidePath = Join-Path $TestDrive 'Outside'
        $null = New-Item -Path $outsidePath -ItemType Directory
        $state = Get-Content -LiteralPath $script:generatedStatePath -Raw | ConvertFrom-Json
        $state.StartEntries[0].EntryRootPath = $outsidePath
        $state | ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath $script:generatedStatePath -Encoding UTF8

        {
            InModuleScope -ModuleName $moduleName -Parameters @{
                TestEntryId = $script:entryId
                TestRoot    = $script:managedRoot
                TestState   = $script:generatedStatePath
            } {
                $parameters = @{
                    EntryId            = $TestEntryId
                    ManagedRoot        = $TestRoot
                    GeneratedStatePath = $TestState
                }
                Resolve-StartMenuFolderEntry @parameters
            }
        } | Should -Throw -ExpectedMessage '*outside*Managed Root*'
    }
}