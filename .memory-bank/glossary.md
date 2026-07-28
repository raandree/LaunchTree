---
status: accepted
last-verified: 2026-07-28
owner: shared
source: signed Design Concept
---

# Glossary

These terms are the canonical language for code, tests, documentation, event
messages, and support material.

| Term | Means | Don't say |
| --- | --- | --- |
| LaunchTree | The product, the PowerShell module, and the command noun prefix. | StartMenuFolders, Start Menu Folders, the LaunchTree app |
| Managed Root | The machine-wide directory whose immediate child directories are Entry Roots. | managed content root, machine root, source root |
| Personal Root | The roaming per-user directory whose matching paths augment the Managed Root. | personal overlay, user root |
| Entry Root | An immediate child directory of the Managed Root represented by one Start Entry. | first-level folder, top-level folder |
| Entry ID | An opaque GUID that maps one Start Entry to one Entry Root through the ownership record. | entry name, folder argument |
| Start Entry | A module-owned native Windows Start shortcut that opens an Entry Root in the Launcher. | launcher shortcut, menu entry |
| Menu Folder | A directory at or below an Entry Root that the Launcher displays as navigable content. | submenu, nested menu |
| Launch Item | A valid `.lnk` or HTTP(S) `.url` file displayed and invoked by the Launcher. | app item, shortcut item |
| Launcher | The WPF user interface that displays Menu Folders and Launch Items. | gallery, custom Start menu |
| Launcher Host | The validated Windows PowerShell or PowerShell 7 executable used by a Start Entry to run the Launcher bootstrap. | LauncherHost, PowerShell host |
| Content Source | The Managed or Personal origin of a Menu Folder or Launch Item. | layer, provider |
| Content Snapshot | The immutable merged view read for one Launcher activation. | live tree, cached tree |
| Reconciliation | The all-or-nothing operation that makes Generated State match current Entry Roots. | synchronization, refresh |
| Generated State | Start Entries, ownership records, event registration, and cache metadata owned by the module. | installed content, deployment state |
| Health Finding | A structured configuration, content, compatibility, performance, or operational result. | warning record, check result |
| Support Bundle | A redacted archive of configuration summaries, Generated State inventory, cache metadata, and relevant events. | diagnostics dump, log bundle |
