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

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
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
        [AllowEmptyString()]
        [string] $Description
    )

    $argumentParts = @(
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
        '-EntryId'
        (ConvertTo-LaunchTreeCommandLineArgument -Value $EntryId.ToString())
        '-ConfigurationPath'
        (ConvertTo-LaunchTreeCommandLineArgument -Value $ConfigurationPath)
    )

    $shell = $null
    $shortcut = $null
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($LiteralPath)
        $shortcut.TargetPath = $LauncherHostPath
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