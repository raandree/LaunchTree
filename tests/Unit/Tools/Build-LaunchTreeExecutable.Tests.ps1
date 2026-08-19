$script:isWindowsHost = $PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows

BeforeAll {
    $script:repositoryRoot = "$PSScriptRoot\..\..\.." | Convert-Path
    $script:generatorPath = Join-Path -Path $script:repositoryRoot `
        -ChildPath 'tools\Build-LaunchTreeExecutable.ps1'
    $script:bootstrapPath = Join-Path -Path $script:repositoryRoot `
        -ChildPath 'tools\StandaloneHost\Invoke-LaunchTreeEmbeddedScript.ps1'

    # Dot-sourcing runs the bootstrap, so give it a script that does nothing measurable.
    $LaunchTreeEmbeddedScript = 'param([string] $Ignored)'
    $LaunchTreeArgument = @()
    . $script:bootstrapPath
}

Describe 'Invoke-LaunchTreeEmbeddedScript' -Tag 'Unit' {
    BeforeAll {
        $script:parameterScript = @'
param(
    [Parameter(Position = 0)]
    [string] $Command,

    [Parameter()]
    [int[]] $EventId,

    [Parameter()]
    [switch] $Force
)
'@
    }

    It 'Should bind a named parameter to its value' {
        $binding = ConvertTo-LaunchTreeParameterBinding -Script $script:parameterScript `
            -Argument @('-Command', 'Show')

        $binding.Named['Command'] | Should -Be 'Show'
        $binding.Positional | Should -BeNullOrEmpty
    }

    It 'Should bind a switch that carries no value' {
        $binding = ConvertTo-LaunchTreeParameterBinding -Script $script:parameterScript `
            -Argument @('-Force')

        $binding.Named['Force'] | Should -BeTrue
    }

    It 'Should honour an explicitly disabled switch' {
        $binding = ConvertTo-LaunchTreeParameterBinding -Script $script:parameterScript `
            -Argument @('-Force:$false')

        $binding.Named['Force'] | Should -BeFalse
    }

    It 'Should split a list value that argv delivers as one token' {
        $binding = ConvertTo-LaunchTreeParameterBinding -Script $script:parameterScript `
            -Argument @('-EventId', '1,2,3')

        $binding.Named['EventId'] | Should -Be @('1', '2', '3')
    }

    It 'Should accept the common parameters CmdletBinding adds' {
        $binding = ConvertTo-LaunchTreeParameterBinding -Script $script:parameterScript `
            -Argument @('-Verbose', '-ErrorAction', 'Stop')

        $binding.Named['Verbose'] | Should -BeTrue
        $binding.Named['ErrorAction'] | Should -Be 'Stop'
    }

    It 'Should keep an argument that names no parameter positional' {
        $binding = ConvertTo-LaunchTreeParameterBinding -Script $script:parameterScript `
            -Argument @('Show')

        $binding.Positional | Should -Be @('Show')
    }

    It 'Should reject a parameter the embedded script does not declare' {
        {
            ConvertTo-LaunchTreeParameterBinding -Script $script:parameterScript `
                -Argument @('-Nonexistent', 'value')
        } | Should -Throw -ExpectedMessage "*'-Nonexistent' is not a parameter*"
    }

    It 'Should reject a parameter that is missing its value' {
        {
            ConvertTo-LaunchTreeParameterBinding -Script $script:parameterScript `
                -Argument @('-Command')
        } | Should -Throw -ExpectedMessage "*'-Command' expects a value*"
    }
}

Describe 'Build-LaunchTreeExecutable' -Tag 'Unit' -Skip:(-not $script:isWindowsHost) {
    BeforeAll {
        $script:sampleScriptPath = Join-Path -Path $TestDrive -ChildPath 'Sample.ps1'
        $sampleScript = @'
[CmdletBinding()]
param(
    [Parameter()]
    [string] $Message = 'default',

    [Parameter()]
    [switch] $Fail
)

if ($Fail) {
    exit 42
}

"message=$Message"
'@
        [IO.File]::WriteAllText(
            $script:sampleScriptPath, $sampleScript, [Text.UTF8Encoding]::new($false)
        )

        $script:executablePath = Join-Path -Path $TestDrive -ChildPath 'Sample.exe'
        $script:result = & $script:generatorPath -ScriptPath $script:sampleScriptPath `
            -OutputPath $script:executablePath -Version '9.9.9-preview0001'
    }

    It 'Should compile a console executable that reports the requested version' {
        $script:result.Path | Should -Exist
        $script:result.Subsystem | Should -Be 'exe'
        $script:result.AssemblyVersion | Should -Be '9.9.9.0'

        $versionInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo($script:executablePath)
        $versionInfo.ProductName | Should -Be 'LaunchTree'
        $versionInfo.FileVersion | Should -Be '9.9.9.0'
    }

    It 'Should run the embedded script with the command line it was started with' {
        $output = & $script:executablePath -Message 'bound'

        $LASTEXITCODE | Should -Be 0
        $output | Should -Contain 'message=bound'
    }

    It 'Should return the exit code the embedded script asks for' {
        $null = & $script:executablePath -Fail

        $LASTEXITCODE | Should -Be 42
    }

    It 'Should compile a windows subsystem executable for the Minimal variant' {
        $minimalPath = Join-Path -Path $TestDrive -ChildPath 'SampleMinimal.exe'
        $minimalResult = & $script:generatorPath -ScriptPath $script:sampleScriptPath `
            -OutputPath $minimalPath -Version '9.9.9' -Variant Minimal

        $minimalResult.Subsystem | Should -Be 'winexe'
        $minimalPath | Should -Exist
    }
}
