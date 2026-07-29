# Configuration specification

> Status: Accepted
> Schema version: 1
> Decisions: `ADR-0002`, `ADR-0005`, `ADR-0006`, `ADR-0008`, `ADR-0009`, `ADR-0010`

This specification resolves machine configuration, user preference, Generated
State, cache, and event contracts. Administrator-authored files are read-only
to the module.

## Path derivation

### CR-001 Vendor name

`VendorName` must be a single valid Windows directory-name segment. It must not
be rooted, contain a directory separator, equal `.` or `..`, or contain Windows
invalid filename characters. The default is `LaunchTree`.

### CR-002 Default paths

For `VendorName = LaunchTree`, defaults are:

| Purpose | Path |
| --- | --- |
| Managed Root | `%ProgramData%\LaunchTree\LaunchTree` |
| Machine configuration | `%ProgramData%\LaunchTree\LaunchTree.json` |
| Generated State ownership record | `%ProgramData%\LaunchTree\LaunchTree.generated.json` |
| Personal Root | `%APPDATA%\LaunchTree\LaunchTree` |
| User preferences | `%APPDATA%\LaunchTree\LaunchTree.preferences.json` |
| User cache | `%LOCALAPPDATA%\LaunchTree\LaunchTree\Cache\v1` |

Replacing `VendorName` changes only the first `LaunchTree` segment in
each path. Callers may override the machine configuration path explicitly.

### CR-013 Root override parameters

`Get-LaunchTreeConfiguration`, `Show-LaunchTree`, `Test-LaunchTree`, and
`Export-LaunchTreeSupportBundle` accept `ManagedRoot` and `PersonalRoot`
parameters. The resolution precedence for both roots is:

1. The parameter supplied to the command.
2. The machine configuration field from `CR-005`.
3. The default derived by `CR-002`.

An override is expanded for environment variables and must be absolute. An
invalid override is a caller error rather than invalid administrator input, so
the command must throw instead of falling back to a lower-precedence value and
resolving content from an unintended root.

An override applies only to the invocation that supplies it. `Update-LaunchTree`
must not accept these parameters: an activated Start Entry re-resolves the
Managed Root from the machine configuration file named in its `CR-011`
arguments and compares it with the `CR-007` ownership record, so Reconciliation
from an unpersisted root would commit Start Entries that fail on activation. A
relocated deployment must persist `ManagedRoot` in the machine configuration.

### CR-003 Start Entry location

Machine-wide Start Entries live directly under the Common Programs directory
returned by Windows, normally:

```text
%ProgramData%\Microsoft\Windows\Start Menu\Programs
```

Windows-known-folder APIs, not a hard-coded localized path, must resolve it.

## Machine configuration

### CR-004 File shape

The machine configuration is UTF-8 JSON. Unknown properties produce a warning
and are ignored for forward compatibility. A missing property uses its default.
An invalid property uses its default and produces a Health Finding. Invalid
JSON causes the entire file to be ignored in favor of defaults. An unsupported
future `SchemaVersion` is not invalid input: the Launcher must show an
incompatible-configuration error, health must be `Unhealthy`, and
Reconciliation must refuse every mutation without reading other fields.

```json
{
  "SchemaVersion": 1,
  "VendorName": "LaunchTree",
  "ManagedRoot": "C:\\ProgramData\\LaunchTree\\LaunchTree",
  "PersonalRoot": "%APPDATA%\\LaunchTree\\LaunchTree",
  "MaximumDepth": 5,
  "LauncherHost": "WindowsPowerShell",
  "LauncherLayout": "TabbedList",
  "DefaultSortOrder": "NameAscending",
  "CloseAfterLaunch": true,
  "Cache": {
    "MaximumSizeMB": 64,
    "MaximumAgeDays": 30
  },
  "Diagnostics": {
    "LogName": "LaunchTree",
    "SourceName": "LaunchTree",
    "MaximumLogSizeMB": 25,
    "TargetRetentionDays": 30
  }
}
```

### CR-005 Field constraints

| Field | Type | Default | Constraint |
| --- | --- | --- | --- |
| `SchemaVersion` | Integer | `1` | Must equal a supported schema version; future versions fail closed |
| `VendorName` | String | `LaunchTree` | Must satisfy `CR-001` |
| `ManagedRoot` | String | Derived by `CR-002` | Absolute local path after environment expansion |
| `PersonalRoot` | String | Derived by `CR-002` | Absolute path after expansion in user context |
| `MaximumDepth` | Integer | `5` | Inclusive range `1..32` |
| `LauncherHost` | String | `WindowsPowerShell` | `WindowsPowerShell` or `PowerShell7` |
| `LauncherLayout` | String | `TabbedList` | `Grid` or `TabbedList` |
| `DefaultSortOrder` | String | `NameAscending` | `NameAscending` or `NameDescending` |
| `CloseAfterLaunch` | Boolean | `true` | No coercion from strings or numbers |
| `Cache.MaximumSizeMB` | Integer | `64` | Inclusive range `16..256` |
| `Cache.MaximumAgeDays` | Integer | `30` | Inclusive range `1..90` |
| `Diagnostics.LogName` | String | `LaunchTree` | Non-empty and valid for Windows Event Log registration |
| `Diagnostics.SourceName` | String | `LaunchTree` | Non-empty and valid for Windows Event Log registration |
| `Diagnostics.MaximumLogSizeMB` | Integer | `25` | Inclusive range `1..128` |
| `Diagnostics.TargetRetentionDays` | Integer | `30` | Inclusive range `1..90` |

The permitted `.url` schemes are fixed to `http` and `https` in schema version
1 and are not extensible through configuration.

## User preferences

### CR-006 File shape

The user preference file is UTF-8 JSON and may contain only presentation state:

```json
{
  "SchemaVersion": 1,
  "SortOrder": "NameAscending",
  "CloseAfterLaunch": true,
  "Window": {
    "Width": null,
    "Height": null,
    "Left": null,
    "Top": null
  }
}
```

Invalid user preferences use machine defaults without preventing the Launcher
from opening. Remembered window coordinates must be clamped to the virtual
screen so the window stays reachable on any connected monitor. The file must
not contain Launch Item targets, search history, or usage
history. Missing or null first-run dimensions fit visible content, with a
minimum of 520 by 420 device-independent pixels and a maximum of 80 percent of
the active work area. A user resize stores the resulting dimensions, and a user
move stores the resulting coordinates.

## Generated State

### CR-007 Ownership record

The ownership record is module-authored UTF-8 JSON containing:

- `SchemaVersion`
- module version
- configuration path and normalized Managed Root
- each owned Start Entry path
- one immutable, randomly generated Entry ID per Entry Root
- Entry Root identity and normalized source path
- content hash of the generated Start Entry definition
- last successful Reconciliation time in UTC

The record must never contain Launch Item targets or arguments. An existing
Start shortcut absent from this record is unowned for `FR-023`.

### CR-008 Transaction staging

Reconciliation stages files in a GUID-named directory beside the ownership
record. Commit uses same-volume atomic rename where available. The prior
ownership record and Start Entries remain recoverable until all replacements
succeed. Startup health removes only abandoned staging directories that are
older than 24 hours and are not referenced by an active transaction marker.

## Cache

### CR-009 Cache policy

The user cache uses a versioned `v1` namespace with a 64 MB default cap, a
least-recently-used eviction policy, and a 30-day maximum age. A cache key must
include normalized source path, file length, last-write time in UTC, requested
DPI/icon size, and extractor version. The Launcher must never deserialize a
different cache namespace. Cache deletion must not affect source content or
Generated State.

## Event contract

### CR-010 Event ranges

The default dedicated log and source are both `LaunchTree`. Event IDs are
stable within schema version 1:

| Range | Category |
| --- | --- |
| `1000-1099` | Configuration and root access |
| `1100-1199` | Content discovery and validation |
| `1200-1299` | Launch Item invocation |
| `1300-1399` | Reconciliation and Generated State |
| `1400-1499` | Icon extraction and cache |
| `1500-1599` | Performance budget breaches |
| `1600-1699` | Health and Support Bundle operations |

Initial event IDs are:

| ID | Level | Meaning |
| --- | --- | --- |
| `1001` | Warning | Machine configuration fallback applied |
| `1002` | Error | Managed Root inaccessible |
| `1101` | Warning | Invalid Launch Item excluded |
| `1102` | Warning | Maximum depth exceeded |
| `1103` | Warning | Menu Folder description unavailable |
| `1104` | Warning | `.url` scheme rejected |
| `1105` | Warning | Launcher Host path-length limit excluded content |
| `1106` | Warning | Directory reparse point ignored |
| `1201` | Error | Windows Shell invocation failed |
| `1301` | Error | Reconciliation failed and rollback was attempted |
| `1302` | Information | Reconciliation completed |
| `1401` | Warning | High-resolution icon extraction failed |
| `1402` | Warning | Cache namespace was rebuilt |
| `1501` | Warning | Launcher startup budget exceeded |
| `1502` | Warning | Interaction budget exceeded |
| `1503` | Warning | Working-set budget exceeded |
| `1601` | Error | Support Bundle export failed |
| `1602` | Information | Event log write/read access probe |
| `1603` | Warning | Standard-user event-log access probe not verified |

Every event must include event schema version, module version, operation,
redacted source path when relevant, error category, and error code. Events must
not include Launch Item arguments, URL query strings, or successful usage.

The log uses a 25 MB default maximum and overwrites oldest records as needed.
Thirty days is a retention target rather than a guarantee when volume reaches
the size cap.

Before registration, the module must search all classic event logs for
`SourceName`. If the source exists under another log, or its registration does
not match the ownership record, Reconciliation must fail without changing it.

## Start Entry activation

### CR-011 Launcher bootstrap

Each Start Entry uses these separately stored Shell Link fields:

| Field | Value |
| --- | --- |
| Target path | Host resolved from `LauncherHost` during Reconciliation |
| Working directory | Built module directory |
| Window style | Hidden |
| Arguments | Fixed switches, bootstrap path, Entry ID, and machine configuration path |

`WindowsPowerShell` resolves to
`%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`.
`PowerShell7` resolves a native `pwsh.exe` from its registered installation;
Reconciliation must fail if it is missing or its architecture does not match
the operating system. The ownership record stores the resolved absolute host
path. The argument sequence is:

```text
-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -STA -File "<ModuleBase>\Scripts\Start-LaunchTreeLauncher.ps1" -EntryId "<GUID>" -ConfigurationPath "<absolute-path>"
```

The Entry ID is a GUID from `CR-007`; no Entry Root name or source path appears
in executable PowerShell text. Windows paths cannot contain a double quote, and
Reconciliation must reject any bootstrap or configuration path that cannot be
represented as one quoted argument. Argument encoding must follow Windows
`CommandLineToArgvW` escaping, including doubling trailing backslashes before a
closing quote. The bootstrap accepts only a GUID Entry ID,
loads the ownership record, verifies that the ID and normalized Managed Root
still match, and then starts or contacts the session-local Launcher.

The Launcher uses a `Local\` session-scoped mutex and a current-user-only named
pipe. This produces one process per interactive logon session without allowing
another user or session to redirect activation.

## Event log access

### CR-012 Registration and runtime API

Elevated Reconciliation creates the dedicated classic event log and source
before Start Entries are committed. Registration must configure:

- an owner and group in a syntactically valid `CustomSD`
- full read, write, and clear rights (`0x7`) for Local System and built-in
  administrators
- read and write rights (`0x3`) for Interactive Users
- no clear right for standard users
- the configured maximum size, default 25 MB, and overwrite-as-needed retention

The event log is diagnostic evidence, not a security audit: any interactive
user granted write access can submit records under a registered source.

All supported PowerShell editions must write through
`System.Diagnostics.EventLog.WriteEntry` and read through compatible .NET or
`Get-WinEvent` APIs. Runtime code must not depend on Windows PowerShell-only
`New-EventLog` or `Write-EventLog` cmdlets. Registration remains elevated;
Launcher writes and health reads remain standard-user operations.

A runtime write must verify that the configured source is registered for the
configured log and must skip the write otherwise. Runtime code must never
register an event source implicitly, because an elevated write to an unknown
source binds that source to the `Application` log and permanently blocks
registration of the dedicated log.

Reconciliation must validate the final descriptor with an access check for the
Interactive Users SID before committing Start Entries. It then launches the
packaged probe through the selected Launcher Host using the elevated account's
linked standard-user token. The probe refuses an administrator token, writes a
nonce-bearing event, reads it back, and exits within a bounded timeout. A
missing linked token or write/read failure must abort the transaction; it must
never be silently discarded.
