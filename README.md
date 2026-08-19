# LaunchTree

LaunchTree is a Windows PowerShell module that creates native Start shortcuts
for managed Entry Roots and opens their recursive content in a WPF Launcher.

The module is under active development. Its signed behavior and release gates
are defined in the [specifications](docs/specifications/README.md).

## Getting started

Follow the [getting-started guide](docs/getting-started.md) to build or install
the module, create a first Entry Root, reconcile its Start Entry, and verify the
Launcher. The [setup script](tools/Initialize-QuickStart.ps1) writes a default
machine configuration, creates a sample Entry Root of built-in Windows Launch
Items, and reconciles its Start Entry when run elevated.

The build also produces `output\LaunchTree.ps1`, a generated self-contained
script for machines where installing a module is impractical. Dot-source it to
load every command, or use `-Command` to run one operation. It also produces
`output\LaunchTree.Minimal.ps1`, a much smaller script that only opens the
Launcher. See
[single-file script delivery](docs/deployment.md#single-file-script-delivery).

## Content model

The default Managed Root is:

```text
C:\ProgramData\LaunchTree\LaunchTree
```

Every immediate directory becomes a Start Entry. Nested directories become
Menu Folders. `.lnk` files and HTTP(S) `.url` files become Launch Items.
Optional UTF-8 `description.txt` files provide Menu Folder tooltips.

## Launcher layouts

Set `LauncherLayout` in the machine configuration to choose the presentation.
`TabbedList` is the default: Menu Folders become tabs, the active description
sits above them, and Launch Items render as compact rows. Selecting a tab keeps
the tab strip visible and opens that folder in place; a Menu Folder below the
selected tab appears as a row that moves the tab strip one level deeper. Select
`Grid` for the tile presentation.

### Tabbed list (default)

![Default dark-theme TabbedList Launcher](docs/images/wpf/launcher-tabbed-list.png)

### Grid

![Dark-theme Grid Launcher](docs/images/wpf/launcher-grid.png)

## Commands

- `Get-LaunchTreeConfiguration`
- `Test-LaunchTree`
- `Update-LaunchTree`
- `Show-LaunchTree`
- `Get-LaunchTreeDiagnostic`
- `Export-LaunchTreeSupportBundle`
- `Clear-LaunchTreeCache`
- `New-LaunchTreeShortcut`
- `Remove-LaunchTree`

## Development

The project uses Sampler, Pester 5, ModuleBuilder, PSScriptAnalyzer, and
GitVersion. Run builds and tests through the detached launcher described in the
project instructions. The `Validate documentation` VS Code task checks the
Memory Bank, specification identifiers, references, links, and sign-off state.

## Project records

- [Signed Design Concept](docs/design-concept.md)
- [Functional requirements](docs/specifications/functional-requirements.md)
- [Configuration specification](docs/specifications/configuration.md)
- [Quality requirements](docs/specifications/quality-requirements.md)
- [Open issues](docs/open-issues.md)

## Operations

- [Getting started](docs/getting-started.md)
- [Deployment](docs/deployment.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Machine configuration example](docs/examples/LaunchTree.json)
