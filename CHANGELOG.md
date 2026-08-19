# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Add `Clear-LaunchTreeCache`, which discards every cached icon in the resolved
  cache namespace, supports `ShouldProcess`, keeps the namespace directory, and
  reports the entry count and bytes reclaimed; a cache key covers only the
  shortcut, so repairing or deploying an icon target could previously not
  invalidate the stale entry before `Cache.MaximumAgeDays` expired it. It is
  also reachable as `-Command ClearCache` in both single-file deliveries,
  including `LaunchTree.Minimal.ps1`, whose embedded set is now derived from the
  `Show-LaunchTree` and `Clear-LaunchTreeCache` call graphs
- Add a LaunchTree application icon that appears at the left of the Launcher
  title bar, in the taskbar, and in Alt+Tab; `source/Assets/LaunchTree.ico` is
  the source of truth and the icon is embedded in the module so the single-file
  deliveries stay self-contained
- Add the repository governance files required for a public release: an MIT
  `LICENSE`, a `SECURITY.md` policy that documents private vulnerability
  reporting and the intended security boundaries, a `CONTRIBUTING.md`
  development guide, and a `CODEOWNERS` default owner; the module manifest now
  states the MIT copyright and publishes `LicenseUri` and `ProjectUri`
- Add drag-to-move for the Launcher window: pressing and dragging the header
  moves the window, and the resulting position is remembered and restored on the
  next activation, clamped to the virtual screen so it stays reachable on any
  connected monitor
- Add `ManagedRoot` and `PersonalRoot` parameters to
  `Get-LaunchTreeConfiguration`, `Show-LaunchTree`, `Test-LaunchTree`, and
  `Export-LaunchTreeSupportBundle` so one invocation can read menu content from
  a location other than the configured roots; an override must be an absolute
  path and is rejected instead of silently falling back
- Add a `TabbedList` Launcher layout with Menu Folder tabs, the active
  description above the tabs, and compact Launch Item rows and no sort selector
  or search box; it is the default presentation, and `LauncherLayout` selects
  `Grid` for the tile layout
- Add a generated single-file `LaunchTree.ps1` delivery that contains the whole
  module logic, runs without installing a module, supports dot-sourcing and
  `-Command` dispatch, and points its Start Entries at the script itself; the
  module delivery is unchanged
- Add a generated `LaunchTree.Minimal.ps1` delivery for hosts that only open the
  Launcher: the build derives it from the `Show-LaunchTree` call graph, so it
  embeds only the functions that call needs and exposes only `-Command Show`,
  `-EntryName`, and `-ManagedRoot`; comments and the blank lines they leave are
  removed under a token-equivalence check, the Event Log and every JSON reader
  are replaced by overrides under `tools/MinimalVariant`, and the full
  single-file script keeps its comment-based help and is otherwise unchanged
- Add a setup script that writes a default machine configuration, creates a
  sample Entry Root of built-in Windows Launch Items, and reconciles its Start
  Entry for a faster first run
- Add a getting-started guide for installation, first content, Reconciliation,
  health verification, Launcher use, and cleanup
- Add structured health, redacted Event Log diagnostics, Support Bundle export,
  and ownership-only Generated State removal
- Add operational Event Log emission for configuration, content, launch,
  Reconciliation, cache, performance, and Support Bundle failures
- Add the session-local WPF Launcher with recursive navigation, global search,
  localized sorting, keyboard/touch controls, high-resolution Shell icons,
  bounded icon caching, persisted presentation preferences, system themes,
  hover descriptions, and right-click suppression
- Add transactional Start Entry Reconciliation with opaque Entry IDs,
  ownership records, collision protection, rollback, and event-log provisioning
- Add Shell-native `.lnk` and `.url` invocation with typed failure results
- Add recursive Content Snapshot discovery with Managed and Personal Content
  Sources, depth boundaries, descriptions, validated `.lnk`/`.url` items, and
  omission of Menu Folders whose subtree holds no Launch Item
- Add read-only effective configuration with validated machine settings, user
  preferences, defaults, and structured Health Findings
- Add the initial Sampler module structure, signed specifications, accepted
  decisions, canonical glossary, and managed issue register

### Changed

- Hide Content Source metadata from compact Launcher rows; a Launch Item or
  Menu Folder without a description now shows no subtitle instead of
  `Managed`, `Personal`, or `Managed+Personal`
- Move the selected Menu Folder description out of the window title bar into its
  own `TabbedList` field between the title bar and the navigation strip; the
  field always reserves two lines so the tab strip stays put whichever tab is
  selected, and a longer description is truncated with an ellipsis and stays
  readable in full as the field's tooltip
- Present the Launcher's compact top line as a window title bar: the
  application icon and the Entry Root title now sit at its left where the Back
  control used to be, and Back moved to the left of the `TabbedList` tab strip
- Fit the `TabbedList` window width to the tab strip so the tabs no longer
  scroll horizontally; the width grows to the required size within 80 percent of
  the work area, never shrinks below the width the user chose, and an automatic
  fit is not stored as a user dimension
- Drop the item count from the `TabbedList` status line and collapse that line
  unless it carries an error; `Grid` still reports its item and result counts
- Reduce the Launcher header to a single compact line holding Back, the title,
  the active description, and Close; the breadcrumb and the separate description
  line are gone, the current path is now the title tooltip, and the header and
  `TabbedList` tab strip use title-bar-height padding
- Hide the `TabbedList` tab of the Entry Root or Menu Folder that the tab strip
  belongs to while it holds no Launch Item of its own, and select its first
  child Menu Folder tab instead, so opening a folder that only groups
  subfolders no longer starts on an empty tab
- Keep the `TabbedList` tab strip visible when a Menu Folder tab is selected;
  a tab now highlights and opens its Launch Items in place instead of replacing
  the tab strip with that folder's children, and a Menu Folder below the
  selected tab appears as a list row that moves the tab strip one level deeper
- Reject a parameter that the selected `-Command` of the single-file
  `LaunchTree.ps1` does not accept instead of silently discarding it, so a
  misapplied path no longer runs the command against the default location
- Restyle the Launcher sort selector to match the window theme with a rounded
  surface, themed border and chevron, hover, open, and keyboard focus states,
  and a themed drop-down list with an accent bar on the selected order
- Rename the module, all seven commands, ProgramData and roaming paths, machine
  configuration and Generated State file names, the Event Log name and source,
  and the exported type names from `StartMenuFolders` to `LaunchTree`
- Scope dedicated-test and help QA gates to exported commands while retaining
  PSScriptAnalyzer coverage for private helpers
- Document how to open the Launcher with `Show-LaunchTree`, how to import the
  built module without installing it, and how to resolve the related failures
- Document the single-file `LaunchTree.ps1` delivery in the getting-started
  guide, the README, and the troubleshooting guide, covering dot-sourcing,
  `-Command` dispatch, the setup-script `-SkipReconciliation` path, and the
  script-path failure modes
- Document PSGallery, GPO, and file-copy deployment plus operational
  troubleshooting and example machine configuration

### Fixed

- Show the LaunchTree application icon on the Launcher taskbar button instead
  of the PowerShell host icon by assigning a per-window AppUserModelID when WPF
  creates the native window
- Fix a raw `Test-Path` access-denied error reaching the console when a Menu
  Folder below the Managed Root, such as a DFS link whose target the signed-in
  user may not read, denies list or traverse access. Probing the folder's
  `description.txt` wrote an uncaught `ItemExistsUnauthorizedAccessError` to the
  error stream before the Launcher opened. The probe is now handled like every
  other unreadable path and is reported as a `DescriptionUnavailable` Health
  Finding, and probing an inaccessible Managed Root or Personal Root no longer
  writes a raw error alongside its finding
- Fix internet shortcut (`.url`) Launch Items silently disappearing from the
  Launcher when any line of the file is not valid UTF-8. Windows writes `.url`
  files in the system ANSI code page, so a non-ASCII character in a field the
  menu never reads, such as `IconFile`, made the strict UTF-8 read throw and the
  whole shortcut was dropped with a `LaunchItemInvalid` Health Finding. The
  reader now falls back to the ANSI code page when the strict UTF-8 decode
  fails; the `http`/`https` scheme check is unchanged
- Fix a Managed Root on a DFS namespace finding no Entry Roots. A DFS link is a
  directory reparse point, and every reparse point was skipped to prevent cycles
  and root escape, so Entry Roots published as DFS links were invisible and
  `Show-LaunchTree` reported `Entry Root '<name>' was not found`. Traversal now
  reads the reparse tag and admits only `IO_REPARSE_TAG_DFS` and
  `IO_REPARSE_TAG_DFSR`; junctions, symbolic links, and mount points are still
  ignored and still reported as Health Findings
- Fix internet shortcut (`.url`) Launch Items showing the generic file icon
  instead of the target site or browser icon; the shell handler that produces
  that icon only answers on an STA thread, so background icon extraction now
  runs on a dedicated STA worker instead of a thread-pool thread, and the icon
  cache key was versioned so entries poisoned by the fallback icon are discarded
- Fix the Launcher window's top edge rendering about five times thicker than
  the other three. A borderless resizable window keeps its top resize border
  inside the visible frame while the other three sit in the invisible drag
  margin, so the window now applies a `WindowChrome` with no caption height and
  no glass frame; the client area is flush with all four edges and a four-pixel
  band still resizes the window
- Fix the `Grid` layout failing to open a Menu Folder because it assigned the
  current path to a breadcrumb control that no longer exists; both layouts now
  expose the current path through the title tooltip
- Fix diagnostic writes registering the `LaunchTree` event source in the
  `Application` log when an elevated session wrote an event before
  Reconciliation had created the dedicated log, which then failed permanently
  with "Event source 'LaunchTree' is owned by log 'Application'"; runtime writes
  now verify the registration first and skip the write instead of creating a
  source, and the registration conflict reports how to remove a stray source
- Fix elevated Reconciliation aborting with "Could not start the standard-user
  probe process" when the de-elevated Event Log probe cannot launch (an
  interactive elevated admin whose linked token is only `Identification`
  level); the probe now returns an unverified result, emits warning event
  `1603`, and surfaces a `StandardUserEventAccessUnverified` Health Finding
  while still registering the log and its Interactive Users access
- Fix the getting-started Entry Root sample so it resolves the effective
  configuration itself, stops at the first error, and releases the shell COM
  object even when shortcut creation fails
- Fix Windows command-line escaping for trailing backslashes and plus signs
- Return structured `Unhealthy` status and a visible Launcher error for future
  configuration schemas while refusing Reconciliation mutation
- Merge matching Managed and Personal Menu Folders into one navigable folder
- Bound Menu Folder description metadata to 64 KB before allocation

### Security

- Validate the Interactive Users Event Log ACL and run a nonce write/read probe
  through the elevated account's linked standard-user token before commit
- Add tests for reparse exclusion, Generated State containment, URL scheme
  revalidation, redaction, and opaque Entry ID command-line boundaries
