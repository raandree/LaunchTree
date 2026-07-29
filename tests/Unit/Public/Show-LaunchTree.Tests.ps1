BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Show-LaunchTree' -Tag 'Unit' {
    It 'Should expose separate Entry ID and Entry Root name parameter sets' {
        $command = Get-Command -Name Show-LaunchTree -Module $moduleName
        $parameterSets = $command.ParameterSets | Select-Object -ExpandProperty Name

        $parameterSets | Should -Contain 'ByEntryId'
        $parameterSets | Should -Contain 'ByEntryName'
        ($command.ParameterSets | Where-Object Name -eq 'ByEntryId').Parameters.Name |
            Should -Contain 'EntryId'
        ($command.ParameterSets | Where-Object Name -eq 'ByEntryName').Parameters.Name |
            Should -Contain 'EntryName'
    }

    It 'Should accept CR-013 root overrides in every parameter set' {
        $command = Get-Command -Name Show-LaunchTree -Module $moduleName

        foreach ($parameterSet in $command.ParameterSets) {
            $parameterSet.Parameters.Name | Should -Contain 'ManagedRoot'
            $parameterSet.Parameters.Name | Should -Contain 'PersonalRoot'
        }
    }

    It 'Should reject a non-STA host before reading content' -Skip:(
        [Threading.Thread]::CurrentThread.GetApartmentState() -eq
            [Threading.ApartmentState]::STA
    ) {
        { Show-LaunchTree -EntryName 'Example' } |
            Should -Throw -ExpectedMessage '*STA*'
    }

    It 'Should render a visible error for an unsupported schema' {
        $configurationPath = Join-Path $TestDrive 'future.json'
        $capturePath = Join-Path $TestDrive 'future-error.png'
        @{ SchemaVersion = 2 } |
            ConvertTo-Json |
            Set-Content -LiteralPath $configurationPath -Encoding UTF8

        $parameters = @{
            EntryName         = 'Example'
            ConfigurationPath = $configurationPath
            CapturePath       = $capturePath
        }
        { Show-LaunchTree @parameters } | Should -Not -Throw
        $capturePath | Should -Exist
        (Get-Item $capturePath).Length | Should -BeGreaterThan 1000
    }
}