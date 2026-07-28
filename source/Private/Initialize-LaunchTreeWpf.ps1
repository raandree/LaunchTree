function Initialize-LaunchTreeWpf {
    [CmdletBinding()]
    param()

    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName WindowsBase

    if (('LaunchTree.ActivationServer' -as [type]) -and
        ('LaunchTree.NativeIcon' -as [type])) {
        return
    }

    $activationSource = @'
using System;
using System.Collections.Concurrent;
using System.IO;
using System.IO.Pipes;
__ACCESS_USING__
using System.Security.Principal;
using System.Threading;
using System.Threading.Tasks;

namespace LaunchTree
{
    public sealed class ActivationServer : IDisposable
    {
        private readonly string pipeName;
        private readonly BlockingCollection<string> messages = new BlockingCollection<string>();
        private readonly CancellationTokenSource cancellation = new CancellationTokenSource();
        private Task worker;

        public ActivationServer(string pipeName)
        {
            this.pipeName = pipeName;
        }

        public void Start()
        {
            if (worker == null)
            {
                worker = Task.Run(() => RunAsync());
            }
        }

    __LEGACY_SERVER_METHOD__

        private async Task RunAsync()
        {
            while (!cancellation.IsCancellationRequested)
            {
                try
                {
                    using (NamedPipeServerStream server = __SERVER_FACTORY__)
                    {
                        await server.WaitForConnectionAsync(cancellation.Token).ConfigureAwait(false);
                        using (StreamReader reader = new StreamReader(server))
                        {
                            string message = await reader.ReadLineAsync().ConfigureAwait(false);
                            if (message != null)
                            {
                                messages.Add(message, cancellation.Token);
                            }
                        }
                    }
                }
                catch (OperationCanceledException)
                {
                    return;
                }
                catch (ObjectDisposedException)
                {
                    return;
                }
            }
        }

        public string Take(int millisecondsTimeout)
        {
            string message;
            return messages.TryTake(out message, millisecondsTimeout) ? message : null;
        }

        public void Dispose()
        {
            cancellation.Cancel();
            messages.Dispose();
            cancellation.Dispose();
        }
    }

    public static class ActivationChannel
    {
        public static void Send(string pipeName, string message, int millisecondsTimeout)
        {
            using (NamedPipeClientStream client = new NamedPipeClientStream(
                ".",
                pipeName,
                PipeDirection.Out,
                PipeOptions.None,
                TokenImpersonationLevel.Identification))
            {
                client.Connect(millisecondsTimeout);
                using (StreamWriter writer = new StreamWriter(client))
                {
                    writer.AutoFlush = true;
                    writer.WriteLine(message);
                }
            }
        }
    }
}
'@

    $supportsCurrentUserOnly = [Enum]::GetNames([IO.Pipes.PipeOptions]) -contains (
        'CurrentUserOnly'
    )
    if ($supportsCurrentUserOnly) {
        $accessUsing = ''
        $legacyServerMethod = ''
        $serverFactory = @'
new NamedPipeServerStream(
                        pipeName,
                        PipeDirection.In,
                        1,
                        PipeTransmissionMode.Byte,
                        PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly)
'@
    } else {
        $accessUsing = 'using System.Security.AccessControl;'
        $serverFactory = 'CreateCurrentUserServer(pipeName)'
        $legacyServerMethod = @'
        private static NamedPipeServerStream CreateCurrentUserServer(string pipeName)
        {
            SecurityIdentifier currentUser = WindowsIdentity.GetCurrent().User;
            PipeSecurity security = new PipeSecurity();
            security.SetOwner(currentUser);
            security.AddAccessRule(new PipeAccessRule(
                currentUser,
                PipeAccessRights.FullControl,
                AccessControlType.Allow));
            return new NamedPipeServerStream(
                pipeName,
                PipeDirection.In,
                1,
                PipeTransmissionMode.Byte,
                PipeOptions.Asynchronous,
                0,
                0,
                security);
        }
'@
    }
    $activationSource = $activationSource.Replace('__ACCESS_USING__', $accessUsing)
    $activationSource = $activationSource.Replace('__LEGACY_SERVER_METHOD__', $legacyServerMethod)
    $activationSource = $activationSource.Replace('__SERVER_FACTORY__', $serverFactory)

    if (-not ('LaunchTree.ActivationServer' -as [type])) {
        Add-Type -TypeDefinition $activationSource -Language CSharp
    }

    $iconSource = @'
using System;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media.Imaging;

namespace LaunchTree
{

    [StructLayout(LayoutKind.Sequential)]
    internal struct NativeSize
    {
        public int Width;
        public int Height;
    }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("bcc18b79-ba16-442f-80c4-8a59c30c463b")]
    internal interface IShellItemImageFactory
    {
        void GetImage(NativeSize size, uint flags, out IntPtr bitmapHandle);
    }

    public static class NativeIcon
    {
        [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
        private static extern void SHCreateItemFromParsingName(
            string path,
            IntPtr bindContext,
            ref Guid interfaceId,
            [MarshalAs(UnmanagedType.Interface)] out IShellItemImageFactory imageFactory);

        [DllImport("gdi32.dll")]
        private static extern bool DeleteObject(IntPtr objectHandle);

        public static Task<BitmapSource> GetAsync(string path, int pixelSize)
        {
            return Task.Run(() => Get(path, pixelSize));
        }

        public static BitmapSource Get(string path, int pixelSize)
        {
            IShellItemImageFactory imageFactory = null;
            IntPtr bitmapHandle = IntPtr.Zero;
            try
            {
                Guid interfaceId = typeof(IShellItemImageFactory).GUID;
                SHCreateItemFromParsingName(path, IntPtr.Zero, ref interfaceId, out imageFactory);
                NativeSize size = new NativeSize { Width = pixelSize, Height = pixelSize };
                const uint BiggerSizeOk = 0x1;
                const uint IconOnly = 0x4;
                imageFactory.GetImage(size, BiggerSizeOk | IconOnly, out bitmapHandle);
                BitmapSource source = Imaging.CreateBitmapSourceFromHBitmap(
                    bitmapHandle,
                    IntPtr.Zero,
                    Int32Rect.Empty,
                    BitmapSizeOptions.FromWidthAndHeight(pixelSize, pixelSize));
                source.Freeze();
                return source;
            }
            finally
            {
                if (bitmapHandle != IntPtr.Zero)
                {
                    DeleteObject(bitmapHandle);
                }
                if (imageFactory != null)
                {
                    Marshal.FinalReleaseComObject(imageFactory);
                }
            }
        }
    }
}
'@

    if (-not ('LaunchTree.NativeIcon' -as [type])) {
        $references = @(
            [System.Windows.Media.Imaging.BitmapSource].Assembly.Location
            [System.Windows.Window].Assembly.Location
            [System.Windows.Rect].Assembly.Location
        )
        Add-Type -TypeDefinition $iconSource -ReferencedAssemblies $references -Language CSharp
    }
}