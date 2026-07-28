BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Update-LaunchTree' -Tag 'Unit' {
    BeforeEach {
        $caseRoot = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString('N'))
        $script:managedRoot = Join-Path -Path $caseRoot -ChildPath 'Managed'
        $script:startMenuPath = Join-Path -Path $caseRoot -ChildPath 'Programs'
        $script:configurationPath = Join-Path -Path $caseRoot -ChildPath 'LaunchTree.json'
        $script:generatedStatePath = Join-Path -Path $caseRoot -ChildPath 'LaunchTree.generated.json'
        $null = New-Item -Path $script:managedRoot -ItemType Directory -Force
        $null = New-Item -Path $script:startMenuPath -ItemType Directory -Force

        @{
            SchemaVersion = 1
            ManagedRoot   = $script:managedRoot
            PersonalRoot  = Join-Path -Path $TestDrive -ChildPath 'Personal'
            MaximumDepth  = 5
        } | ConvertTo-Json -Depth 4 |
            Set-Content -LiteralPath $script:configurationPath -Encoding UTF8

        $script:updateParameters = @{
            ConfigurationPath        = $script:configurationPath
            StartMenuPath             = $script:startMenuPath
            GeneratedStatePath        = $script:generatedStatePath
            SkipEventLogRegistration = $true
            Confirm                   = $false
        }
    }

    Context 'When Entry Roots need Start Entries' {
        It 'Should create owned Start Entries with stable opaque Entry IDs' {
            Mock -ModuleName $moduleName -CommandName Write-LaunchTreeEvent -MockWith {
                $true
            }
            $null = New-Item -Path (Join-Path $script:managedRoot 'EntryA') -ItemType Directory
            $null = New-Item -Path (Join-Path $script:managedRoot 'EntryB') -ItemType Directory

            $firstResult = Update-LaunchTree @script:updateParameters
            $firstState = Get-Content -LiteralPath $script:generatedStatePath -Raw |
                ConvertFrom-Json
            $firstIdentifiers = @{}
            foreach ($entry in $firstState.StartEntries) {
                $firstIdentifiers[$entry.EntryRootPath] = $entry.EntryId
                { [guid]::Parse($entry.EntryId) } | Should -Not -Throw
            }

            $secondResult = Update-LaunchTree @script:updateParameters
            $secondState = Get-Content -LiteralPath $script:generatedStatePath -Raw |
                ConvertFrom-Json

            $firstResult.Succeeded | Should -BeTrue
            $firstResult.Added | Should -HaveCount 2
            $secondResult.Succeeded | Should -BeTrue
            $secondResult.Added | Should -BeNullOrEmpty
            $secondResult.Updated | Should -BeNullOrEmpty
            $secondResult.Removed | Should -BeNullOrEmpty
            Get-ChildItem -LiteralPath $script:startMenuPath -Filter '*.lnk' |
                Should -HaveCount 2
            foreach ($entry in $secondState.StartEntries) {
                $entry.EntryId | Should -Be $firstIdentifiers[$entry.EntryRootPath]
            }
            $assertion = @{
                ModuleName      = $moduleName
                CommandName     = 'Write-LaunchTreeEvent'
                Times           = 2
                Exactly         = $true
                ParameterFilter = { $EventId -eq 1302 }
            }
            Should -Invoke @assertion
        }

        It 'Should remove only stale Start Entries recorded as owned' {
            $entryA = New-Item -Path (Join-Path $script:managedRoot 'EntryA') -ItemType Directory
            $entryB = New-Item -Path (Join-Path $script:managedRoot 'EntryB') -ItemType Directory
            $null = Update-LaunchTree @script:updateParameters
            $initialState = Get-Content -LiteralPath $script:generatedStatePath -Raw |
                ConvertFrom-Json
            $entryAId = ($initialState.StartEntries |
                Where-Object EntryRootPath -eq $entryA.FullName).EntryId

            Remove-Item -LiteralPath $entryB.FullName -Recurse -Force
            $result = Update-LaunchTree @script:updateParameters
            $updatedState = Get-Content -LiteralPath $script:generatedStatePath -Raw |
                ConvertFrom-Json

            $result.Removed | Should -Contain (Join-Path $script:startMenuPath 'EntryB.lnk')
            Join-Path $script:startMenuPath 'EntryB.lnk' | Should -Not -Exist
            Join-Path $script:startMenuPath 'EntryA.lnk' | Should -Exist
            $updatedState.StartEntries | Should -HaveCount 1
            $updatedState.StartEntries[0].EntryId | Should -Be $entryAId
        }
    }

    Context 'When an unowned Start shortcut collides with an Entry Root' {
        It 'Should fail before modifying the unowned shortcut or Generated State' {
            $null = New-Item -Path (Join-Path $script:managedRoot 'EntryA') -ItemType Directory
            $collisionPath = Join-Path $script:startMenuPath 'EntryA.lnk'
            'unowned-content' | Set-Content -LiteralPath $collisionPath -Encoding ASCII
            $originalHash = (Get-FileHash -LiteralPath $collisionPath).Hash

            { Update-LaunchTree @script:updateParameters } |
                Should -Throw -ExpectedMessage '*unowned*'

            (Get-FileHash -LiteralPath $collisionPath).Hash | Should -Be $originalHash
            $script:generatedStatePath | Should -Not -Exist
        }
    }

    Context 'When machine configuration uses a future schema' {
        It 'Should refuse mutation before creating Generated State' {
            @{ SchemaVersion = 2 } |
                ConvertTo-Json |
                Set-Content -LiteralPath $script:configurationPath -Encoding UTF8

            { Update-LaunchTree @script:updateParameters } |
                Should -Throw -ExpectedMessage '*schema version*'
            $script:generatedStatePath | Should -Not -Exist
            Get-ChildItem -LiteralPath $script:startMenuPath -Filter '*.lnk' |
                Should -BeNullOrEmpty
        }
    }

    Context 'When a transaction fails after a Start Entry changes' {
        It 'Should restore the prior Start Entry and Generated State' {
            $entry = New-Item -Path (Join-Path $script:managedRoot 'EntryA') -ItemType Directory
            $null = Update-LaunchTree @script:updateParameters
            $shortcutPath = Join-Path $script:startMenuPath 'EntryA.lnk'
            $originalShortcutHash = (Get-FileHash -LiteralPath $shortcutPath).Hash
            $originalState = Get-Content -LiteralPath $script:generatedStatePath -Raw
            'Changed description' |
                Set-Content -LiteralPath (Join-Path $entry.FullName 'description.txt') -Encoding UTF8

            Mock -ModuleName $moduleName -CommandName Copy-Item -MockWith {
                param(
                    $LiteralPath,
                    $Destination,
                    $Force
                )

                $copyParameters = @{
                    LiteralPath = $LiteralPath
                    Destination = $Destination
                    Force       = $Force
                }
                Microsoft.PowerShell.Management\Copy-Item @copyParameters
            }
            Mock -ModuleName $moduleName -CommandName Copy-Item -ParameterFilter {
                $LiteralPath -like '*staging*GeneratedState.json' -and
                $Destination -eq $script:generatedStatePath
            } -MockWith {
                throw [System.IO.IOException]::new('Injected ownership commit failure.')
            }
            Mock -ModuleName $moduleName -CommandName Write-LaunchTreeEvent -MockWith {
                $true
            }

            { Update-LaunchTree @script:updateParameters } |
                Should -Throw -ExpectedMessage '*Injected ownership commit failure*'

            (Get-FileHash -LiteralPath $shortcutPath).Hash | Should -Be $originalShortcutHash
            Get-Content -LiteralPath $script:generatedStatePath -Raw | Should -Be $originalState
            $assertion = @{
                ModuleName      = $moduleName
                CommandName     = 'Write-LaunchTreeEvent'
                Times           = 1
                Exactly         = $true
                ParameterFilter = { $EventId -eq 1301 }
            }
            Should -Invoke @assertion
        }
    }
}