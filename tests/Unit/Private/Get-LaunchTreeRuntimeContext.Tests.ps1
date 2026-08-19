BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-LaunchTreeRuntimeContext' -Tag 'Unit' {
    It 'Should describe the installed module as a delivery that needs a Launcher Host' {
        $context = InModuleScope -ModuleName $moduleName {
            Get-LaunchTreeRuntimeContext
        }

        $context.HostKind | Should -Be 'Module'
        $context.LauncherIsExecutable | Should -BeFalse
        $context.LauncherPath | Should -BeLike '*Scripts\Start-LaunchTreeLauncher.ps1'
        $context.LauncherCommand | Should -BeNullOrEmpty
    }

    It 'Should describe a single-file script as a delivery that needs a Launcher Host' {
        $context = InModuleScope -ModuleName $moduleName {
            $script:LaunchTreeStandalonePath = 'C:\Tools\LaunchTree.ps1'
            $script:LaunchTreeStandaloneVersion = '9.9.9'
            try {
                Get-LaunchTreeRuntimeContext
            } finally {
                Remove-Variable -Name 'LaunchTreeStandalonePath' -Scope Script
                Remove-Variable -Name 'LaunchTreeStandaloneVersion' -Scope Script
            }
        }

        $context.HostKind | Should -Be 'Script'
        $context.LauncherIsExecutable | Should -BeFalse
        $context.RootPath | Should -Be 'C:\Tools'
        $context.Version | Should -Be '9.9.9'
        $context.LauncherCommand | Should -Be 'Show'
        $context.ProbeCommand | Should -Be 'EventLogProbe'
    }

    It 'Should describe a compiled executable as its own Launcher Host' {
        $context = InModuleScope -ModuleName $moduleName {
            $script:LaunchTreeStandalonePath = 'C:\Program Files\LaunchTree\LaunchTree.exe'
            $script:LaunchTreeStandaloneVersion = '9.9.9'
            try {
                Get-LaunchTreeRuntimeContext
            } finally {
                Remove-Variable -Name 'LaunchTreeStandalonePath' -Scope Script
                Remove-Variable -Name 'LaunchTreeStandaloneVersion' -Scope Script
            }
        }

        $context.HostKind | Should -Be 'Executable'
        $context.LauncherIsExecutable | Should -BeTrue
        $context.LauncherPath | Should -Be 'C:\Program Files\LaunchTree\LaunchTree.exe'
        $context.ProbePath | Should -Be 'C:\Program Files\LaunchTree\LaunchTree.exe'
        $context.RootPath | Should -Be 'C:\Program Files\LaunchTree'
    }
}
