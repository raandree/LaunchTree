BeforeAll {
    $script:moduleName = 'StartMenuFolders'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Save-StartMenuFolderPreference' -Tag 'Unit' {
    It 'Should persist only allowed presentation state as schema version 1' {
        $preferencePath = Join-Path $TestDrive 'Preferences\StartMenuFolders.preferences.json'
        $configuration = [PSCustomObject] @{
            PreferencePath    = $preferencePath
            CloseAfterLaunch  = $false
        }

        InModuleScope -ModuleName $moduleName -Parameters @{
            TestConfiguration = $configuration
        } {
            $parameters = @{
                Configuration = $TestConfiguration
                SortOrder     = 'NameDescending'
                Width         = 820
                Height        = 640
                Left          = 25
                Top           = 35
            }
            Save-StartMenuFolderPreference @parameters
        }

        $preference = Get-Content -LiteralPath $preferencePath -Raw | ConvertFrom-Json
        $preference.SchemaVersion | Should -Be 1
        $preference.SortOrder | Should -Be 'NameDescending'
        $preference.CloseAfterLaunch | Should -BeFalse
        $preference.Window.Width | Should -Be 820
        $preference.Window.Height | Should -Be 640
        $preference.PSObject.Properties.Name | Should -Not -Contain 'ManagedRoot'
        $preference.PSObject.Properties.Name | Should -Not -Contain 'TargetPath'
    }
}