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
            @('[InternetShortcut]', 'URL=https://leveltwo.example') |
                Set-Content -LiteralPath (Join-Path $levelTwo.FullName 'Level two.url') -Encoding ASCII
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

        It 'Should discover an Entry Root and content behind a DFS link' {
            $target = New-Item -Path (Join-Path $TestDrive 'DfsTarget') -ItemType Directory
            $folder = New-Item -Path (Join-Path $target.FullName 'Tools') -ItemType Directory
            @('[InternetShortcut]', 'URL=https://dfs.example') |
                Set-Content -LiteralPath (Join-Path $folder.FullName 'Behind DFS.url') -Encoding ASCII
            $linkParameters = @{
                Path     = Join-Path $managedRoot 'EntryDfs'
                ItemType = 'Junction'
                Target   = $target.FullName
            }
            $null = New-Item @linkParameters

            $result = InModuleScope -ModuleName $moduleName -Parameters @{
                TestConfiguration = $script:testConfiguration
            } {
                Mock -CommandName Get-LaunchTreeReparseTag -MockWith { [uint32] 0x8000000Al }

                Get-LaunchTreeContentSnapshot -Configuration $TestConfiguration
            }

            $result.EntryRoots.Name | Should -Contain 'EntryDfs'
            $result.Objects.Name | Should -Contain 'Behind DFS'
            $result.HealthFindings.Code | Should -Not -Contain 'ReparsePointIgnored'
        }

        It 'Should keep a Menu Folder usable when description metadata is oversized' {
            $entry = New-Item -Path (Join-Path $managedRoot 'EntryA') -ItemType Directory
            $folder = New-Item -Path (Join-Path $entry.FullName 'Large description') -ItemType Directory
            @('[InternetShortcut]', 'URL=https://described.example') |
                Set-Content -LiteralPath (Join-Path $folder.FullName 'Described.url') -Encoding ASCII
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

    Context 'When a Menu Folder subtree contains no Launch Item' {
        It 'Should hide empty Menu Folders and keep folders whose only content is nested' {
            $entry = New-Item -Path (Join-Path $managedRoot 'EntryA') -ItemType Directory
            $null = New-Item -Path (Join-Path $entry.FullName 'Empty folder') -ItemType Directory
            $emptyParent = New-Item -Path (Join-Path $entry.FullName 'Empty parent') -ItemType Directory
            $null = New-Item -Path (Join-Path $emptyParent.FullName 'Empty child') -ItemType Directory
            $nested = New-Item -Path (Join-Path $entry.FullName 'Nested') -ItemType Directory
            $deep = New-Item -Path (Join-Path $nested.FullName 'Deep') -ItemType Directory
            @('[InternetShortcut]', 'URL=https://deep.example') |
                Set-Content -LiteralPath (Join-Path $deep.FullName 'Deep link.url') -Encoding ASCII

            $result = InModuleScope -ModuleName $moduleName -Parameters @{
                TestConfiguration = $script:testConfiguration
            } {
                Get-LaunchTreeContentSnapshot -Configuration $TestConfiguration
            }

            $result.Objects.Name | Should -Not -Contain 'Empty folder'
            $result.Objects.Name | Should -Not -Contain 'Empty parent'
            $result.Objects.Name | Should -Not -Contain 'Empty child'
            $result.Objects.Name | Should -Contain 'Nested'
            $result.Objects.Name | Should -Contain 'Deep'
            $result.Objects.Name | Should -Contain 'Deep link'
        }
    }
}