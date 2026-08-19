function New-LaunchTreeLauncherShortcut {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath,

        [Parameter(Mandatory)]
        [PSTypeName('LaunchTree.ShortcutDefinition')]
        $Definition,

        [Parameter()]
        [AllowEmptyString()]
        [string] $Description
    )

    if (-not $PSCmdlet.ShouldProcess($LiteralPath, 'Create LaunchTree shortcut')) {
        return
    }

    $shortcutDirectory = Split-Path -Path $LiteralPath -Parent
    if ($shortcutDirectory -and -not (Test-Path -LiteralPath $shortcutDirectory -PathType Container)) {
        $null = New-Item -Path $shortcutDirectory -ItemType Directory -Force
    }

    $shell = $null
    $shortcut = $null
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($LiteralPath)
        $shortcut.TargetPath = $Definition.TargetPath
        $shortcut.Arguments = $Definition.Arguments
        $shortcut.WorkingDirectory = $Definition.WorkingDirectory
        $shortcut.Description = if ($PSBoundParameters.ContainsKey('Description')) {
            $Description
        } else {
            "Open the $($Definition.EntryName) Entry Root in LaunchTree."
        }
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

    $LiteralPath
}
