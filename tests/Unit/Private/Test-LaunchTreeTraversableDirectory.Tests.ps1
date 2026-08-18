BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Test-LaunchTreeTraversableDirectory' -Tag 'Unit' {
    BeforeEach {
        $script:caseRoot = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString('N'))
        $null = New-Item -Path $script:caseRoot -ItemType Directory -Force
    }

    It 'Should traverse a plain directory' {
        $plain = New-Item -Path (Join-Path $script:caseRoot 'Plain') -ItemType Directory

        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            TestDirectory = $plain
        } {
            Test-LaunchTreeTraversableDirectory -Directory $TestDirectory
        }

        $result | Should -BeTrue
    }

    It 'Should refuse a junction' {
        $target = New-Item -Path (Join-Path $script:caseRoot 'Target') -ItemType Directory
        $junctionParameters = @{
            Path     = Join-Path $script:caseRoot 'Junction'
            ItemType = 'Junction'
            Target   = $target.FullName
        }
        $junction = New-Item @junctionParameters

        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            TestDirectory = $junction
        } {
            Test-LaunchTreeTraversableDirectory -Directory $TestDirectory
        }

        $result | Should -BeFalse
    }

    It 'Should traverse a directory whose reparse tag is a DFS link' {
        $target = New-Item -Path (Join-Path $script:caseRoot 'DfsTarget') -ItemType Directory
        $junctionParameters = @{
            Path     = Join-Path $script:caseRoot 'DfsLink'
            ItemType = 'Junction'
            Target   = $target.FullName
        }
        $link = New-Item @junctionParameters

        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            TestDirectory = $link
        } {
            Mock -CommandName Get-LaunchTreeReparseTag -MockWith { [uint32] 0x8000000Al }

            Test-LaunchTreeTraversableDirectory -Directory $TestDirectory
        }

        $result | Should -BeTrue
    }

    It 'Should report the reparse tag of a junction' {
        $target = New-Item -Path (Join-Path $script:caseRoot 'TagTarget') -ItemType Directory
        $junctionParameters = @{
            Path     = Join-Path $script:caseRoot 'TagJunction'
            ItemType = 'Junction'
            Target   = $target.FullName
        }
        $junction = New-Item @junctionParameters

        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            TestPath = $junction.FullName
        } {
            Get-LaunchTreeReparseTag -LiteralPath $TestPath
        }

        # IO_REPARSE_TAG_MOUNT_POINT
        $result | Should -Be ([uint32] 0xA0000003l)
    }
}
