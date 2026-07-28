function Initialize-LaunchTreeUnelevatedProcess {
    [CmdletBinding()]
    param()

    if ('LaunchTree.UnelevatedProcess' -as [type]) {
        return
    }

    $source = @'
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace LaunchTree
{
    public static class UnelevatedProcess
    {
        private const uint TokenQuery = 0x0008;
        private const int TokenLinkedToken = 19;
        private const int LogonWithProfile = 0x00000001;
        private const int CreateNoWindow = 0x08000000;
        private const uint WaitTimeout = 0x00000102;
        private const uint Infinite = 0xFFFFFFFF;

        [StructLayout(LayoutKind.Sequential)]
        private struct TokenLinkedTokenInformation
        {
            public IntPtr LinkedToken;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct StartupInfo
        {
            public int Size;
            public string Reserved;
            public string Desktop;
            public string Title;
            public int X;
            public int Y;
            public int XSize;
            public int YSize;
            public int XCountChars;
            public int YCountChars;
            public int FillAttribute;
            public int Flags;
            public short ShowWindow;
            public short Reserved2;
            public IntPtr ReservedPointer;
            public IntPtr StandardInput;
            public IntPtr StandardOutput;
            public IntPtr StandardError;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct ProcessInformation
        {
            public IntPtr Process;
            public IntPtr Thread;
            public int ProcessId;
            public int ThreadId;
        }

        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern bool OpenProcessToken(
            IntPtr processHandle,
            uint desiredAccess,
            out IntPtr tokenHandle);

        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern bool GetTokenInformation(
            IntPtr tokenHandle,
            int tokenInformationClass,
            out TokenLinkedTokenInformation tokenInformation,
            int tokenInformationLength,
            out int returnLength);

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CreateProcessWithTokenW(
            IntPtr tokenHandle,
            int logonFlags,
            string applicationName,
            StringBuilder commandLine,
            int creationFlags,
            IntPtr environment,
            string currentDirectory,
            ref StartupInfo startupInfo,
            out ProcessInformation processInformation);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetExitCodeProcess(IntPtr process, out uint exitCode);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool TerminateProcess(IntPtr process, uint exitCode);

        [DllImport("kernel32.dll")]
        private static extern bool CloseHandle(IntPtr handle);

        public static int Run(
            string applicationPath,
            string arguments,
            string workingDirectory,
            int timeoutMilliseconds)
        {
            IntPtr elevatedToken = IntPtr.Zero;
            IntPtr linkedToken = IntPtr.Zero;
            ProcessInformation processInformation = new ProcessInformation();
            try
            {
                if (!OpenProcessToken(Process.GetCurrentProcess().Handle, TokenQuery, out elevatedToken))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not open the elevated process token.");
                }

                TokenLinkedTokenInformation linkedInformation;
                int returnLength;
                if (!GetTokenInformation(
                    elevatedToken,
                    TokenLinkedToken,
                    out linkedInformation,
                    Marshal.SizeOf(typeof(TokenLinkedTokenInformation)),
                    out returnLength))
                {
                    throw new Win32Exception(
                        Marshal.GetLastWin32Error(),
                        "The elevated token has no linked standard-user token.");
                }
                linkedToken = linkedInformation.LinkedToken;

                StartupInfo startupInfo = new StartupInfo();
                startupInfo.Size = Marshal.SizeOf(typeof(StartupInfo));
                StringBuilder commandLine = new StringBuilder(
                    "\"" + applicationPath + "\" " + arguments);
                if (!CreateProcessWithTokenW(
                    linkedToken,
                    LogonWithProfile,
                    applicationPath,
                    commandLine,
                    CreateNoWindow,
                    IntPtr.Zero,
                    workingDirectory,
                    ref startupInfo,
                    out processInformation))
                {
                    throw new Win32Exception(
                        Marshal.GetLastWin32Error(),
                        "Could not start the standard-user probe process.");
                }

                uint waitResult = WaitForSingleObject(
                    processInformation.Process,
                    timeoutMilliseconds < 0 ? Infinite : (uint)timeoutMilliseconds);
                if (waitResult == WaitTimeout)
                {
                    TerminateProcess(processInformation.Process, 1460);
                    throw new TimeoutException("The standard-user probe timed out.");
                }

                uint exitCode;
                if (!GetExitCodeProcess(processInformation.Process, out exitCode))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not read the probe exit code.");
                }
                return unchecked((int)exitCode);
            }
            finally
            {
                if (processInformation.Thread != IntPtr.Zero) CloseHandle(processInformation.Thread);
                if (processInformation.Process != IntPtr.Zero) CloseHandle(processInformation.Process);
                if (linkedToken != IntPtr.Zero) CloseHandle(linkedToken);
                if (elevatedToken != IntPtr.Zero) CloseHandle(elevatedToken);
            }
        }
    }
}
'@

    Add-Type -TypeDefinition $source -Language CSharp
}