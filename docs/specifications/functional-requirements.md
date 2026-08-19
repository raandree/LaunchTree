# Functional requirements

> Status: Accepted
> Version: 1
> Source: [Signed Design Concept](../design-concept.md)

This specification defines behavior visible to users, deployment automation,
and support operators. `Must` denotes a release requirement. `Should` denotes
a preferred behavior that may be waived only through an accepted decision.

## Content discovery

### FR-001 Resolve roots

The module must derive the Managed Root and Personal Root from the machine
configuration. Missing optional path fields must use the defaults in `CR-002`.
A caller may override either root for a single invocation under `CR-013`.
Environment variables in the Personal Root must be expanded in the signed-in
user context.

### FR-002 Discover Entry Roots

Every immediate, non-reparse-point child directory of the Managed Root must be
an Entry Root. A DFS link must count as an Entry Root, because a Managed Root
published as a DFS namespace exposes its Entry Roots as DFS reparse points.
Loose files in the Managed Root must not become content.

### FR-003 Create Start Entries from managed content

Reconciliation must create exactly one machine-wide Start Entry for every Entry
Root. A directory that exists only under the Personal Root must not create a
machine-wide Start Entry.

### FR-004 Merge Content Sources

Within an Entry Root, the Content Snapshot must union matching relative paths
from the Managed Root and Personal Root. Case-insensitive name collisions must
remain visible as separate objects and expose their Content Source.

### FR-005 Traverse Menu Folders safely

Every directory at or below an Entry Root must be a Menu Folder. Traversal must
ignore directory reparse points other than DFS links, stop at the configured
maximum depth, and emit a Health Finding for excluded deeper content. A Menu
Folder whose subtree contains no visible Launch Item must be omitted from the
Content Snapshot. On Windows PowerShell 5.1, content beyond the host's effective
path-length limit must be excluded with a Health Finding rather than
disappearing silently.

### FR-006 Read Menu Folder descriptions

When a Menu Folder contains `description.txt`, the Launcher must read it as
UTF-8, trim surrounding whitespace, preserve internal line breaks, and expose
the result as a wrapped, size-capped tooltip. A read or decode failure must not
block the Menu Folder.

### FR-007 Read Launch Items

Version 1 must accept `.lnk` files and `.url` files whose scheme is `http` or
`https`. The visible name must be the filename without its extension. A `.lnk`
tooltip must use its embedded Description field when present. A `.url` has no
Launch Item tooltip in version 1 and must never expose its target URL on hover.

### FR-008 Isolate invalid content

An unreadable or invalid Launch Item must be excluded without hiding healthy
siblings. The module must emit a redacted warning event and a Health Finding.

### FR-009 Use a Content Snapshot

Each Launcher activation must read one Content Snapshot. Source changes during
an activation must not mutate that snapshot. A later activation must read the
new state.

## Launcher behavior

### FR-010 Maintain one Launcher per user

At most one Launcher process and window may be active per interactive logon
session. A later activation in the same session must focus the existing window
and switch it to the requested Entry Root. Concurrent sessions, including two
sessions for one account, must have independent Launcher processes.

### FR-011 Navigate in one window

Activating a Menu Folder must replace the visible content in the same window.
The Back control must restore parent context. The window title bar must be one
compact line holding the application icon, the current Entry Root title, and the
Minimize, Maximize, and Close controls; the Maximize control must restore the
window when it is already maximized; the title must expose the current path as
its tooltip. The
selected description must appear in its own field between the title bar and the
navigation strip. That field must always reserve exactly two lines, so the
navigation strip never moves when the description changes; a description longer
than two lines must be truncated with an ellipsis and remain readable in full as
the field's tooltip. The Back control must sit at the left of the navigation
strip. A Menu Folder whose subtree contains no Launch Item must not be
displayed.
`TabbedList` is the
default Launcher layout: the owning Menu Folder and its child Menu Folders
must be tabs, the selected tab's description must appear in the description
field above the tabs, and
the selected tab's Launch Items must appear as compact list rows. The owning
Menu Folder must keep its own tab only while it holds a Launch Item directly
or no child Menu Folder tab can replace it; when that tab is hidden, the first
child Menu Folder tab must be selected. Selecting a tab must keep the whole
tab strip visible and highlight the selected tab. A Menu Folder below the
selected tab must appear as a list row, and opening that row must move the tab
strip one level deeper. The window width must fit the tab strip without
horizontal scrolling, within the work-area maximum and never below the width
the user last chose, and the layout must not display an item count. Machine
configuration may select `Grid` for the tile
presentation.

### FR-012 Search all Entry Roots

The `Grid` layout must provide type-to-search across all configured Entry
Roots. Results must include enough relative path and Content Source context to
distinguish equal names. `TabbedList` navigates through tabs and provides no
search box.

### FR-013 Sort by localized name

The Launcher must support locale-aware, case-insensitive `NameAscending` and
`NameDescending` ordering. `Grid` must sort Menu Folders and Launch Items
together and offer a sort selector. `TabbedList` must sort Menu Folder tabs and
Launch Item rows independently, following the configured order without a
selector.

### FR-014 Follow Windows presentation settings

The Launcher must follow the user's light, dark, and high-contrast settings. It
must open near the Start button when no window position is remembered and at
the remembered position afterwards, stay inside the active work area, fit
content within screen bounds, permit resizing, permit minimizing, maximizing,
and restoring, permit moving the window by dragging its title bar, and scroll
overflow.

### FR-015 Support keyboard and touch

The Launcher must support touch and keyboard operation. Arrow keys move focus;
Enter activates; Escape closes; Backspace navigates to the parent; and every
keyboard-focused interactive element has a visible focus indicator.

### FR-016 Suppress right-click inside the Launcher

Right-click or touch press-and-hold inside Launcher content must not activate an
object or open a context menu. This requirement does not apply to the Windows-
owned context menu of a native Start Entry.

### FR-017 Load high-resolution icons without layout shifts

The Launcher must request icons appropriate to current DPI. It may display a
fixed-size placeholder while loading asynchronously. Replacing a placeholder
must not change layout. Extraction failure must use the Windows Shell fallback
icon.

## Invocation

### FR-018 Invoke through Windows Shell

Activating a Launch Item must ask Windows Shell to open the shortcut file
itself. The module must not reconstruct target paths, arguments, working
directories, show states, environment expansion, or elevation behavior.

### FR-019 Handle invocation outcomes

After a successful invocation, the Launcher must close when `CloseAfterLaunch`
is true and remain open otherwise. The resolved default is false, so the
Launcher stays open and a user can start several items from one window; an
administrator, a user preference, or the `CR-014` override may ask for closing.
A failed invocation must show a nonmodal inline error, retain navigation state,
and emit a redacted error event.

## Configuration and preferences

### FR-020 Degrade safely on configuration failure

Missing or partly invalid machine configuration must use valid defaults and
emit warnings. An inaccessible Managed Root must produce a visible error state.
The module must never rewrite administrator-authored configuration.

### FR-021 Persist only allowed user preferences

The Launcher may persist sort order, close-after-launch behavior, window size,
and window position in the user preference file. A maximized window must
persist the size and position it restores to, not its maximized bounds. It must
not persist source content or target details.

## Reconciliation and lifecycle

### FR-022 Reconcile Generated State transactionally

Reconciliation must stage all Start Entry and ownership-record changes before
commit. A failure at any point must restore the complete prior Generated State.

### FR-023 Protect unowned Start content

Reconciliation must not overwrite or remove an existing Start shortcut that is
not listed in the ownership record. A collision must fail the transaction and
produce an actionable Health Finding.

### FR-024 Remove only Generated State

Removal must delete module-owned Start Entries, ownership records, event
registration, and caches selected by scope. It must preserve the Managed Root,
Personal Root, Launch Items, Menu Folders, and administrator-authored
configuration.

### FR-025 Support one previous major Generated State schema

The current module must read and transactionally migrate Generated State from
one previous major schema. A supported downgrade must restore compatible state.
Incompatible cache namespaces must be ignored rather than parsed.

### FR-034 Clear the user cache on demand

`Clear-LaunchTreeCache` must discard every cached icon in the resolved cache
namespace without waiting for the age or size eviction in `CR-009`. It must
support `ShouldProcess`, keep the namespace directory so the next Launcher run
repopulates it, report how many entries and bytes it discarded, and succeed
with a zero count when the namespace does not exist. It must not touch source
content, Generated State, machine configuration, or user preferences.

An operator needs this because a cache key identifies only the shortcut, so a
repaired or newly deployed icon target cannot invalidate the entry that the
shortcut already produced.

### FR-035 Create an Entry Root shortcut with a wizard

`New-LaunchTreeShortcut` must open a three-step wizard for creating a Windows
shortcut to an Entry Root. Both single-file deliveries must reach the same
wizard through `-Command CreateShortcut`. The Launcher must not offer the
wizard from its title bar. The wizard must accept one folder path, derive the
Managed Root from its parent and the Entry Root name from its last segment, and
reject a path that is relative, names no parent folder, or names a UNC share
without an Entry Root folder below it.

The wizard must let the user choose whether the Launcher closes after an item
starts, must ask for the shortcut file through a Windows save dialog, must show
the resulting command line before it writes anything, and must write the
`CR-015` shortcut only when the user confirms the last step. A failure at any
step must stay inside the wizard with an actionable message and must not create
a partial shortcut. The created shortcut is user-owned: it must not appear in
the `CR-007` ownership record and Reconciliation must neither create nor remove
it.

## Health and support

### FR-026 Emit stable events

The module must emit configuration, content, invocation, Reconciliation, cache,
performance, and support failures using the stable contract in `CR-010`.
Successful Launch Item use must not be audited.

### FR-027 Return structured health

`Test-LaunchTree` must return a top-level `Healthy`, `Degraded`, or
`Unhealthy` state and structured Health Findings for configuration, Generated
State drift, content, compatibility, cache, and recent events.

### FR-028 Export a redacted Support Bundle

`Export-LaunchTreeSupportBundle` must create a Support Bundle containing
the configuration summary, Generated State inventory, cache metadata, and
relevant events. It must omit Launch Item arguments and URL query strings.

### FR-029 Report performance budget breaches

The Launcher must emit warning events only when startup, interaction, or memory
budgets are exceeded. It must not emit performance events for every healthy
activation.

### FR-030 Read effective configuration

`Get-LaunchTreeConfiguration` must return the effective machine
configuration, resolved paths, user preferences, fallback warnings, and source
of each value without creating or rewriting any file.

### FR-031 Read diagnostics

`Get-LaunchTreeDiagnostic` must return structured, redacted event and
Health Finding objects. It must support time, event ID, level, and operation
filters without returning successful Launch Item activity.

### FR-032 Activate Start Entries safely

Each Start Entry must pass an opaque Entry ID to the fixed Launcher bootstrap
defined by `CR-011`. Reconciliation must never interpolate an Entry Root name
or source path into PowerShell code. The bootstrap must resolve the Entry ID
through the ownership record before opening a Content Snapshot.

### FR-033 Register usable diagnostics

Elevated Reconciliation must register and validate the dedicated event log,
event source, size policy, and access descriptor defined by `CR-012`. It must
fail before changing Start Entries if the event source is owned by another log
or a standard interactive user cannot read and write a probe event.

## Public command surface

| Command | Purpose | Required behavior |
| --- | --- | --- |
| `Get-LaunchTreeConfiguration` | Read effective machine settings and user preferences | Implements `FR-030` |
| `Test-LaunchTree` | Evaluate installation health | Implements `FR-027` and supports automation-friendly output |
| `Update-LaunchTree` | Reconcile Generated State | Supports `ShouldProcess`; implements `FR-022` and `FR-023` |
| `Show-LaunchTree` | Open or activate the Launcher | Requires an Entry Root name and implements `FR-009` through `FR-019` |
| `Get-LaunchTreeDiagnostic` | Read structured recent events and Health Findings | Implements `FR-031` and applies `QR-012` |
| `Export-LaunchTreeSupportBundle` | Export support evidence | Implements `FR-028` and supports `ShouldProcess` |
| `Clear-LaunchTreeCache` | Discard cached icons | Supports `ShouldProcess`; implements `FR-034` |
| `New-LaunchTreeShortcut` | Create a user-owned shortcut to an Entry Root | Supports `ShouldProcess`; implements `FR-035` |
| `Remove-LaunchTree` | Remove Generated State | Supports `ShouldProcess`; implements `FR-024` |

No version 1 public command creates, edits, renames, moves, or deletes source
content.

## Acceptance scenarios

| ID | Scenario | Expected result |
| --- | --- | --- |
| AS-001 | Managed Root contains `OneLevel` and `TwoLevel`; Reconciliation runs | Two Start Entries exist and open their corresponding Entry Roots |
| AS-002 | `TwoLevel` contains a Menu Folder containing another Menu Folder | The user navigates both levels in one window and returns with Back |
| AS-003 | A valid `.lnk` contains arguments and a working directory | Windows Shell invokes the `.lnk` without reconstructed parameters |
| AS-004 | A valid HTTPS `.url` and an invalid non-HTTP(S) `.url` coexist | The HTTPS Launch Item appears; the invalid file is excluded and reported |
| AS-005 | Managed and Personal content have equal visible names | Both objects appear with distinct Content Sources |
| AS-006 | `description.txt` contains UTF-8 multiline text | Hover shows wrapped multiline text without changing layout |
| AS-007 | A Launch Item fails in Windows Shell | The Launcher remains open with an inline error and unchanged navigation state |
| AS-008 | Reconciliation encounters an unowned Start shortcut collision | The transaction fails and restores the previous Generated State |
| AS-009 | Right-click occurs on every Launcher object type | No activation or context menu occurs |
| AS-010 | The same user activates another Start Entry while open | The existing Launcher focuses and switches Entry Root |
| AS-011 | A reparse point and content beyond maximum depth exist below an Entry Root | Neither boundary is traversed and each exclusion produces a Health Finding |
| AS-012 | A Support Bundle includes evidence for an argument-bearing `.lnk` and query-bearing `.url` | The archive contains neither arguments nor URL query strings |
| AS-013 | A standard user launches a failing item after elevated Reconciliation | Event `1201` is written to and read from the dedicated log without elevation |
| AS-014 | Entry Root names contain spaces, quotes-like shell metacharacters, Unicode, and PowerShell syntax text | Start Entries pass only opaque Entry IDs and open the correct Entry Roots without code evaluation |
| AS-015 | Configuration uses an unsupported future schema version | Reconciliation refuses mutation and the Launcher shows an incompatible-configuration error |
| AS-016 | Configuration and diagnostic commands run before any user preference file exists | Both commands return structured, redacted objects and create no files |
| AS-017 | Touch press-and-hold occurs on each Launcher object type | No activation or context menu occurs |
| AS-018 | Machine configuration omits `LauncherLayout` for an Entry Root with descriptions, nested Menu Folders, and Launch Items | The Launcher shows descriptions above Menu Folder tabs and renders Launch Items as compact rows with no sort selector or search box; selecting `Grid` restores the tile presentation |
| AS-019 | An Entry Root contains an empty Menu Folder, a Menu Folder holding only empty Menu Folders, and a Menu Folder whose only Launch Item is nested two levels deep | Only the Menu Folder with nested content and its populated ancestors are displayed |
| AS-020 | A `TabbedList` Entry Root holds populated Menu Folders but no Launch Item of its own | The Entry Root has no tab of its own and the first Menu Folder tab is selected with its Launch Items |
| AS-021 | The Managed Root is a DFS namespace folder whose Entry Roots are DFS links to hidden shares | Every Entry Root is discovered and its content is traversed through the referral |
