function Get-LaunchTreeReparseTag {
    [CmdletBinding()]
    [OutputType([uint32])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath
    )

    if (-not ('LaunchTree.ReparsePoint' -as [type])) {
        $source = @'
using System;
using System.Runtime.InteropServices;

namespace LaunchTree
{
    public static class ReparsePoint
    {
        private const int MaxPath = 260;
        private const uint FileAttributeReparsePoint = 0x400;
        private static readonly IntPtr InvalidHandle = new IntPtr(-1);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct FindData
        {
            public uint FileAttributes;
            public uint CreationTimeLow;
            public uint CreationTimeHigh;
            public uint LastAccessTimeLow;
            public uint LastAccessTimeHigh;
            public uint LastWriteTimeLow;
            public uint LastWriteTimeHigh;
            public uint FileSizeHigh;
            public uint FileSizeLow;
            public uint ReparseTag;
            public uint Reserved1;

            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = MaxPath)]
            public string FileName;

            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 14)]
            public string AlternateFileName;
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr FindFirstFileW(string fileName, out FindData findData);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool FindClose(IntPtr findHandle);

        // Queries the parent directory entry, so a DFS link reports its own tag
        // instead of the attributes behind the referral.
        public static uint GetTag(string path)
        {
            FindData findData;
            IntPtr findHandle = FindFirstFileW(path, out findData);
            if (findHandle == InvalidHandle)
            {
                return 0;
            }

            try
            {
                if ((findData.FileAttributes & FileAttributeReparsePoint) == 0)
                {
                    return 0;
                }

                return findData.ReparseTag;
            }
            finally
            {
                FindClose(findHandle);
            }
        }
    }
}
'@

        Add-Type -TypeDefinition $source -Language CSharp
    }

    [LaunchTree.ReparsePoint]::GetTag($LiteralPath)
}
