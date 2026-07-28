BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-LaunchTreeContentSnapshot' -Tag 'Unit' {
    BeforeEach {
        $caseRoot = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString('N'))
        $managedRoot = Join-Path -Path $caseRoot -ChildPath 'Managed'
        $personalRoot = Join-Path -Path $caseRoot -ChildPath 'Personal'
        $null = New-Item -Path $managedRoot -ItemType Directory -Force
        $null = New-Item -Path $personalRoot -ItemType Directory -Force

        $script:testConfiguration = [PSCustomObject] @{
            ManagedRoot   = $managedRoot
            PersonalRoot  = $personalRoot
            MaximumDepth  = 5
            SortOrder     = 'NameAscending'
        }
    }

    Context 'When managed and personal content is valid' {
        It 'Should create one merged Content Snapshot without exposing invalid root content' {
            $entryA = New-Item -Path (Join-Path $managedRoot 'EntryA') -ItemType Directory
            $null = New-Item -Path (Join-Path $managedRoot 'EntryB') -ItemType Directory
            $tools = New-Item -Path (Join-Path $entryA.FullName 'Tools') -ItemType Directory
            $personalEntry = New-Item -Path (Join-Path $personalRoot 'EntryA') -ItemType Directory
            $personalTools = New-Item -Path (Join-Path $personalEntry.FullName 'Tools') -ItemType Directory
            $null = New-Item -Path (Join-Path $personalRoot 'PersonalOnly') -ItemType Directory

            'Entry description' |
                Set-Content -LiteralPath (Join-Path $entryA.FullName 'description.txt') -Encoding UTF8
            "Tools line 1`nTools line 2" |
                Set-Content -LiteralPath (Join-Path $tools.FullName 'description.txt') -Encoding UTF8

            @('[InternetShortcut]', 'URL=https://managed.example/path') |
                Set-Content -LiteralPath (Join-Path $entryA.FullName 'Portal.url') -Encoding ASCII
            @('[InternetShortcut]', 'URL=https://personal.example/path') |
                Set-Content -LiteralPath (Join-Path $personalEntry.FullName 'Portal.url') -Encoding ASCII
            @('[InternetShortcut]', 'URL=https://personal.example/media') |
                Set-Content -LiteralPath (Join-Path $personalTools.FullName 'Personal media.url') -Encoding ASCII
            @('[InternetShortcut]', 'URL=file:///C:/Windows/notepad.exe') |
                Set-Content -LiteralPath (Join-Path $entryA.FullName 'Blocked.url') -Encoding ASCII
            @('[InternetShortcut]', 'URL=https://ignored.example') |
                Set-Content -LiteralPath (Join-Path $managedRoot 'Loose.url') -Encoding ASCII

            $linkPath = Join-Path $tools.FullName 'Editor.lnk'
            $shell = New-Object -ComObject WScript.Shell
            try {
                $shortcut = $shell.CreateShortcut($linkPath)
                $shortcut.TargetPath = Join-Path $env:SystemRoot 'System32\notepad.exe'
                $shortcut.Description = 'Text editor description'
                $shortcut.Save()
            } finally {
                if ($shortcut) {
                    [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut)
                }
                [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
            }

            $result = InModuleScope -ModuleName $moduleName -Parameters @{
                TestConfiguration = $script:testConfiguration
            } {
                Get-LaunchTreeContentSnapshot -Configuration $TestConfiguration
            }

            $result.PSObject.TypeNames | Should -Contain 'LaunchTree.ContentSnapshot'
            $result.EntryRoots | Should -HaveCount 2
            $result.EntryRoots.Name | Should -Be @('EntryA', 'EntryB')
            ($result.EntryRoots | Where-Object Name -eq 'EntryA').Description |
                Should -Be 'Entry description'

            $portalItems = @($result.Objects | Where-Object Name -eq 'Portal')
            $portalItems | Should -HaveCount 2
            $portalItems.ContentSource | Should -Contain 'Managed'
            $portalItems.ContentSource | Should -Contain 'Personal'

            $toolsFolders = @($result.Objects |
                Where-Object { $_.Kind -eq 'MenuFolder' -and $_.Name -eq 'Tools' })
            $toolsFolders | Should -HaveCount 1
            $toolsFolder = $toolsFolders[0]
            $toolsFolder.Description | Should -Be "Tools line 1`nTools line 2"
            $toolsChildren = @($result.Objects | Where-Object ParentRelativePath -eq 'Tools')
            $toolsChildren.Name | Should -Contain 'Editor'
            $toolsChildren.Name | Should -Contain 'Personal media'

            $editor = $result.Objects | Where-Object Name -eq 'Editor'
            $editor.Kind | Should -Be 'LaunchItem'
            $editor.Extension | Should -Be '.lnk'
            $editor.Description | Should -Be 'Text editor description'

            $result.Objects.Name | Should -Not -Contain 'Blocked'
            $result.Objects.Name | Should -Not -Contain 'Loose'
            $result.EntryRoots.Name | Should -Not -Contain 'PersonalOnly'
            $result.HealthFindings.Code | Should -Contain 'UrlSchemeRejected'
        }
    }

    Context 'When content exceeds the configured maximum depth' {
        It 'Should preserve visible siblings and report excluded deeper content' {
            $entry = New-Item -Path (Join-Path $managedRoot 'EntryA') -ItemType Directory
            $levelTwo = New-Item -Path (Join-Path $entry.FullName 'LevelTwo') -ItemType Directory
            $levelThree = New-Item -Path (Join-Path $levelTwo.FullName 'LevelThree') -ItemType Directory
            @('[InternetShortcut]', 'URL=https://excluded.example') |
                Set-Content -LiteralPath (Join-Path $levelThree.FullName 'Excluded.url') -Encoding ASCII
            @('[InternetShortcut]', 'URL=https://visible.example') |
                Set-Content -LiteralPath (Join-Path $entry.FullName 'Visible.url') -Encoding ASCII
            $script:testConfiguration.MaximumDepth = 2

            $result = InModuleScope -ModuleName $moduleName -Parameters @{
                TestConfiguration = $script:testConfiguration
            } {
                Get-LaunchTreeContentSnapshot -Configuration $TestConfiguration
            }

            $result.Objects.Name | Should -Contain 'LevelTwo'
            $result.Objects.Name | Should -Contain 'Visible'
            $result.Objects.Name | Should -Not -Contain 'LevelThree'
            $result.Objects.Name | Should -Not -Contain 'Excluded'
            $result.HealthFindings.Code | Should -Contain 'MaximumDepthExceeded'
        }
    }

    Context 'When content crosses a reparse or metadata boundary' {
        It 'Should ignore a junction and report the boundary' {
            $entry = New-Item -Path (Join-Path $managedRoot 'EntryA') -ItemType Directory
            $outside = New-Item -Path (Join-Path $TestDrive 'Outside') -ItemType Directory
            @('[InternetShortcut]', 'URL=https://outside.example') |
                Set-Content -LiteralPath (Join-Path $outside.FullName 'Outside.url') -Encoding ASCII
            $junctionParameters = @{
                Path     = Join-Path $entry.FullName 'Junction'
                ItemType = 'Junction'
                Target   = $outside.FullName
            }
            $null = New-Item @junctionParameters

            $result = InModuleScope -ModuleName $moduleName -Parameters @{
                TestConfiguration = $script:testConfiguration
            } {
                Get-LaunchTreeContentSnapshot -Configuration $TestConfiguration
            }

            $result.Objects.Name | Should -Not -Contain 'Outside'
            $result.HealthFindings.Code | Should -Contain 'ReparsePointIgnored'
        }

        It 'Should keep a Menu Folder usable when description metadata is oversized' {
            $entry = New-Item -Path (Join-Path $managedRoot 'EntryA') -ItemType Directory
            $folder = New-Item -Path (Join-Path $entry.FullName 'Large description') -ItemType Directory
            ('x' * 70000) |
                Set-Content -LiteralPath (Join-Path $folder.FullName 'description.txt') -Encoding UTF8

            $result = InModuleScope -ModuleName $moduleName -Parameters @{
                TestConfiguration = $script:testConfiguration
            } {
                Get-LaunchTreeContentSnapshot -Configuration $TestConfiguration
            }

            $result.Objects.Name | Should -Contain 'Large description'
            ($result.Objects | Where-Object Name -eq 'Large description').Description |
                Should -BeNullOrEmpty
            $result.HealthFindings.Code | Should -Contain 'DescriptionUnavailable'
        }
    }
}