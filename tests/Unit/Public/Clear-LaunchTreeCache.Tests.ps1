BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Clear-LaunchTreeCache' -Tag 'Unit' {
    BeforeEach {
        $script:cachePath = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString('N'))
        $null = New-Item -Path $script:cachePath -ItemType Directory -Force
        foreach ($name in @('a.png', 'b.png')) {
            $filePath = Join-Path -Path $script:cachePath -ChildPath $name
            [IO.File]::WriteAllBytes($filePath, [byte[]]::new(1024))
        }
    }

    It 'Should discard every cached icon and keep the namespace directory (FR-034)' {
        $result = Clear-LaunchTreeCache -CachePath $script:cachePath -Confirm:$false

        $result.Succeeded | Should -BeTrue
        $result.Path | Should -Be $script:cachePath
        $result.RemovedCount | Should -Be 2
        $result.ReclaimedBytes | Should -Be 2048
        $script:cachePath | Should -Exist
        @(Get-ChildItem -LiteralPath $script:cachePath -File) | Should -BeNullOrEmpty
    }

    It 'Should preserve every cached icon under WhatIf (FR-034)' {
        $result = Clear-LaunchTreeCache -CachePath $script:cachePath -WhatIf

        $result | Should -BeNullOrEmpty
        @(Get-ChildItem -LiteralPath $script:cachePath -Filter '*.png' -File).Count | Should -Be 2
    }

    It 'Should succeed with a zero count when the namespace does not exist (FR-034)' {
        $missingPath = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString('N'))

        $result = Clear-LaunchTreeCache -CachePath $missingPath -Confirm:$false

        $result.Succeeded | Should -BeTrue
        $result.RemovedCount | Should -Be 0
        $result.ReclaimedBytes | Should -Be 0
    }

    It 'Should clear the configured cache namespace when no path is supplied (FR-034)' {
        $configurationPath = Join-Path -Path $TestDrive -ChildPath 'LaunchTree.json'
        @{ SchemaVersion = 1 } | ConvertTo-Json | Set-Content -LiteralPath $configurationPath -Encoding UTF8
        $resolvedCachePath = $script:cachePath
        Mock -CommandName Get-LaunchTreeConfiguration -ModuleName $script:moduleName -MockWith {
            [PSCustomObject] @{
                ConfigurationPath = $configurationPath
                Cache             = [PSCustomObject] @{ Path = $resolvedCachePath }
            }
        }

        $result = Clear-LaunchTreeCache -ConfigurationPath $configurationPath -Confirm:$false

        $result.Path | Should -Be $script:cachePath
        $result.RemovedCount | Should -Be 2
        Should -Invoke -CommandName Get-LaunchTreeConfiguration -ModuleName $script:moduleName -Times 1 -Exactly
    }

    It 'Should leave content that is not a cached icon untouched (FR-034)' {
        $foreignPath = Join-Path -Path $script:cachePath -ChildPath 'notes.txt'
        Set-Content -LiteralPath $foreignPath -Value 'keep me' -Encoding UTF8

        $result = Clear-LaunchTreeCache -CachePath $script:cachePath -Confirm:$false

        $result.RemovedCount | Should -Be 2
        $foreignPath | Should -Exist
    }
}
