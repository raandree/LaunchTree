function Get-StartMenuFolderLauncherHostPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('WindowsPowerShell', 'PowerShell7')]
        [string] $LauncherHost
    )

    if ($LauncherHost -eq 'WindowsPowerShell') {
        $windowsDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
        $hostPath = Join-Path -Path $windowsDirectory -ChildPath (
            'System32\WindowsPowerShell\v1.0\powershell.exe'
        )
    } else {
        $hostCommand = Get-Command -Name 'pwsh.exe' -CommandType Application -ErrorAction Stop |
            Select-Object -First 1
        $hostPath = $hostCommand.Source
    }

    if (-not (Test-Path -LiteralPath $hostPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new(
            "The configured Launcher Host '$LauncherHost' was not found.",
            $hostPath
        )
    }

    (Resolve-Path -LiteralPath $hostPath).Path
}