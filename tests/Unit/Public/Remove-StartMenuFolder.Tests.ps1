BeforeAll {
    $script:moduleName = 'StartMenuFolders'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Remove-StartMenuFolder' -Tag 'Unit' {
    It 'Should remove only owned Generated State and preserve source content' {
        $caseRoot = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString('N'))
        $managedRoot = Join-Path $caseRoot 'Managed'
        $entryRoot = New-Item -Path (Join-Path $managedRoot 'EntryA') -ItemType Directory -Force
        $configurationPath = Join-Path $caseRoot 'StartMenuFolders.json'
        $statePath = Join-Path $caseRoot 'StartMenuFolders.generated.json'
        $shortcutPath = Join-Path $caseRoot 'EntryA.lnk'
        $cachePath = Join-Path $caseRoot 'Cache'
        $null = New-Item -Path $shortcutPath -ItemType File
        $null = New-Item -Path $cachePath -ItemType Directory
        $null = New-Item -Path (Join-Path $cachePath 'icon.bin') -ItemType File
        @{
            SchemaVersion = 1
            ManagedRoot   = $managedRoot
            PersonalRoot  = Join-Path $caseRoot 'Personal'
        } | ConvertTo-Json | Set-Content $configurationPath -Encoding UTF8
        @{
            SchemaVersion = 1
            ManagedRoot   = $managedRoot
            StartEntries  = @(
                @{ EntryId = [guid]::NewGuid(); EntryRootPath = $entryRoot.FullName; ShortcutPath = $shortcutPath }
            )
        } | ConvertTo-Json -Depth 4 | Set-Content $statePath -Encoding UTF8

        $parameters = @{
            ConfigurationPath = $configurationPath
            GeneratedStatePath = $statePath
            CachePath           = $cachePath
            SkipEventLog        = $true
            Confirm             = $false
        }
        $result = Remove-StartMenuFolder @parameters

        $result.Succeeded | Should -BeTrue
        $shortcutPath | Should -Not -Exist
        $statePath | Should -Not -Exist
        $cachePath | Should -Not -Exist
        $configurationPath | Should -Exist
        $managedRoot | Should -Exist
    }
}