BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'New-LaunchTreeLauncherShortcut' -Tag 'Unit' {
    It 'Should write a shortcut that reproduces the derived launcher command line' {
        $shortcutPath = Join-Path -Path $TestDrive -ChildPath 'Links\Programs.lnk'

        $created = InModuleScope -ModuleName $moduleName -Parameters @{
            TargetShortcutPath = $shortcutPath
        } {
            $definitionParameters = @{
                EntryRootPath    = 'C:\Menus\Contoso\Programs'
                LauncherHostPath = Join-Path $env:SystemRoot 'System32\notepad.exe'
                LauncherPath     = 'C:\Tools\LaunchTree.Minimal.ps1'
                LauncherCommand  = 'Show'
            }
            $definition = Get-LaunchTreeShortcutDefinition @definitionParameters
            New-LaunchTreeLauncherShortcut -LiteralPath $TargetShortcutPath `
                -Definition $definition
        }

        $created | Should -Be $shortcutPath
        $shortcutPath | Should -Exist

        $shell = New-Object -ComObject WScript.Shell
        try {
            $shortcut = $shell.CreateShortcut($shortcutPath)
            try {
                $shortcut.TargetPath | Should -Be (
                    Join-Path $env:SystemRoot 'System32\notepad.exe'
                )
                $shortcut.Arguments | Should -Match ([regex]::Escape(
                        '-Command "Show" -ManagedRoot "C:\Menus\Contoso" -EntryName "Programs"'
                    ))
                $shortcut.Description | Should -Be (
                    'Open the Programs Entry Root in LaunchTree.'
                )
            } finally {
                [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut)
            }
        } finally {
            [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
        }
    }

    It 'Should create nothing when the caller declines the change' {
        $shortcutPath = Join-Path -Path $TestDrive 'Declined\Programs.lnk'

        InModuleScope -ModuleName $moduleName -Parameters @{
            TargetShortcutPath = $shortcutPath
        } {
            $definitionParameters = @{
                EntryRootPath    = 'C:\Menus\Contoso\Programs'
                LauncherHostPath = Join-Path $env:SystemRoot 'System32\notepad.exe'
                LauncherPath     = 'C:\Tools\LaunchTree.Minimal.ps1'
                LauncherCommand  = 'Show'
            }
            $definition = Get-LaunchTreeShortcutDefinition @definitionParameters
            New-LaunchTreeLauncherShortcut -LiteralPath $TargetShortcutPath `
                -Definition $definition -WhatIf
        }

        $shortcutPath | Should -Not -Exist
    }
}
