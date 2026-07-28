BeforeAll {
    $script:moduleName = 'StartMenuFolders'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Test-StartMenuFolder' -Tag 'Unit' {
    BeforeEach {
        $script:caseRoot = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString('N'))
        $script:managedRoot = Join-Path $script:caseRoot 'Managed'
        $script:configurationPath = Join-Path $script:caseRoot 'StartMenuFolders.json'
        $script:statePath = Join-Path $script:caseRoot 'StartMenuFolders.generated.json'
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
        $result = Test-StartMenuFolder @parameters

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
        $result = Test-StartMenuFolder @parameters

        $result.Status | Should -Be 'Degraded'
        $result.HealthFindings.Code | Should -Contain 'GeneratedStateMissing'
    }
}