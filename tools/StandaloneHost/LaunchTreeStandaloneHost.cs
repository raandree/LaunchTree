// Host for the generated single-file LaunchTree script inside a compiled executable.
// tools/Build-LaunchTreeExecutable.ps1 fills in the double-underscore placeholders and
// compiles this file with the in-box .NET Framework C# compiler, so it must stay C# 5.

using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Globalization;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Host;
using System.Management.Automation.Runspaces;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security;
using System.Text;

[assembly: AssemblyTitle("__TITLE__")]
[assembly: AssemblyProduct("__PRODUCT__")]
[assembly: AssemblyDescription("__DESCRIPTION__")]
[assembly: AssemblyCompany("__COMPANY__")]
[assembly: AssemblyCopyright("__COPYRIGHT__")]
[assembly: AssemblyVersion("__ASSEMBLY_VERSION__")]
[assembly: AssemblyFileVersion("__ASSEMBLY_VERSION__")]
[assembly: AssemblyInformationalVersion("__INFORMATIONAL_VERSION__")]
[assembly: ComVisible(false)]

namespace LaunchTree.Standalone
{
    internal sealed class StandaloneRawUserInterface : PSHostRawUserInterface
    {
        private const int FallbackWidth = 120;

        private readonly bool interactive;
        private ConsoleColor foreground = ConsoleColor.Gray;
        private ConsoleColor background = ConsoleColor.Black;
        private Coordinates cursor = new Coordinates(0, 0);
        private Coordinates window = new Coordinates(0, 0);
        private Size buffer = new Size(FallbackWidth, 5000);
        private Size windowExtent = new Size(FallbackWidth, 50);
        private Size maximumWindow = new Size(FallbackWidth, 50);
        private int cursorExtent = 25;
        private string title = "__TITLE__";

        internal StandaloneRawUserInterface(bool interactive)
        {
            this.interactive = interactive;

            if (!interactive)
            {
                return;
            }

            try
            {
                buffer = new Size(Console.BufferWidth, Console.BufferHeight);
                windowExtent = new Size(Console.WindowWidth, Console.WindowHeight);
                maximumWindow = new Size(Console.LargestWindowWidth, Console.LargestWindowHeight);
                foreground = Console.ForegroundColor;
                background = Console.BackgroundColor;
            }
            catch (IOException)
            {
            }
            catch (ArgumentOutOfRangeException)
            {
            }
        }

        public override ConsoleColor ForegroundColor
        {
            get { return foreground; }
            set { foreground = value; }
        }

        public override ConsoleColor BackgroundColor
        {
            get { return background; }
            set { background = value; }
        }

        public override Coordinates CursorPosition
        {
            get { return cursor; }
            set { cursor = value; }
        }

        public override Coordinates WindowPosition
        {
            get { return window; }
            set { window = value; }
        }

        public override int CursorSize
        {
            get { return cursorExtent; }
            set { cursorExtent = value; }
        }

        public override Size BufferSize
        {
            get { return buffer; }
            set { buffer = value; }
        }

        public override Size WindowSize
        {
            get { return windowExtent; }
            set { windowExtent = value; }
        }

        public override Size MaxWindowSize
        {
            get { return maximumWindow; }
        }

        public override Size MaxPhysicalWindowSize
        {
            get { return maximumWindow; }
        }

        public override string WindowTitle
        {
            get { return title; }
            set { title = value; }
        }

        public override bool KeyAvailable
        {
            get { return interactive && Console.KeyAvailable; }
        }

        public override void FlushInputBuffer()
        {
        }

        public override KeyInfo ReadKey(ReadKeyOptions options)
        {
            if (!interactive)
            {
                throw new PSNotSupportedException(
                    "The compiled LaunchTree host cannot read a key without a console.");
            }

            ConsoleKeyInfo key = Console.ReadKey((options & ReadKeyOptions.NoEcho) == ReadKeyOptions.NoEcho);
            return new KeyInfo((int)key.Key, key.KeyChar, default(ControlKeyStates), true);
        }

        public override BufferCell[,] GetBufferContents(Rectangle rectangle)
        {
            throw new PSNotSupportedException("The compiled LaunchTree host has no screen buffer.");
        }

        public override void SetBufferContents(Coordinates origin, BufferCell[,] contents)
        {
            throw new PSNotSupportedException("The compiled LaunchTree host has no screen buffer.");
        }

        public override void SetBufferContents(Rectangle rectangle, BufferCell fill)
        {
            throw new PSNotSupportedException("The compiled LaunchTree host has no screen buffer.");
        }

        public override void ScrollBufferContents(
            Rectangle source, Coordinates destination, Rectangle clip, BufferCell fill)
        {
            throw new PSNotSupportedException("The compiled LaunchTree host has no screen buffer.");
        }
    }

    internal sealed class StandaloneUserInterface : PSHostUserInterface
    {
        private readonly StandaloneRawUserInterface raw;
        private readonly bool interactive;

        internal StandaloneUserInterface(bool interactive)
        {
            this.interactive = interactive;
            raw = new StandaloneRawUserInterface(interactive);
        }

        public override PSHostRawUserInterface RawUI
        {
            get { return raw; }
        }

        public override void Write(string value)
        {
            Console.Out.Write(value);
        }

        public override void Write(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value)
        {
            if (!interactive)
            {
                Console.Out.Write(value);
                return;
            }

            ConsoleColor previousForeground = Console.ForegroundColor;
            ConsoleColor previousBackground = Console.BackgroundColor;
            try
            {
                Console.ForegroundColor = foregroundColor;
                Console.BackgroundColor = backgroundColor;
                Console.Out.Write(value);
            }
            finally
            {
                Console.ForegroundColor = previousForeground;
                Console.BackgroundColor = previousBackground;
            }
        }

        public override void WriteLine(string value)
        {
            Console.Out.WriteLine(value);
        }

        public override void WriteErrorLine(string value)
        {
            WriteChannel(ConsoleColor.Red, value);
        }

        public override void WriteWarningLine(string message)
        {
            WriteChannel(ConsoleColor.Yellow, "WARNING: " + message);
        }

        public override void WriteVerboseLine(string message)
        {
            WriteChannel(ConsoleColor.Cyan, "VERBOSE: " + message);
        }

        public override void WriteDebugLine(string message)
        {
            WriteChannel(ConsoleColor.Yellow, "DEBUG: " + message);
        }

        public override void WriteProgress(long sourceId, ProgressRecord record)
        {
        }

        public override string ReadLine()
        {
            if (!interactive)
            {
                throw new PSNotSupportedException(
                    "The compiled LaunchTree host cannot prompt without a console.");
            }

            return Console.In.ReadLine();
        }

        public override SecureString ReadLineAsSecureString()
        {
            throw new PSNotSupportedException(
                "The compiled LaunchTree host does not read secrets.");
        }

        public override Dictionary<string, PSObject> Prompt(
            string caption, string message, Collection<FieldDescription> descriptions)
        {
            throw new PSNotSupportedException(
                "The compiled LaunchTree host does not prompt for values.");
        }

        public override PSCredential PromptForCredential(
            string caption, string message, string userName, string targetName)
        {
            throw new PSNotSupportedException(
                "The compiled LaunchTree host does not prompt for credentials.");
        }

        public override PSCredential PromptForCredential(
            string caption,
            string message,
            string userName,
            string targetName,
            PSCredentialTypes allowedCredentialTypes,
            PSCredentialUIOptions options)
        {
            throw new PSNotSupportedException(
                "The compiled LaunchTree host does not prompt for credentials.");
        }

        public override int PromptForChoice(
            string caption, string message, Collection<ChoiceDescription> choices, int defaultChoice)
        {
            if (!interactive)
            {
                throw new PSNotSupportedException(
                    "The compiled LaunchTree host cannot confirm without a console; pass -Force.");
            }

            if (!string.IsNullOrEmpty(caption))
            {
                WriteLine(caption);
            }

            if (!string.IsNullOrEmpty(message))
            {
                WriteLine(message);
            }

            StringBuilder prompt = new StringBuilder();
            for (int index = 0; index < choices.Count; index++)
            {
                prompt.Append(index == 0 ? string.Empty : "  ");
                prompt.Append(choices[index].Label);
            }

            while (true)
            {
                Write(prompt.ToString() + " [default is " + choices[defaultChoice].Label + "]: ");
                string answer = Console.In.ReadLine();
                if (string.IsNullOrEmpty(answer))
                {
                    return defaultChoice;
                }

                for (int index = 0; index < choices.Count; index++)
                {
                    string label = choices[index].Label.Replace("&", string.Empty);
                    if (label.Equals(answer, StringComparison.OrdinalIgnoreCase) ||
                        label.StartsWith(answer, StringComparison.OrdinalIgnoreCase))
                    {
                        return index;
                    }
                }
            }
        }

        private void WriteChannel(ConsoleColor color, string value)
        {
            if (!interactive)
            {
                Console.Error.WriteLine(value);
                return;
            }

            ConsoleColor previous = Console.ForegroundColor;
            try
            {
                Console.ForegroundColor = color;
                Console.Error.WriteLine(value);
            }
            finally
            {
                Console.ForegroundColor = previous;
            }
        }
    }

    internal sealed class StandaloneHost : PSHost
    {
        private readonly Guid instanceId = Guid.NewGuid();
        private readonly CultureInfo culture = CultureInfo.CurrentCulture;
        private readonly CultureInfo uiCulture = CultureInfo.CurrentUICulture;
        private readonly StandaloneUserInterface ui;

        internal StandaloneHost(bool interactive)
        {
            ui = new StandaloneUserInterface(interactive);
        }

        internal bool ShouldExit { get; private set; }

        internal int ExitCode { get; private set; }

        public override string Name
        {
            get { return "LaunchTreeStandaloneHost"; }
        }

        public override Guid InstanceId
        {
            get { return instanceId; }
        }

        public override Version Version
        {
            get { return new Version("__ASSEMBLY_VERSION__"); }
        }

        public override PSHostUserInterface UI
        {
            get { return ui; }
        }

        public override CultureInfo CurrentCulture
        {
            get { return culture; }
        }

        public override CultureInfo CurrentUICulture
        {
            get { return uiCulture; }
        }

        public override void EnterNestedPrompt()
        {
            throw new PSNotSupportedException("The compiled LaunchTree host has no nested prompt.");
        }

        public override void ExitNestedPrompt()
        {
            throw new PSNotSupportedException("The compiled LaunchTree host has no nested prompt.");
        }

        public override void NotifyBeginApplication()
        {
        }

        public override void NotifyEndApplication()
        {
        }

        public override void SetShouldExit(int exitCode)
        {
            ShouldExit = true;
            ExitCode = exitCode;
        }
    }

    public static class Program
    {
        private const int HideWindow = 0;
        private const string ScriptResourceName = "__SCRIPT_RESOURCE_NAME__";
        private const string BootstrapResourceName = "__BOOTSTRAP_RESOURCE_NAME__";

        [DllImport("kernel32.dll")]
        private static extern IntPtr GetConsoleWindow();

        [DllImport("kernel32.dll")]
        private static extern uint GetConsoleProcessList(uint[] processList, uint processCount);

        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr windowHandle, int command);

        [STAThread]
        public static int Main(string[] args)
        {
            bool interactive = PrepareConsole();
            StandaloneHost host = new StandaloneHost(interactive);
            int exitCode = 0;

            try
            {
                exitCode = RunEmbeddedScript(host, args);
            }
            catch (Exception exception)
            {
                host.UI.WriteErrorLine(exception.Message);
                exitCode = 1;
            }

            return host.ShouldExit ? host.ExitCode : exitCode;
        }

        private static int RunEmbeddedScript(StandaloneHost host, string[] args)
        {
            string script = ReadEmbeddedText(ScriptResourceName);
            string bootstrap = ReadEmbeddedText(BootstrapResourceName);

            using (Runspace runspace = RunspaceFactory.CreateRunspace(host))
            {
                runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                runspace.Open();
                runspace.SessionStateProxy.SetVariable("LaunchTreeExecutablePath", GetExecutablePath());
                runspace.SessionStateProxy.SetVariable("LaunchTreeEmbeddedScript", script);
                runspace.SessionStateProxy.SetVariable("LaunchTreeArgument", args);

                using (PowerShell shell = PowerShell.Create())
                {
                    shell.Runspace = runspace;
                    shell.AddScript(bootstrap)
                        .AddCommand("Out-String")
                        .AddParameter("Stream", true);

                    Subscribe(shell, host);

                    Collection<PSObject> results = shell.Invoke();
                    foreach (PSObject result in results)
                    {
                        if (result != null)
                        {
                            host.UI.WriteLine(result.ToString());
                        }
                    }

                    return shell.Streams.Error.Count > 0 ? 1 : 0;
                }
            }
        }

        private static void Subscribe(PowerShell shell, StandaloneHost host)
        {
            shell.Streams.Error.DataAdded += delegate(object sender, DataAddedEventArgs e)
            {
                host.UI.WriteErrorLine(shell.Streams.Error[e.Index].ToString());
            };
            shell.Streams.Warning.DataAdded += delegate(object sender, DataAddedEventArgs e)
            {
                host.UI.WriteWarningLine(shell.Streams.Warning[e.Index].Message);
            };
            shell.Streams.Verbose.DataAdded += delegate(object sender, DataAddedEventArgs e)
            {
                host.UI.WriteVerboseLine(shell.Streams.Verbose[e.Index].Message);
            };
            shell.Streams.Debug.DataAdded += delegate(object sender, DataAddedEventArgs e)
            {
                host.UI.WriteDebugLine(shell.Streams.Debug[e.Index].Message);
            };
            shell.Streams.Information.DataAdded += delegate(object sender, DataAddedEventArgs e)
            {
                host.UI.WriteLine(shell.Streams.Information[e.Index].ToString());
            };
        }

        private static string ReadEmbeddedText(string resourceName)
        {
            using (Stream stream = Assembly.GetExecutingAssembly()
                .GetManifestResourceStream(resourceName))
            {
                if (stream == null)
                {
                    throw new InvalidOperationException(
                        "The embedded resource '" + resourceName + "' is missing from this executable.");
                }

                using (StreamReader reader = new StreamReader(stream, Encoding.UTF8, true))
                {
                    return reader.ReadToEnd();
                }
            }
        }

        private static string GetExecutablePath()
        {
            Assembly assembly = Assembly.GetEntryAssembly();
            if (assembly != null && !string.IsNullOrEmpty(assembly.Location))
            {
                return assembly.Location;
            }

            using (System.Diagnostics.Process process = System.Diagnostics.Process.GetCurrentProcess())
            {
                return process.MainModule.FileName;
            }
        }

        // A console this process created for itself belongs to a shortcut or a double click,
        // where a console window would be noise; an inherited console is a real terminal.
        private static bool PrepareConsole()
        {
            IntPtr window = GetConsoleWindow();
            if (window == IntPtr.Zero)
            {
                return false;
            }

            if (!__HIDE_OWN_CONSOLE__)
            {
                return true;
            }

            uint[] processes = new uint[4];
            if (GetConsoleProcessList(processes, (uint)processes.Length) > 1)
            {
                return true;
            }

            ShowWindow(window, HideWindow);
            return false;
        }
    }
}
