function Initialize-LaunchTreeWpf {
    [CmdletBinding()]
    param()

    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName WindowsBase

    if (('LaunchTree.ActivationServer' -as [type]) -and
        ('LaunchTree.NativeIcon' -as [type]) -and
        ('LaunchTree.NativeWindow' -as [type])) {
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
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace LaunchTree
{

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    internal struct PropertyKey
    {
        public Guid FormatId;
        public uint PropertyId;

        public PropertyKey(Guid formatId, uint propertyId)
        {
            FormatId = formatId;
            PropertyId = propertyId;
        }
    }

    [StructLayout(LayoutKind.Explicit)]
    internal struct PropVariant : IDisposable
    {
        [FieldOffset(0)]
        private ushort valueType;

        [FieldOffset(8)]
        private IntPtr pointerValue;

        [DllImport("ole32.dll")]
        private static extern int PropVariantClear(ref PropVariant value);

        public static PropVariant FromString(string value)
        {
            PropVariant result = new PropVariant();
            result.valueType = 31;
            result.pointerValue = Marshal.StringToCoTaskMemUni(value);
            return result;
        }

        public void Dispose()
        {
            PropVariantClear(ref this);
        }
    }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99")]
    internal interface IPropertyStore
    {
        uint GetCount();
        PropertyKey GetAt(uint propertyIndex);
        void GetValue(ref PropertyKey key, out PropVariant value);
        void SetValue(ref PropertyKey key, ref PropVariant value);
        void Commit();
    }

    public static class NativeWindow
    {
        [DllImport("shell32.dll", PreserveSig = false)]
        private static extern void SHGetPropertyStoreForWindow(
            IntPtr windowHandle,
            ref Guid interfaceId,
            [MarshalAs(UnmanagedType.Interface)] out IPropertyStore propertyStore);

        public static void SetAppUserModelId(Window window, string appUserModelId)
        {
            IPropertyStore propertyStore = null;
            PropVariant value = PropVariant.FromString(appUserModelId);
            try
            {
                Guid interfaceId = typeof(IPropertyStore).GUID;
                SHGetPropertyStoreForWindow(
                    new WindowInteropHelper(window).Handle,
                    ref interfaceId,
                    out propertyStore);
                PropertyKey key = new PropertyKey(
                    new Guid("9f4c2855-9f79-4b39-a8d0-e1d42de1d5f3"),
                    5);
                propertyStore.SetValue(ref key, ref value);
                propertyStore.Commit();
            }
            finally
            {
                value.Dispose();
                if (propertyStore != null)
                {
                    Marshal.FinalReleaseComObject(propertyStore);
                }
            }
        }
    }

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
        private static readonly object workerGate = new object();
        private static Dispatcher worker;

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
            // Internet shortcut icons come from a shell handler that only
            // answers on an STA thread, so a thread-pool thread would yield
            // the generic file icon instead.
            TaskCompletionSource<BitmapSource> completion =
                new TaskCompletionSource<BitmapSource>();
            EnsureWorker().BeginInvoke(
                DispatcherPriority.Normal,
                new Action(delegate ()
                {
                    try
                    {
                        completion.SetResult(Get(path, pixelSize));
                    }
                    catch (Exception error)
                    {
                        completion.SetException(error);
                    }
                }));
            return completion.Task;
        }

        private static Dispatcher EnsureWorker()
        {
            lock (workerGate)
            {
                if (worker == null)
                {
                    TaskCompletionSource<Dispatcher> ready =
                        new TaskCompletionSource<Dispatcher>();
                    Thread thread = new Thread(delegate ()
                    {
                        ready.SetResult(Dispatcher.CurrentDispatcher);
                        Dispatcher.Run();
                    });
                    thread.IsBackground = true;
                    thread.SetApartmentState(ApartmentState.STA);
                    thread.Start();
                    worker = ready.Task.Result;
                }
                return worker;
            }
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

    if (-not ('LaunchTree.NativeIcon' -as [type]) -or
        -not ('LaunchTree.NativeWindow' -as [type])) {
        $references = @(
            [System.Windows.Media.Imaging.BitmapSource].Assembly.Location
            [System.Windows.Window].Assembly.Location
            [System.Windows.Rect].Assembly.Location
        )
        <#
            Supplying references replaces the PowerShell 7 default set, which
            is the only source of the threading types there. Windows
            PowerShell resolves them from mscorlib and ships no reference
            folder.
        #>
        foreach ($referenceName in @('System.Threading.Thread.dll', 'System.Threading.dll')) {
            $referencePath = Join-Path -Path $PSHOME -ChildPath "ref\$referenceName"
            if (Test-Path -LiteralPath $referencePath -PathType Leaf) {
                $references += $referencePath
            }
        }
        Add-Type -TypeDefinition $iconSource -ReferencedAssemblies $references -Language CSharp
    }
}