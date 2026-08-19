function New-LaunchTreeShortcut {
    <#
        .SYNOPSIS
            Opens the wizard that writes a Windows shortcut to an Entry Root.

        .DESCRIPTION
            Opens a three-step wizard that creates a plain Windows shortcut
            which opens one Entry Root in the Launcher. The wizard derives the
            Managed Root from the parent of the entered folder and the Entry
            Root name from its last segment, asks whether the Launcher closes
            after a Launch Item starts, and shows the resulting command line
            before it writes anything. The created shortcut is user-owned: it
            is not Generated State, so Reconciliation and removal neither
            create nor delete it. The command returns the path of the created
            shortcut and returns nothing when the wizard is cancelled.

        .PARAMETER ConfigurationPath
            Specifies the machine configuration JSON file used to resolve the
            Launcher Host that the shortcut starts.

        .PARAMETER EntryRootPath
            Specifies the Entry Root folder the wizard starts with. The user
            can still change it in the first step.

        .EXAMPLE
            New-LaunchTreeShortcut

            Opens the wizard with an empty Entry Root folder.

        .EXAMPLE
            New-LaunchTreeShortcut -EntryRootPath '\\contoso.com\Data\Files\programs'

            Opens the wizard with the Entry Root folder already filled in.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([string])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $EntryRootPath
    )

    $configurationParameters = @{}
    if ($PSBoundParameters.ContainsKey('ConfigurationPath')) {
        $configurationParameters.ConfigurationPath = $ConfigurationPath
    }
    $configuration = Get-LaunchTreeConfiguration @configurationParameters

    if (-not $PSCmdlet.ShouldProcess('an Entry Root shortcut', 'Create')) {
        return
    }

    if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne
        [Threading.ApartmentState]::STA) {
        throw [System.Threading.ThreadStateException]::new(
            'New-LaunchTreeShortcut requires an STA PowerShell host.'
        )
    }

    Initialize-LaunchTreeWpf

    $wizardParameters = @{
        Configuration = $configuration
        Theme         = Get-LaunchTreeTheme
    }
    if ($PSBoundParameters.ContainsKey('EntryRootPath')) {
        $wizardParameters.InitialPath = $EntryRootPath
    }

    Show-LaunchTreeShortcutWizard @wizardParameters
}
