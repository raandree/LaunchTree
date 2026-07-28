BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Export-LaunchTreeSupportBundle' -Tag 'Unit' {
    It 'Should export redacted structured evidence without Launch Item details' {
        $bundlePath = Join-Path $TestDrive 'Support.zip'
        Mock -ModuleName $moduleName -CommandName Get-LaunchTreeConfiguration -MockWith {
            [PSCustomObject] @{
                VendorName = 'LaunchTree'
                ManagedRoot = 'C:\Managed'
                PersonalRoot = 'C:\Personal'
                ConfigurationPath = 'C:\Config\LaunchTree.json'
                PreferencePath = 'C:\Users\Person\preferences.json'
                Cache = [PSCustomObject] @{ Path = 'C:\Cache'; MaximumSizeMB = 64 }
                Diagnostics = [PSCustomObject] @{ LogName = 'LaunchTree' }
            }
        }
        Mock -ModuleName $moduleName -CommandName Test-LaunchTree -MockWith {
            [PSCustomObject] @{ Status = 'Degraded'; HealthFindings = @() }
        }
        Mock -ModuleName $moduleName -CommandName Get-LaunchTreeDiagnostic -MockWith {
            [PSCustomObject] @{
                EventId = 1201
                Message = 'Failed https://example.test/path?[redacted]'
            }
        }

        $result = Export-LaunchTreeSupportBundle -Path $bundlePath -Confirm:$false

        $result | Should -Be $bundlePath
        $bundlePath | Should -Exist
        $expandedPath = Join-Path $TestDrive 'Expanded'
        Expand-Archive -LiteralPath $bundlePath -DestinationPath $expandedPath
        $content = Get-ChildItem -LiteralPath $expandedPath -File |
            ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }
        ($content -join "`n") | Should -Not -Match 'token=|ArgumentList|TargetPath'
    }

    It 'Should emit event 1601 when archive creation fails' {
        $bundlePath = Join-Path $TestDrive 'Failed.zip'
        Mock -ModuleName $moduleName -CommandName Get-LaunchTreeConfiguration -MockWith {
            [PSCustomObject] @{
                VendorName = 'LaunchTree'
                ManagedRoot = 'C:\Managed'
                PersonalRoot = 'C:\Personal'
                ConfigurationPath = 'C:\Config\LaunchTree.json'
                PreferencePath = 'C:\Users\Person\preferences.json'
                Cache = [PSCustomObject] @{ Path = 'C:\Cache' }
                Diagnostics = [PSCustomObject] @{
                    LogName = 'LaunchTree'
                    SourceName = 'LaunchTree'
                }
            }
        }
        Mock -ModuleName $moduleName -CommandName Test-LaunchTree -MockWith {
            [PSCustomObject] @{ Status = 'Healthy'; HealthFindings = @() }
        }
        Mock -ModuleName $moduleName -CommandName Get-LaunchTreeDiagnostic
        Mock -ModuleName $moduleName -CommandName Compress-Archive -MockWith {
            throw [IO.IOException]::new('Injected archive failure.')
        }
        Mock -ModuleName $moduleName -CommandName Write-LaunchTreeEvent -MockWith {
            $true
        }

        { Export-LaunchTreeSupportBundle -Path $bundlePath -Confirm:$false } |
            Should -Throw -ExpectedMessage '*Injected archive failure*'
        $assertion = @{
            ModuleName      = $moduleName
            CommandName     = 'Write-LaunchTreeEvent'
            Times           = 1
            Exactly         = $true
            ParameterFilter = { $EventId -eq 1601 }
        }
        Should -Invoke @assertion
    }
}