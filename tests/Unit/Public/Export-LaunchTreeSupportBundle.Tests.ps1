BeforeAll {
    $script:moduleName = 'StartMenuFolders'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Export-StartMenuFolderSupportBundle' -Tag 'Unit' {
    It 'Should export redacted structured evidence without Launch Item details' {
        $bundlePath = Join-Path $TestDrive 'Support.zip'
        Mock -ModuleName $moduleName -CommandName Get-StartMenuFolderConfiguration -MockWith {
            [PSCustomObject] @{
                VendorName = 'StartMenuFolders'
                ManagedRoot = 'C:\Managed'
                PersonalRoot = 'C:\Personal'
                ConfigurationPath = 'C:\Config\StartMenuFolders.json'
                PreferencePath = 'C:\Users\Person\preferences.json'
                Cache = [PSCustomObject] @{ Path = 'C:\Cache'; MaximumSizeMB = 64 }
                Diagnostics = [PSCustomObject] @{ LogName = 'StartMenuFolders' }
            }
        }
        Mock -ModuleName $moduleName -CommandName Test-StartMenuFolder -MockWith {
            [PSCustomObject] @{ Status = 'Degraded'; HealthFindings = @() }
        }
        Mock -ModuleName $moduleName -CommandName Get-StartMenuFolderDiagnostic -MockWith {
            [PSCustomObject] @{
                EventId = 1201
                Message = 'Failed https://example.test/path?[redacted]'
            }
        }

        $result = Export-StartMenuFolderSupportBundle -Path $bundlePath -Confirm:$false

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
        Mock -ModuleName $moduleName -CommandName Get-StartMenuFolderConfiguration -MockWith {
            [PSCustomObject] @{
                VendorName = 'StartMenuFolders'
                ManagedRoot = 'C:\Managed'
                PersonalRoot = 'C:\Personal'
                ConfigurationPath = 'C:\Config\StartMenuFolders.json'
                PreferencePath = 'C:\Users\Person\preferences.json'
                Cache = [PSCustomObject] @{ Path = 'C:\Cache' }
                Diagnostics = [PSCustomObject] @{
                    LogName = 'StartMenuFolders'
                    SourceName = 'StartMenuFolders'
                }
            }
        }
        Mock -ModuleName $moduleName -CommandName Test-StartMenuFolder -MockWith {
            [PSCustomObject] @{ Status = 'Healthy'; HealthFindings = @() }
        }
        Mock -ModuleName $moduleName -CommandName Get-StartMenuFolderDiagnostic
        Mock -ModuleName $moduleName -CommandName Compress-Archive -MockWith {
            throw [IO.IOException]::new('Injected archive failure.')
        }
        Mock -ModuleName $moduleName -CommandName Write-StartMenuFolderEvent -MockWith {
            $true
        }

        { Export-StartMenuFolderSupportBundle -Path $bundlePath -Confirm:$false } |
            Should -Throw -ExpectedMessage '*Injected archive failure*'
        $assertion = @{
            ModuleName      = $moduleName
            CommandName     = 'Write-StartMenuFolderEvent'
            Times           = 1
            Exactly         = $true
            ParameterFilter = { $EventId -eq 1601 }
        }
        Should -Invoke @assertion
    }
}