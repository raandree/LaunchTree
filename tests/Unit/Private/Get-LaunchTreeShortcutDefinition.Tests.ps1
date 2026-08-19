BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-LaunchTreeShortcutDefinition' -Tag 'Unit' {
    It 'Should split a UNC Entry Root path into Managed Root and Entry Root name' {
        $definition = InModuleScope -ModuleName $moduleName {
            $parameters = @{
                EntryRootPath    = '\\contoso.com\Data\Files\programs'
                LauncherHostPath = 'C:\Windows\System32\powershell.exe'
                LauncherPath     = 'C:\Tools\LaunchTree.Minimal.ps1'
                LauncherCommand  = 'Show'
            }
            Get-LaunchTreeShortcutDefinition @parameters
        }

        $definition.ManagedRoot | Should -Be '\\contoso.com\Data\Files'
        $definition.EntryName | Should -Be 'programs'
        $definition.TargetPath | Should -Be 'C:\Windows\System32\powershell.exe'
        $definition.FileName | Should -Be 'programs.lnk'
        $definition.WorkingDirectory | Should -Be 'C:\Tools'
        $definition.Arguments | Should -BeLike (
            '*-File "C:\Tools\LaunchTree.Minimal.ps1" -Command "Show" ' +
            '-ManagedRoot "\\contoso.com\Data\Files" -EntryName "programs"'
        )
        $definition.Arguments | Should -Not -Match '-CloseAfterLaunch'
    }

    It 'Should ignore a trailing separator on the Entry Root path' {
        $definition = InModuleScope -ModuleName $moduleName {
            $parameters = @{
                EntryRootPath    = 'C:\Menus\Contoso\Programs\'
                LauncherHostPath = 'C:\Windows\System32\powershell.exe'
                LauncherPath     = 'C:\Tools\LaunchTree.Minimal.ps1'
                LauncherCommand  = 'Show'
            }
            Get-LaunchTreeShortcutDefinition @parameters
        }

        $definition.ManagedRoot | Should -Be 'C:\Menus\Contoso'
        $definition.EntryName | Should -Be 'Programs'
    }

    It 'Should keep the trailing separator when the Managed Root is a drive root' {
        $definition = InModuleScope -ModuleName $moduleName {
            $parameters = @{
                EntryRootPath    = 'D:\Programs'
                LauncherHostPath = 'C:\Windows\System32\powershell.exe'
                LauncherPath     = 'C:\Tools\LaunchTree.Minimal.ps1'
                LauncherCommand  = 'Show'
            }
            Get-LaunchTreeShortcutDefinition @parameters
        }

        $definition.ManagedRoot | Should -Be 'D:\'
        $definition.EntryName | Should -Be 'Programs'
    }

    It 'Should append the close switch only when closing is requested' {
        $definition = InModuleScope -ModuleName $moduleName {
            $parameters = @{
                EntryRootPath    = 'C:\Menus\Contoso\Programs'
                LauncherHostPath = 'C:\Windows\System32\powershell.exe'
                LauncherPath     = 'C:\Tools\LaunchTree.Minimal.ps1'
                LauncherCommand  = 'Show'
                CloseAfterLaunch = $true
            }
            Get-LaunchTreeShortcutDefinition @parameters
        }

        $definition.CloseAfterLaunch | Should -BeTrue
        $definition.Arguments | Should -Match '-CloseAfterLaunch$'
    }

    It 'Should omit the command token when the delivery has no command dispatcher' {
        $definition = InModuleScope -ModuleName $moduleName {
            $parameters = @{
                EntryRootPath    = 'C:\Menus\Contoso\Programs'
                LauncherHostPath = 'C:\Windows\System32\powershell.exe'
                LauncherPath     = 'C:\Program Files\LaunchTree\Start-LaunchTreeLauncher.ps1'
                LauncherCommand  = $null
            }
            Get-LaunchTreeShortcutDefinition @parameters
        }

        $definition.Arguments | Should -Not -Match '-Command'
        $definition.Arguments | Should -Match (
            [regex]::Escape('-File "C:\Program Files\LaunchTree\Start-LaunchTreeLauncher.ps1"')
        )
    }

    It 'Should replace characters a shortcut file name cannot carry' {
        $definition = InModuleScope -ModuleName $moduleName {
            $parameters = @{
                EntryRootPath    = 'C:\Menus\Contoso\Line:Of Business'
                LauncherHostPath = 'C:\Windows\System32\powershell.exe'
                LauncherPath     = 'C:\Tools\LaunchTree.Minimal.ps1'
                LauncherCommand  = 'Show'
            }
            Get-LaunchTreeShortcutDefinition @parameters
        }

        $definition.EntryName | Should -Be 'Line:Of Business'
        $definition.FileName | Should -Be 'Line_Of Business.lnk'
    }

    It 'Should reject a relative path' {
        {
            InModuleScope -ModuleName $moduleName {
                $parameters = @{
                    EntryRootPath    = 'Menus\Programs'
                    LauncherHostPath = 'C:\Windows\System32\powershell.exe'
                    LauncherPath     = 'C:\Tools\LaunchTree.Minimal.ps1'
                }
                Get-LaunchTreeShortcutDefinition @parameters
            }
        } | Should -Throw -ExpectedMessage '*is not an absolute path*'
    }

    It 'Should reject a UNC share that carries no Entry Root folder' {
        {
            InModuleScope -ModuleName $moduleName {
                $parameters = @{
                    EntryRootPath    = '\\contoso.com\Data'
                    LauncherHostPath = 'C:\Windows\System32\powershell.exe'
                    LauncherPath     = 'C:\Tools\LaunchTree.Minimal.ps1'
                }
                Get-LaunchTreeShortcutDefinition @parameters
            }
        } | Should -Throw -ExpectedMessage '*server, a share, and the Entry Root folder*'
    }

    It 'Should reject a drive root that has no parent folder' {
        {
            InModuleScope -ModuleName $moduleName {
                $parameters = @{
                    EntryRootPath    = 'C:\'
                    LauncherHostPath = 'C:\Windows\System32\powershell.exe'
                    LauncherPath     = 'C:\Tools\LaunchTree.Minimal.ps1'
                }
                Get-LaunchTreeShortcutDefinition @parameters
            }
        } | Should -Throw -ExpectedMessage '*no parent folder*'
    }

    It 'Should target a compiled executable directly instead of a Launcher Host' {
        $definition = InModuleScope -ModuleName $moduleName {
            $parameters = @{
                EntryRootPath        = 'C:\Menus\Contoso\Programs'
                LauncherPath         = 'C:\Program Files\LaunchTree\LaunchTree.Minimal.exe'
                LauncherCommand      = 'Show'
                LauncherIsExecutable = $true
            }
            Get-LaunchTreeShortcutDefinition @parameters
        }

        $definition.TargetPath | Should -Be 'C:\Program Files\LaunchTree\LaunchTree.Minimal.exe'
        $definition.Arguments | Should -Not -Match '-File'
        $definition.Arguments | Should -Not -Match '-ExecutionPolicy'
        $definition.Arguments | Should -Be (
            '-Command "Show" -ManagedRoot "C:\Menus\Contoso" -EntryName "Programs"'
        )
    }

    It 'Should reject a script Launcher that names no Launcher Host' {
        {
            InModuleScope -ModuleName $moduleName {
                $parameters = @{
                    EntryRootPath = 'C:\Menus\Contoso\Programs'
                    LauncherPath  = 'C:\Tools\LaunchTree.Minimal.ps1'
                }
                Get-LaunchTreeShortcutDefinition @parameters
            }
        } | Should -Throw -ExpectedMessage '*needs the path of its Launcher Host*'
    }
}
