BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-LaunchTreeLaunchItem' -Tag 'Unit' {
    Context 'When Windows Shell accepts the Launch Item' {
        BeforeEach {
            Mock -ModuleName $moduleName -CommandName Start-Process -MockWith {
                [PSCustomObject] @{ Id = 42 }
            }
        }

        It 'Should pass the .lnk file itself without reconstructed target values' {
            $linkPath = Join-Path -Path $TestDrive -ChildPath 'Editor.lnk'
            $null = New-Item -Path $linkPath -ItemType File

            $result = InModuleScope -ModuleName $moduleName -Parameters @{
                TestPath = $linkPath
            } {
                Invoke-LaunchTreeLaunchItem -LiteralPath $TestPath
            }

            $result.Succeeded | Should -BeTrue
            $result.LiteralPath | Should -Be $linkPath
            $assertion = @{
                ModuleName     = $moduleName
                CommandName    = 'Start-Process'
                Times          = 1
                Exactly        = $true
                ParameterFilter = {
                    $FilePath -eq $linkPath -and
                    -not $PSBoundParameters.ContainsKey('ArgumentList') -and
                    -not $PSBoundParameters.ContainsKey('WorkingDirectory')
                }
            }
            Should -Invoke @assertion
        }

        It 'Should pass the .url file itself to Windows Shell' {
            $urlPath = Join-Path -Path $TestDrive -ChildPath 'Portal.url'
            @('[InternetShortcut]', 'URL=https://example.test/') |
                Set-Content -LiteralPath $urlPath -Encoding ASCII

            $result = InModuleScope -ModuleName $moduleName -Parameters @{
                TestPath = $urlPath
            } {
                Invoke-LaunchTreeLaunchItem -LiteralPath $TestPath
            }

            $result.Succeeded | Should -BeTrue
            $assertion = @{
                ModuleName      = $moduleName
                CommandName     = 'Start-Process'
                Times           = 1
                Exactly         = $true
                ParameterFilter = { $FilePath -eq $urlPath }
            }
            Should -Invoke @assertion
        }

        It 'Should reject a URL changed to an unsupported scheme before invocation' {
            $urlPath = Join-Path -Path $TestDrive -ChildPath 'Changed.url'
            @('[InternetShortcut]', 'URL=file:///C:/Windows/notepad.exe') |
                Set-Content -LiteralPath $urlPath -Encoding ASCII

            {
                InModuleScope -ModuleName $moduleName -Parameters @{
                    TestPath = $urlPath
                } {
                    Invoke-LaunchTreeLaunchItem -LiteralPath $TestPath
                }
            } | Should -Throw -ExpectedMessage '*HTTP or HTTPS*'
            Should -Invoke -ModuleName $moduleName -CommandName Start-Process -Times 0
        }
    }

    Context 'When invocation cannot proceed' {
        It 'Should return a typed failure without closing caller state' {
            $linkPath = Join-Path -Path $TestDrive -ChildPath 'Broken.lnk'
            $null = New-Item -Path $linkPath -ItemType File
            Mock -ModuleName $moduleName -CommandName Start-Process -MockWith {
                throw [System.ComponentModel.Win32Exception]::new('Shell rejected the item.')
            }
            Mock -ModuleName $moduleName -CommandName Write-LaunchTreeEvent -MockWith {
                $true
            }
            $configuration = [PSCustomObject] @{
                Diagnostics = [PSCustomObject] @{
                    LogName = 'LaunchTree'
                    SourceName = 'LaunchTree'
                }
            }

            $result = InModuleScope -ModuleName $moduleName -Parameters @{
                TestPath          = $linkPath
                TestConfiguration = $configuration
            } {
                $parameters = @{
                    LiteralPath   = $TestPath
                    Configuration = $TestConfiguration
                }
                Invoke-LaunchTreeLaunchItem @parameters
            }

            $result.PSObject.TypeNames | Should -Contain 'LaunchTree.LaunchResult'
            $result.Succeeded | Should -BeFalse
            $result.Message | Should -Match 'Shell rejected'
            $assertion = @{
                ModuleName      = $moduleName
                CommandName     = 'Write-LaunchTreeEvent'
                Times           = 1
                Exactly         = $true
                ParameterFilter = { $EventId -eq 1201 }
            }
            Should -Invoke @assertion
        }

        It 'Should reject unsupported direct executable files' {
            $executablePath = Join-Path -Path $TestDrive -ChildPath 'NotAllowed.exe'
            $null = New-Item -Path $executablePath -ItemType File

            {
                InModuleScope -ModuleName $moduleName -Parameters @{
                    TestPath = $executablePath
                } {
                    Invoke-LaunchTreeLaunchItem -LiteralPath $TestPath
                }
            } | Should -Throw -ExpectedMessage '*unsupported*'
        }
    }
}