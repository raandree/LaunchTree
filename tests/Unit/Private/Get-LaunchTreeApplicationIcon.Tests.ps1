BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-LaunchTreeApplicationIcon' -Tag 'Unit' {
    It 'Should return a frozen frame closest to the requested pixel size' {
        $result = InModuleScope -ModuleName $moduleName {
            [PSCustomObject] @{
                Small   = Get-LaunchTreeApplicationIcon -PixelSize 16
                Default = Get-LaunchTreeApplicationIcon
                Large   = Get-LaunchTreeApplicationIcon -PixelSize 48
            }
        }

        $result.Small.PixelWidth | Should -Be 16
        $result.Default.PixelWidth | Should -Be 32
        $result.Large.PixelWidth | Should -Be 48
        $result.Default.IsFrozen | Should -BeTrue
    }

    It 'Should embed the same bytes as the committed icon asset' {
        $repositoryRoot = (Resolve-Path -LiteralPath (
                Join-Path -Path $PSScriptRoot -ChildPath '..\..\..'
            )).Path
        $functionPath = Join-Path -Path $repositoryRoot -ChildPath (
            'source\Private\Get-LaunchTreeApplicationIcon.ps1'
        )
        $assetPath = Join-Path -Path $repositoryRoot -ChildPath 'source\Assets\LaunchTree.ico'

        $functionText = Get-Content -LiteralPath $functionPath -Raw
        $encoded = [regex]::Match($functionText, "(?s)@'\r?\n(?<icon>.*?)\r?\n'@")

        $encoded.Success | Should -BeTrue -Because 'the icon is embedded in a here-string'

        $embedded = [byte[]] [Convert]::FromBase64String($encoded.Groups['icon'].Value)
        $asset = [byte[]] [IO.File]::ReadAllBytes($assetPath)

        $embedded.Length | Should -Be $asset.Length
        [Linq.Enumerable]::SequenceEqual($embedded, $asset) |
            Should -BeTrue -Because (
                'source\Assets\LaunchTree.ico is the source of truth for the embedded icon'
            )
    }
}
