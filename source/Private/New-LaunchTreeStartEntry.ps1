function New-LaunchTreeStartEntry {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Private staging helper; the public Reconciliation command owns ShouldProcess.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $LauncherHostPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $BootstrapPath,

        [Parameter(Mandatory)]
        [guid] $EntryId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $WorkingDirectory,

        [Parameter()]
        [AllowNull()]
        [string] $CommandName,

        [Parameter()]
        [switch] $LauncherIsExecutable,

        [Parameter()]
        [AllowEmptyString()]
        [string] $Description
    )

    if (-not $LauncherIsExecutable -and [string]::IsNullOrWhiteSpace($LauncherHostPath)) {
        throw [System.ArgumentException]::new(
            'A script bootstrap needs the path of its Launcher Host.',
            'LauncherHostPath'
        )
    }

    $argumentParts = [System.Collections.Generic.List[string]]::new()
    if (-not $LauncherIsExecutable) {
        foreach ($part in @(
                '-NoLogo'
                '-NoProfile'
                '-NonInteractive'
                '-WindowStyle'
                'Hidden'
                '-ExecutionPolicy'
                'Bypass'
                '-STA'
                '-File'
                (ConvertTo-LaunchTreeCommandLineArgument -Value $BootstrapPath)
            )) {
            [void] $argumentParts.Add($part)
        }
    }
    if ($CommandName) {
        [void] $argumentParts.Add('-Command')
        [void] $argumentParts.Add(
            (ConvertTo-LaunchTreeCommandLineArgument -Value $CommandName)
        )
    }
    foreach ($part in @(
            '-EntryId'
            (ConvertTo-LaunchTreeCommandLineArgument -Value $EntryId.ToString())
            '-ConfigurationPath'
            (ConvertTo-LaunchTreeCommandLineArgument -Value $ConfigurationPath)
        )) {
        [void] $argumentParts.Add($part)
    }

    $shell = $null
    $shortcut = $null
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($LiteralPath)
        $shortcut.TargetPath = if ($LauncherIsExecutable) { $BootstrapPath } else { $LauncherHostPath }
        $shortcut.Arguments = $argumentParts -join ' '
        $shortcut.WorkingDirectory = $WorkingDirectory
        $shortcut.Description = $Description
        $shortcut.IconLocation = "$env:SystemRoot\System32\imageres.dll,-3"
        $shortcut.WindowStyle = 7
        $shortcut.Save()
    } finally {
        if ($shortcut) {
            [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut)
        }
        if ($shell) {
            [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
        }
    }
}