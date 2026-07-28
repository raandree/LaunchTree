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
}