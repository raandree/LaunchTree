# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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
  removed under a token-equivalence check, and the full single-file script keeps
  its comment-based help and is otherwise unchanged
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
