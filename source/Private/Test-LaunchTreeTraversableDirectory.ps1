function Test-LaunchTreeTraversableDirectory {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [IO.DirectoryInfo] $Directory
    )

    if (($Directory.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
        return $true
    }

    # A junction, symbolic link, or mount point may leave the root or form a
    # cycle. A DFS link is how a namespace publishes content, and the file
    # server enforces the boundary behind the referral.
    # IO_REPARSE_TAG_DFS and IO_REPARSE_TAG_DFSR; the long suffix keeps the
    # literals from parsing as negative Int32 values.
    $dfsTags = [uint32[]] @(0x8000000Al, 0x80000012l)

    return $dfsTags -contains (Get-LaunchTreeReparseTag -LiteralPath $Directory.FullName)
}
