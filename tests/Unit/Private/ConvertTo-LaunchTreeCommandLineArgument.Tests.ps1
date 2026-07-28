BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertTo-LaunchTreeCommandLineArgument' -Tag 'Unit' {
    It 'Should wrap an ordinary value in quotes without changing it' {
        InModuleScope -ModuleName $moduleName {
            ConvertTo-LaunchTreeCommandLineArgument -Value 'C:\Program Files\App.ps1' |
                Should -Be '"C:\Program Files\App.ps1"'
        }
    }

    It 'Should double trailing backslashes before the closing quote' {
        InModuleScope -ModuleName $moduleName {
            ConvertTo-LaunchTreeCommandLineArgument -Value 'C:\App\' |
                Should -Be '"C:\App\\"'
        }
    }

    It 'Should not alter trailing plus signs' {
        InModuleScope -ModuleName $moduleName {
            ConvertTo-LaunchTreeCommandLineArgument -Value 'name+' |
                Should -Be '"name+"'
        }
    }

    It 'Should support an empty argument' {
        InModuleScope -ModuleName $moduleName {
            ConvertTo-LaunchTreeCommandLineArgument -Value '' |
                Should -Be '""'
        }
    }

    It 'Should reject embedded double quotes' {
        {
            InModuleScope -ModuleName $moduleName {
                ConvertTo-LaunchTreeCommandLineArgument -Value 'bad"value'
            }
        } | Should -Throw -ExpectedMessage '*double quote*'
    }
}