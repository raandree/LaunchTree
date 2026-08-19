BeforeAll {
    $script:moduleName = 'LaunchTree'
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-LaunchTreeConfiguration' -Tag 'Unit' {
    BeforeEach {
        $script:originalEnvironment = @{
            APPDATA      = $env:APPDATA
            LOCALAPPDATA = $env:LOCALAPPDATA
            ProgramData  = $env:ProgramData
        }

        $env:APPDATA = Join-Path -Path $TestDrive -ChildPath 'AppData'
        $env:LOCALAPPDATA = Join-Path -Path $TestDrive -ChildPath 'LocalAppData'
        $env:ProgramData = Join-Path -Path $TestDrive -ChildPath 'ProgramData'
    }

    AfterEach {
        $env:APPDATA = $script:originalEnvironment.APPDATA
        $env:LOCALAPPDATA = $script:originalEnvironment.LOCALAPPDATA
        $env:ProgramData = $script:originalEnvironment.ProgramData
    }

    Context 'When no configuration files exist' {
        It 'Should return CR-001 through CR-005 defaults without creating files' {
            $configurationPath = Join-Path -Path $TestDrive -ChildPath 'machine.json'
            $preferencePath = Join-Path -Path $TestDrive -ChildPath 'preferences.json'
            $parameters = @{
                ConfigurationPath = $configurationPath
                PreferencePath    = $preferencePath
            }

            $result = Get-LaunchTreeConfiguration @parameters

            $result.PSObject.TypeNames | Should -Contain 'LaunchTree.Configuration'
            $result.SchemaVersion | Should -Be 1
            $result.VendorName | Should -Be 'LaunchTree'
            $result.ManagedRoot | Should -Be (
                Join-Path $env:ProgramData 'LaunchTree\LaunchTree'
            )
            $result.PersonalRoot | Should -Be (
                Join-Path $env:APPDATA 'LaunchTree\LaunchTree'
            )
            $result.MaximumDepth | Should -Be 5
            $result.LauncherHost | Should -Be 'WindowsPowerShell'
            $result.LauncherLayout | Should -Be 'TabbedList'
            $result.SortOrder | Should -Be 'NameAscending'
            $result.CloseAfterLaunch | Should -BeFalse
            $result.Cache.MaximumSizeMB | Should -Be 64
            $result.Cache.MaximumAgeDays | Should -Be 30
            $result.HealthFindings | Should -BeNullOrEmpty
            $configurationPath | Should -Not -Exist
            $preferencePath | Should -Not -Exist
        }
    }

    Context 'When machine configuration and user preferences are valid' {
        It 'Should combine machine settings with allowed user preferences' {
            $configurationPath = Join-Path -Path $TestDrive -ChildPath 'machine.json'
            $preferencePath = Join-Path -Path $TestDrive -ChildPath 'preferences.json'
            @{
                SchemaVersion   = 1
                VendorName      = 'Contoso'
                ManagedRoot     = (Join-Path $TestDrive 'Managed')
                PersonalRoot    = (Join-Path $TestDrive 'Personal')
                MaximumDepth    = 9
                LauncherHost    = 'PowerShell7'
                LauncherLayout  = 'Grid'
                DefaultSortOrder = 'NameAscending'
                CloseAfterLaunch = $true
                Cache           = @{
                    MaximumSizeMB  = 96
                    MaximumAgeDays = 14
                }
                Diagnostics     = @{
                    LogName             = 'ContosoStartMenu'
                    SourceName          = 'ContosoStartMenu'
                    MaximumLogSizeMB    = 32
                    TargetRetentionDays = 21
                }
            } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configurationPath -Encoding UTF8
            @{
                SchemaVersion   = 1
                SortOrder       = 'NameDescending'
                CloseAfterLaunch = $false
                Window          = @{
                    Width  = 840
                    Height = 680
                    Left   = 20
                    Top    = 30
                }
            } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $preferencePath -Encoding UTF8

            $parameters = @{
                ConfigurationPath = $configurationPath
                PreferencePath    = $preferencePath
            }

            $result = Get-LaunchTreeConfiguration @parameters

            $result.VendorName | Should -Be 'Contoso'
            $result.MaximumDepth | Should -Be 9
            $result.LauncherHost | Should -Be 'PowerShell7'
            $result.LauncherLayout | Should -Be 'Grid'
            $result.SortOrder | Should -Be 'NameDescending'
            $result.CloseAfterLaunch | Should -BeFalse
            $result.Window.Width | Should -Be 840
            $result.Window.Height | Should -Be 680
            $result.Cache.MaximumSizeMB | Should -Be 96
            $result.Cache.MaximumAgeDays | Should -Be 14
            $result.Diagnostics.LogName | Should -Be 'ContosoStartMenu'
            $result.Diagnostics.SourceName | Should -Be 'ContosoStartMenu'
            $result.Diagnostics.MaximumLogSizeMB | Should -Be 32
            $result.Diagnostics.TargetRetentionDays | Should -Be 21
            $result.HealthFindings | Should -BeNullOrEmpty
        }
    }

    Context 'When configuration is malformed or unsupported' {
        It 'Should use defaults and return a warning for malformed JSON' {
            $configurationPath = Join-Path -Path $TestDrive -ChildPath 'machine.json'
            '{ not-json' | Set-Content -LiteralPath $configurationPath -Encoding UTF8
            Mock -ModuleName $moduleName -CommandName Write-LaunchTreeEvent -MockWith {
                $true
            }

            $result = Get-LaunchTreeConfiguration -ConfigurationPath $configurationPath

            $result.VendorName | Should -Be 'LaunchTree'
            $result.HealthFindings | Should -HaveCount 1
            $result.HealthFindings[0].Code | Should -Be 'ConfigurationInvalidJson'
            $assertion = @{
                ModuleName      = $moduleName
                CommandName     = 'Write-LaunchTreeEvent'
                Times           = 1
                Exactly         = $true
                ParameterFilter = { $EventId -eq 1001 }
            }
            Should -Invoke @assertion
        }

        It 'Should return an invalid typed result for an unsupported future schema' {
            $configurationPath = Join-Path -Path $TestDrive -ChildPath 'machine.json'
            $preferencePath = Join-Path -Path $TestDrive -ChildPath 'preferences.json'
            @{ SchemaVersion = 2 } |
                ConvertTo-Json |
                Set-Content -LiteralPath $configurationPath -Encoding UTF8

            $parameters = @{
                ConfigurationPath = $configurationPath
                PreferencePath    = $preferencePath
            }

            $result = Get-LaunchTreeConfiguration @parameters

            $result.IsValid | Should -BeFalse
            $result.HealthFindings.Code | Should -Contain 'ConfigurationSchemaUnsupported'
            $result.HealthFindings.Severity | Should -Contain 'Error'
            $preferencePath | Should -Not -Exist
        }

        It 'Should report invalid cache and diagnostic values while retaining defaults' {
            $configurationPath = Join-Path -Path $TestDrive -ChildPath 'machine.json'
            @{
                SchemaVersion = 1
                Cache = @{
                    MaximumSizeMB  = 2
                    MaximumAgeDays = 500
                }
                Diagnostics = @{
                    LogName             = ''
                    SourceName          = ''
                    MaximumLogSizeMB    = 0
                    TargetRetentionDays = 500
                }
            } | ConvertTo-Json -Depth 5 |
                Set-Content -LiteralPath $configurationPath -Encoding UTF8

            $result = Get-LaunchTreeConfiguration -ConfigurationPath $configurationPath

            $result.Cache.MaximumSizeMB | Should -Be 64
            $result.Cache.MaximumAgeDays | Should -Be 30
            $result.Diagnostics.LogName | Should -Be 'LaunchTree'
            $result.Diagnostics.SourceName | Should -Be 'LaunchTree'
            $result.HealthFindings.Code | Should -Contain 'CacheMaximumSizeInvalid'
            $result.HealthFindings.Code | Should -Contain 'CacheMaximumAgeInvalid'
            $result.HealthFindings.Code | Should -Contain 'DiagnosticsLogNameInvalid'
            $result.HealthFindings.Code | Should -Contain 'DiagnosticsSourceNameInvalid'
            $result.HealthFindings.Code | Should -Contain 'DiagnosticsMaximumLogSizeInvalid'
            $result.HealthFindings.Code | Should -Contain 'DiagnosticsRetentionInvalid'
        }

        It 'Should retain the CR-005 default for an invalid Launcher layout' {
            $configurationPath = Join-Path -Path $TestDrive -ChildPath 'machine.json'
            @{
                SchemaVersion  = 1
                LauncherLayout = 'Cards'
            } | ConvertTo-Json |
                Set-Content -LiteralPath $configurationPath -Encoding UTF8

            $result = Get-LaunchTreeConfiguration -ConfigurationPath $configurationPath

            $result.LauncherLayout | Should -Be 'TabbedList'
            $result.HealthFindings.Code | Should -Contain 'LauncherLayoutInvalid'
        }
    }

    Context 'When root overrides are supplied as parameters' {
        It 'Should apply CR-013 precedence over machine configuration roots' {
            $configurationPath = Join-Path -Path $TestDrive -ChildPath 'machine.json'
            $overrideManagedRoot = Join-Path -Path $TestDrive -ChildPath 'OverrideManaged'
            $overridePersonalRoot = Join-Path -Path $TestDrive -ChildPath 'OverridePersonal'
            @{
                SchemaVersion = 1
                ManagedRoot   = (Join-Path $TestDrive 'FileManaged')
                PersonalRoot  = (Join-Path $TestDrive 'FilePersonal')
            } | ConvertTo-Json |
                Set-Content -LiteralPath $configurationPath -Encoding UTF8

            $parameters = @{
                ConfigurationPath = $configurationPath
                ManagedRoot       = $overrideManagedRoot
                PersonalRoot      = $overridePersonalRoot
            }

            $result = Get-LaunchTreeConfiguration @parameters

            $result.ManagedRoot | Should -Be $overrideManagedRoot
            $result.PersonalRoot | Should -Be $overridePersonalRoot
            $result.HealthFindings | Should -BeNullOrEmpty
        }

        It 'Should expand environment variables in an overridden root' {
            $result = Get-LaunchTreeConfiguration -ManagedRoot '%ProgramData%\Contoso\Menu'

            $result.ManagedRoot | Should -Be (Join-Path $env:ProgramData 'Contoso\Menu')
        }

        It 'Should reject a relative root override instead of falling back' {
            { Get-LaunchTreeConfiguration -ManagedRoot 'Relative\Menu' } |
                Should -Throw -ExpectedMessage '*absolute path*'
        }
    }

    Context 'When the close-after-launch override is supplied as a parameter' {
        It 'Should take precedence over the machine configuration and preferences' {
            $configurationPath = Join-Path -Path $TestDrive -ChildPath 'close-machine.json'
            $preferencePath = Join-Path -Path $TestDrive -ChildPath 'close-preferences.json'
            @{
                SchemaVersion    = 1
                CloseAfterLaunch = $false
            } | ConvertTo-Json | Set-Content -LiteralPath $configurationPath -Encoding UTF8
            @{
                SchemaVersion    = 1
                CloseAfterLaunch = $false
            } | ConvertTo-Json | Set-Content -LiteralPath $preferencePath -Encoding UTF8

            $parameters = @{
                ConfigurationPath = $configurationPath
                PreferencePath    = $preferencePath
                CloseAfterLaunch  = $true
            }

            $result = Get-LaunchTreeConfiguration @parameters

            $result.CloseAfterLaunch | Should -BeTrue
        }

        It 'Should leave the resolved value untouched when the override is absent' {
            $configurationPath = Join-Path -Path $TestDrive -ChildPath 'close-only.json'
            @{
                SchemaVersion    = 1
                CloseAfterLaunch = $true
            } | ConvertTo-Json | Set-Content -LiteralPath $configurationPath -Encoding UTF8

            $parameters = @{
                ConfigurationPath = $configurationPath
                PreferencePath    = Join-Path -Path $TestDrive -ChildPath 'absent.json'
            }

            $result = Get-LaunchTreeConfiguration @parameters

            $result.CloseAfterLaunch | Should -BeTrue
        }
    }
}