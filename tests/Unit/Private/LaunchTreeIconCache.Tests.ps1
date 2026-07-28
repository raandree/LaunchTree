BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'LaunchTree icon cache' -Tag 'Unit' {
    It 'Should save and reload a frozen PNG icon from a stable cache key' {
        $sourcePath = Join-Path $TestDrive 'Item.lnk'
        $cacheRoot = Join-Path $TestDrive 'Cache'
        $null = New-Item -Path $sourcePath -ItemType File

        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            TestSource = $sourcePath
            TestCache  = $cacheRoot
        } {
            Initialize-LaunchTreeWpf
            $cacheParameters = @{
                CachePath  = $TestCache
                SourcePath = $TestSource
                PixelSize  = 64
            }
            $cachePath = Get-LaunchTreeIconCachePath @cacheParameters
            $bitmap = [System.Windows.Media.Imaging.WriteableBitmap]::new(
                2,
                2,
                96,
                96,
                [System.Windows.Media.PixelFormats]::Bgra32,
                $null
            )
            Save-LaunchTreeCachedIcon -Image $bitmap -LiteralPath $cachePath
            $loaded = Get-LaunchTreeCachedIcon -LiteralPath $cachePath

            [PSCustomObject] @{
                Path      = $cachePath
                IsFrozen  = $loaded.IsFrozen
                PixelWidth = $loaded.PixelWidth
            }
        }

        $result.Path | Should -Exist
        $result.IsFrozen | Should -BeTrue
        $result.PixelWidth | Should -Be 2
    }

    It 'Should remove expired and least-recently-used files above the size cap' {
        $cacheRoot = Join-Path $TestDrive 'TrimCache'
        $null = New-Item -Path $cacheRoot -ItemType Directory
        $oldPath = Join-Path $cacheRoot 'old.png'
        $recentA = Join-Path $cacheRoot 'recent-a.png'
        $recentB = Join-Path $cacheRoot 'recent-b.png'
        [IO.File]::WriteAllBytes($oldPath, [byte[]]::new(600000))
        [IO.File]::WriteAllBytes($recentA, [byte[]]::new(600000))
        [IO.File]::WriteAllBytes($recentB, [byte[]]::new(600000))
        [IO.File]::SetLastAccessTimeUtc($oldPath, [DateTime]::UtcNow.AddDays(-40))
        [IO.File]::SetLastWriteTimeUtc($oldPath, [DateTime]::UtcNow.AddDays(-40))
        [IO.File]::SetLastAccessTimeUtc($recentA, [DateTime]::UtcNow.AddMinutes(-10))
        [IO.File]::SetLastAccessTimeUtc($recentB, [DateTime]::UtcNow)

        InModuleScope -ModuleName $moduleName -Parameters @{
            TestCache = $cacheRoot
        } {
            $trimParameters = @{
                CachePath      = $TestCache
                MaximumSizeMB  = 1
                MaximumAgeDays = 30
            }
            Remove-LaunchTreeExpiredIconCache @trimParameters
        }

        $oldPath | Should -Not -Exist
        $recentA | Should -Not -Exist
        $recentB | Should -Exist
    }
}