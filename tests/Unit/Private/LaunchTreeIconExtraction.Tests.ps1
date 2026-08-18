BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'LaunchTree icon extraction' -Tag 'Unit' {
    It 'Should resolve an internet shortcut icon instead of the generic file icon' {
        $shortcutPath = Join-Path $TestDrive 'Probe.url'
        $unknownPath = Join-Path $TestDrive 'Probe.zzlaunchtree'
        Set-Content -LiteralPath $shortcutPath -Encoding ascii -Value @(
            '[InternetShortcut]'
            'URL=https://example.com/'
        )
        Set-Content -LiteralPath $unknownPath -Encoding ascii -Value 'probe'

        $result = InModuleScope -ModuleName $moduleName -Parameters @{
            TestShortcut = $shortcutPath
            TestUnknown  = $unknownPath
        } {
            Initialize-LaunchTreeWpf

            function Get-ProbePixelHash {
                param([string] $Path)

                $task = [LaunchTree.NativeIcon]::GetAsync($Path, 64)
                if (-not $task.Wait(30000)) {
                    throw "Icon extraction timed out for '$Path'."
                }

                $image = $task.Result
                $stride = $image.PixelWidth * 4
                $buffer = [byte[]]::new($stride * $image.PixelHeight)
                $image.CopyPixels($buffer, $stride, 0)
                $algorithm = [Security.Cryptography.SHA256]::Create()
                try {
                    ([BitConverter]::ToString($algorithm.ComputeHash($buffer))).Replace('-', '')
                } finally {
                    $algorithm.Dispose()
                }
            }

            [PSCustomObject] @{
                ShortcutHash = Get-ProbePixelHash -Path $TestShortcut
                UnknownHash  = Get-ProbePixelHash -Path $TestUnknown
            }
        }

        <#
            The internet shortcut icon comes from a shell handler that only
            answers on an STA thread. On a thread-pool thread the shell falls
            back to the generic file icon, which is what the unknown extension
            resolves to.
        #>
        $result.ShortcutHash | Should -Not -Be $result.UnknownHash
    }
}
