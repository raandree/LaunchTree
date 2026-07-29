BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Test-LaunchTree' -Tag 'Unit' {
    BeforeEach {
        $script:caseRoot = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString('N'))
        $script:managedRoot = Join-Path $script:caseRoot 'Managed'
        $script:configurationPath = Join-Path $script:caseRoot 'LaunchTree.json'
        $script:statePath = Join-Path $script:caseRoot 'LaunchTree.generated.json'
        $script:startMenuPath = Join-Path $script:caseRoot 'Programs'
        $null = New-Item -Path $script:caseRoot -ItemType Directory -Force
    }

    It 'Should report Unhealthy when the Managed Root is missing' {
        @{
            SchemaVersion = 1
            ManagedRoot   = $script:managedRoot
            PersonalRoot  = Join-Path $script:caseRoot 'Personal'
        } | ConvertTo-Json | Set-Content $script:configurationPath -Encoding UTF8

        $parameters = @{
            ConfigurationPath = $script:configurationPath
            GeneratedStatePath = $script:statePath
            StartMenuPath       = $script:startMenuPath
            SkipEventLog        = $true
        }
        $result = Test-LaunchTree @parameters

        $result.Status | Should -Be 'Unhealthy'
        $result.HealthFindings.Code | Should -Contain 'ManagedRootInaccessible'
    }

    It 'Should report Degraded when Entry Roots are not reconciled' {
        $null = New-Item -Path (Join-Path $script:managedRoot 'EntryA') -ItemType Directory -Force
        @{
            SchemaVersion = 1
            ManagedRoot   = $script:managedRoot
            PersonalRoot  = Join-Path $script:caseRoot 'Personal'
        } | ConvertTo-Json | Set-Content $script:configurationPath -Encoding UTF8

        $parameters = @{
            ConfigurationPath = $script:configurationPath
            GeneratedStatePath = $script:statePath
            StartMenuPath       = $script:startMenuPath
            SkipEventLog        = $true
        }
        $result = Test-LaunchTree @parameters

        $result.Status | Should -Be 'Degraded'
        $result.HealthFindings.Code | Should -Contain 'GeneratedStateMissing'
    }

    It 'Should evaluate a CR-013 Managed Root override instead of the configured root' {
        $overrideRoot = Join-Path $script:caseRoot 'Relocated'
        $null = New-Item -Path (Join-Path $overrideRoot 'EntryA') -ItemType Directory -Force
        @{
            SchemaVersion = 1
            ManagedRoot   = $script:managedRoot
            PersonalRoot  = Join-Path $script:caseRoot 'Personal'
        } | ConvertTo-Json | Set-Content $script:configurationPath -Encoding UTF8

        $parameters = @{
            ConfigurationPath  = $script:configurationPath
            ManagedRoot        = $overrideRoot
            GeneratedStatePath = $script:statePath
            StartMenuPath      = $script:startMenuPath
            SkipEventLog       = $true
        }
        $result = Test-LaunchTree @parameters

        $result.EntryRootCount | Should -Be 1
        $result.HealthFindings.Code | Should -Not -Contain 'ManagedRootInaccessible'
    }

    It 'Should report Unhealthy without reading future-schema fields' {
        @{
            SchemaVersion = 2
            ManagedRoot   = $script:managedRoot
        } | ConvertTo-Json | Set-Content $script:configurationPath -Encoding UTF8

        $parameters = @{
            ConfigurationPath = $script:configurationPath
            GeneratedStatePath = $script:statePath
            StartMenuPath       = $script:startMenuPath
            SkipEventLog        = $true
        }
        $result = Test-LaunchTree @parameters

        $result.Status | Should -Be 'Unhealthy'
        $result.HealthFindings.Code | Should -Contain 'ConfigurationSchemaUnsupported'
        $result.EntryRootCount | Should -Be 0
    }
}