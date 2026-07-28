# Design Concept: StartMenuFolders

> Status: DRAFT — awaiting user sign-off
> Interview conducted: 2026-07-28
> Override log: empty

## Purpose

StartMenuFolders extends the practical depth of the Windows Start experience
without attempting to inject custom content into the Windows 11 Category view.
Each immediate child directory of a managed content root is represented by an
ordinary machine-wide Start shortcut with a high-resolution folder icon. The
shortcut opens a PowerShell/WPF launcher rooted at that directory.

The launcher provides recursive navigation beyond the depth supported by the
native Start menu. Version 1 is successful when a deployment can demonstrate
two native Start entries: one opens a one-level launcher and one opens content
with at least two navigable levels. Every valid item launches through Windows
Shell, folder and item descriptions appear on hover, icons remain crisp across
supported DPI settings, and right-click has no effect inside the WPF window.

## Scope

- Deliver a Windows-only PowerShell module built with Sampler and tested with
  Pester.
- Support Windows 10 x64, Windows 11 x64 and ARM64, and Windows Server with a
  graphical desktop environment.
- Support Windows PowerShell 5.1, PowerShell 7 x64, and PowerShell 7 ARM64.
- Publish the module to PSGallery while also producing a self-contained built
  module that can be deployed without network access by GPO or plain file copy.
- Create and reconcile machine-wide native Start shortcuts from immediate
  child directories of the managed root. Reconciliation is explicit and
  deployment-triggered.
- Keep source content read-only. The module inspects it and manages only its
  own generated shortcuts, configuration state, event source, and caches.
- Open one WPF process per signed-in user. A later activation reuses the
  existing window and switches it to the requested entry.
- Navigate nested directories in the same window with Back and breadcrumb
  affordances.
- Provide global type-to-search across all configured entries.
- Follow Windows light, dark, and high-contrast settings.
- Place the window near the Start button, fit it to content within screen
  bounds, permit resizing, and scroll when necessary.
- Support keyboard navigation, touch interaction, and visible keyboard focus.
- Allow users to select locale-aware name ascending or name descending sort.
- Close after a successful launch by default, with a persisted option to keep
  the window open.
- Expose structured PowerShell commands to reconcile entries, show a launcher,
  test configuration and content health, and collect diagnostics.
- Provide troubleshooting guidance for missing entries, broken launches, icon
  failures, execution policy or application-control blocks, and support-bundle
  collection.

The first release acceptance review includes functional tests and screenshot
comparison against the supplied Windows references at 100%, 150%, and 200%
display scaling.

## Non-goals

- Injecting custom categories, tiles, or controls into the native Windows 11
  Category view.
- Suppressing the Windows-owned context menu of the native Start shortcut.
- Editing, creating, renaming, moving, or deleting managed or personal source
  content from the WPF launcher.
- Watching source directories or updating an open window when files change.
  Each process activation reads a new snapshot.
- Shipping an MSI, MSIX, Intune package, SCCM application, or product-specific
  GPO package in version 1.
- Self-update, update notifications, cloud services, online metadata lookup,
  or outbound telemetry.
- Supporting launchable executables, scripts, AppX discovery, ClickOnce, or
  other item types directly in version 1. A future provider boundary may add
  them without changing the directory model.
- Running the WPF launcher on Linux or macOS.
- Localizing module-owned UI strings beyond English in version 1. Content
  names and descriptions still support arbitrary Unicode.
- Screen-reader certification in version 1. High contrast, keyboard, and touch
  support remain required.
- Central alert definitions. The module emits stable events for a deployment's
  monitoring system to collect.

## Stakeholders

| Stakeholder | Responsibility |
| --- | --- |
| Developer and release owner | Approves releases, owns incidents, and accepts the visual comparison |
| Deployment automation | Installs or copies the module, supplies configuration and content, and invokes reconciliation |
| Content automation | Maintains managed directories, descriptions, and shortcut files |
| Managed employees | Browse and launch centrally supplied content as standard users |
| Personal users | Browse managed content and add permitted content through their roaming overlay |

Runtime browsing and launching must not require elevation. A selected shortcut
may still trigger its own Windows elevation behavior. Updates are performed
only by deployment automation.

## Inputs

### Managed paths and configuration

The default managed root is:

```text
C:\ProgramData\StartMenuFolders\StartMenuFolders
```

Setup accepts a `VendorName` that changes the pattern to:

```text
C:\ProgramData\<VendorName>\StartMenuFolders
```

An explicit machine JSON file stores root, presentation defaults, depth,
retention, and policy settings. It is separate from the content root so that
the root contains directories only. The module validates but never rewrites
administrator-authored JSON.

Deployment is responsible for permissions on managed files. The module trusts
that deployment prevents unintended standard-user modification; it does not
verify signatures or hashes for managed content.

### Personal overlay

The default roaming overlay is:

```text
%APPDATA%\<VendorName>\StartMenuFolders
```

The overlay augments corresponding managed entry directories. Version 1 does
not create machine-wide Start entries for personal-only top-level directories.
Within a matching entry, managed and personal directory trees merge by
relative path. Same-name items remain visible and carry a Managed or Personal
source indicator rather than replacing one another.

### Directory and item contract

- Every directory below an entry represents a visible menu folder.
- The managed root contains first-level entry directories, not loose items.
- `description.txt` is reserved metadata. It is UTF-8 plain text, surrounding
  whitespace is trimmed, and multiline content is preserved for a wrapped,
  size-capped tooltip.
- A folder label is its directory name.
- A `.lnk` or `.url` label is its filename without the extension.
- A `.lnk` tooltip uses the shortcut Description field when present.
- Only `.lnk` and `.url` are launchable in version 1.
- A `.url` is valid only when its URL uses `http` or `https`.
- Directory reparse points are ignored and never traversed.
- Default maximum depth is five, counting an entry directory as level 1. The
  machine JSON may set another bounded value.
- Paths beyond legacy `MAX_PATH` are supported when the operating system is
  configured for long paths.
- Names, descriptions, filtering, and sorting use Unicode and the signed-in
  user's locale.

Content is read as a snapshot on activation. Changes become visible on the
next activation; there is no file watcher.

## Outputs

### Native Start entries

Reconciliation creates one machine-wide native Start shortcut for every
immediate managed child directory. Each shortcut has a crisp folder icon,
opens the launcher at that entry, and carries the folder description where
Windows exposes shortcut descriptions. Removed or renamed source entries are
reconciled transactionally.

### WPF launcher

The launcher presents a responsive Windows 11-inspired grid using stable item
dimensions. Folders and links are sorted together by the selected name order.
Folder activation replaces the current view in the same window. Back and
breadcrumb navigation restore parent context. Empty folders remain visible and
open to an explicit empty state.

Search covers every configured entry and shows enough path and source context
to distinguish duplicate names. Right-click events are consumed throughout
the WPF content surface and never activate an item or open a context menu.
Windows may still show its normal context menu for the native Start shortcut.

Icons are requested at a resolution appropriate to the current DPI. The first
view may render stable placeholders while icons load asynchronously; replacing
a placeholder must not move surrounding content. Missing icons fall back to
the Windows Shell default for the target or file type. A bounded, versioned
per-user cache under LocalAppData stores extracted icons and parsed metadata.

Selecting a valid item asks Windows Shell to open the shortcut file itself.
The module does not reconstruct target invocation, preserving arguments,
working directory, show state, environment expansion, protocol handling, and
shortcut elevation semantics. A successful launch closes the window unless
the user preference says to keep it open.

Management and diagnostic commands emit structured PowerShell objects rather
than preformatted text. Human-oriented formatting is layered on those objects.

## Failure modes

| Failure | Required behavior |
| --- | --- |
| Managed root missing or inaccessible | Open a visible error state that identifies the diagnostic path |
| JSON missing, malformed, or partly invalid | Use safe defaults, report ignored settings, and log a warning |
| Broken or unreadable `.lnk` or `.url` | Hide only that item and log the failure |
| Unsupported `.url` scheme | Hide the item and log a policy failure |
| Unreadable or invalid `description.txt` | Keep the folder usable without a tooltip and log the metadata failure |
| Icon extraction failure | Display the Windows Shell fallback icon and log only when diagnostically useful |
| Shell launch failure | Show a nonmodal inline error, retain navigation state, and log the failure |
| Reconciliation failure | Restore the complete prior generated state and report an unsuccessful transaction |
| Cache corruption or incompatible version | Ignore the cache namespace, rebuild safely, and prune it later |

Warnings and failures go to a dedicated Windows Event Log. Successful item
launches are not audited.

## Edge cases

- Empty folders remain visible and navigable.
- A folder made empty by skipped invalid items uses the same empty state.
- Traversal stops at the configured depth and reports deeper content as a
  health finding.
- Junctions, symbolic links, mount points, and other directory reparse points
  are ignored to prevent cycles and root escape.
- Managed and personal duplicates remain visible with source attribution.
- Locale-aware, case-insensitive comparison governs sorting, filtering, and
  collision diagnostics.
- Long and multiline tooltips wrap and stay within capped screen dimensions;
  source metadata is not truncated on disk.
- Multiple activations converge on one process and one window per signed-in
  user. The newest activation selects the requested root.
- A snapshot remains internally consistent if automation changes source files
  while a window is open; changes appear on the next activation.
- Display scaling, mixed-DPI monitors, taskbar alignment, auto-hide taskbars,
  and reduced work areas must not place the window off-screen.

## Security

- The launcher runs as the signed-in standard user and does not elevate itself.
- Managed content and configuration trust the ACLs established by deployment.
- Personal overlay content is user-controlled and needs no target allowlist.
- `.lnk` files may target local, UNC, mapped-drive, or remote resources and are
  delegated to normal Windows Shell security behavior.
- `.url` files are limited to HTTP and HTTPS.
- WPF functionality takes priority over Constrained Language Mode support. The
  launcher requires FullLanguage; WDAC or AppLocker deployments must allow it
  explicitly.
- Generated launch commands use `-ExecutionPolicy Bypass` as required. This
  setting does not bypass WDAC, AppLocker, or Constrained Language Mode.
- Right-click suppression is an application interaction rule, not a security
  boundary.
- Logs may include source paths and error codes, but omit shortcut arguments,
  URL query strings, and successful user activity.
- Exported support bundles apply the same redaction and contain no secrets.
- The module performs no outbound telemetry or network lookup of its own.

## Performance

| Measure | Budget |
| --- | --- |
| Typical installation | Up to 50 entry directories and 1,000 total visible items |
| Supported maximum | 1,000 total visible items across managed and personal trees |
| Cold activation to usable first view | Less than 500 ms on ordinary enterprise hardware |
| Nested-folder navigation | Less than 100 ms after discovery |
| Filtering/search interaction | Less than 100 ms after the search index is ready |
| Process working set | Less than 200 MB |

Metadata discovery and icon extraction must not block the UI thread. Icon
loading is asynchronous and cache-backed. Global search indexing may continue
after the first view appears, but its progress must not block navigation or
resize the layout. Performance warning events are emitted only when documented
budgets are exceeded, not on every successful launch.

## Observability

The module owns a stable, documented Windows Event Log source with versioned
event IDs, levels, categories, and fields. Local retention targets 30 days and
a 25 MB size cap. There is no built-in central collector or alert rule.

One health command returns a top-level `Healthy`, `Degraded`, or `Unhealthy`
state plus actionable structured findings for:

- JSON and path validity
- depth, sorting, policy, and runtime compatibility
- missing, stale, duplicate, or unexpected generated Start shortcuts
- broken links, invalid URLs, collisions, and unreadable descriptions
- cache size, version, corruption, and icon failures
- recent relevant Event Log warnings and errors

A diagnostics command exports a redacted support bundle containing the
configuration summary, generated-state inventory, cache metadata, and relevant
events. It excludes target arguments and URL query strings. A human can verify
basic health within 30 seconds by running the health command and reading its
summary.

## Rollback

- Generated Start entries and module-owned state are reconciled as one
  transaction. Changes are staged and the previous state is retained until the
  new state commits successfully.
- Any mid-sync failure restores the complete prior generated state.
- Uninstall removes generated shortcuts, module-owned configuration state,
  event registration, and caches while preserving managed and personal content
  roots.
- A version reads and migrates generated configuration from one previous major
  schema version.
- Installing the previous supported module version automatically restores or
  migrates compatible generated state transactionally.
- Per-user caches use versioned namespaces. Older code ignores newer cache
  formats; maintenance later prunes abandoned namespaces.
- Reconciliation never rewrites administrator-authored JSON.
- The launcher mutates no source content, so user-facing undo is limited to
  normal Back navigation.

## Open questions

The following items do not change the product boundary but must be resolved
before claiming the corresponding compatibility or release gate:

1. Which Windows Server releases and Desktop Experience/session-host variants
   are in the supported test matrix?
2. Which physical or hosted ARM64 environment will run the Windows 11 ARM64 and
   PowerShell 7 ARM64 acceptance tests?
3. What exact names, paths, and JSON schema versions will be assigned to the
   machine configuration and per-user presentation-preference files?
4. What event source name and event-ID ranges will form the stable monitoring
   contract?
5. What cache size limit and eviction policy will satisfy the 200 MB process
   budget on the 1,000-item fixture?

These are implementation-detail TBDs. Sign-off accepts the behavior and
constraints in this document while requiring the TBDs to be closed and tested
before release.

## Sign-off

- [ ] User has read this document end to end.
- [ ] User accepts every section or has flagged required changes.
- [ ] User has typed `SIGNED OFF` (or equivalent) in chat.
