BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'New-LaunchTreeShortcut' -Tag 'Unit' {
    It 'Should expose the wizard as a public command (FR-035)' {
        $command = Get-Command -Name New-LaunchTreeShortcut -Module $moduleName

        $command.Parameters.Keys | Should -Contain 'ConfigurationPath'
        $command.Parameters.Keys | Should -Contain 'EntryRootPath'
        $command.Parameters.Keys | Should -Contain 'WhatIf'
    }

    It 'Should open no window under WhatIf (FR-035)' {
        Mock -CommandName Show-LaunchTreeShortcutWizard -ModuleName $script:moduleName -MockWith {
            'C:\Users\Example\Desktop\Programs.lnk'
        }

        $result = New-LaunchTreeShortcut -ConfigurationPath (
            Join-Path -Path $TestDrive -ChildPath 'absent.json'
        ) -WhatIf

        $result | Should -BeNullOrEmpty
        Should -Invoke -CommandName Show-LaunchTreeShortcutWizard `
            -ModuleName $script:moduleName -Times 0 -Exactly
    }

    It 'Should hand the Entry Root folder and the theme to the wizard (FR-035)' -Skip:(
        [Threading.Thread]::CurrentThread.GetApartmentState() -ne
            [Threading.ApartmentState]::STA
    ) {
        Mock -CommandName Show-LaunchTreeShortcutWizard -ModuleName $script:moduleName -MockWith {
            'C:\Users\Example\Desktop\Programs.lnk'
        }

        $parameters = @{
            EntryRootPath     = 'C:\Menus\Contoso\Programs'
            ConfigurationPath = Join-Path -Path $TestDrive -ChildPath 'absent.json'
            Confirm           = $false
        }
        $result = New-LaunchTreeShortcut @parameters

        $result | Should -Be 'C:\Users\Example\Desktop\Programs.lnk'
        Should -Invoke -CommandName Show-LaunchTreeShortcutWizard `
            -ModuleName $script:moduleName -Times 1 -Exactly -ParameterFilter {
            $InitialPath -eq 'C:\Menus\Contoso\Programs' -and $null -ne $Theme.AccentColor
        }
    }

    It 'Should reject a non-STA host before opening the wizard (FR-035)' -Skip:(
        [Threading.Thread]::CurrentThread.GetApartmentState() -eq
            [Threading.ApartmentState]::STA
    ) {
        $parameters = @{
            ConfigurationPath = Join-Path -Path $TestDrive -ChildPath 'absent.json'
            Confirm           = $false
        }

        { New-LaunchTreeShortcut @parameters } | Should -Throw -ExpectedMessage '*STA*'
    }
}
