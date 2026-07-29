# Open issues

This register is the repository source of truth for unresolved decisions,
external validation, and release blockers. GitHub issues may mirror these rows
later, but a remote issue number does not replace the `OI-###` identity.

## Workflow

| State | Meaning |
| --- | --- |
| Open | Work is understood and can proceed |
| In progress | An owner is actively collecting the closure evidence |
| Blocked | Closure depends on unavailable access, hardware, or an external decision |
| Resolved | Closure evidence is linked in the issue record |
| Deferred | Explicitly excluded from the current release by an accepted decision |

Every issue must have one owner, priority, affected release gate, next action,
and objective closure evidence. High-priority Open or Blocked issues prevent a
production-ready release. Updates append a dated note to the issue record and
update the summary table.

## Summary

| ID | Title | Priority | State | Owner | Release gate |
| --- | --- | --- | --- | --- | --- |
| `OI-001` | Select and validate Windows Server matrix | High | Blocked | Developer and release owner | Windows Server compatibility |
| `OI-002` | Validate Windows 11 and PowerShell 7 on ARM64 | High | Blocked | Developer and release owner | ARM64 compatibility |
| `OI-003` | Define configuration paths and schemas | Medium | Resolved | Developer and release owner | Configuration contract |
| `OI-004` | Define event source and event IDs | Medium | Resolved | Developer and release owner | Observability contract |
| `OI-005` | Define cache size and eviction | Medium | Resolved | Developer and release owner | Performance and rollback |
| `OI-006` | Capture visual baselines at three DPI settings | High | Open | Developer and release owner | Visual acceptance |
| `OI-007` | Validate clean GPO and file-copy deployment | High | Resolved | Developer and release owner | Offline deployment |
| `OI-008` | Exercise FullLanguage application-control guidance | High | Open | Developer and release owner | Enterprise policy compatibility |
| `OI-009` | Validate standard-user event-log access | High | In progress | Developer and release owner | Operational diagnostics |
| `OI-010` | Implement Generated State migration before schema version 2 | Medium | Open | Developer and release owner | Upgrade and downgrade compatibility |

## Issue records

### OI-001: Select and validate Windows Server matrix

- State: Blocked
- Priority: High
- Owner: Developer and release owner
- Release gate: Windows Server compatibility
- Source: Design Concept open question 1; `QR-001`
- Blocker: Required Windows Server releases and test hosts are not identified.
- Next action: Developer and release owner selects supported releases and
  Desktop Experience or session-host variants.
- Closure evidence: Named matrix plus passing acceptance results for each row.
- History: 2026-07-28 - Created from the signed Design Concept.

### OI-002: Validate Windows 11 and PowerShell 7 on ARM64

- State: Blocked
- Priority: High
- Owner: Developer and release owner
- Release gate: ARM64 compatibility
- Source: Design Concept open question 2; `QR-001`, `QR-002`
- Blocker: No physical or hosted ARM64 test environment is identified.
- Next action: Provision or nominate an ARM64 acceptance host.
- Closure evidence: Passing module import, Launcher, Reconciliation, invocation,
  and removal evidence on native ARM64.
- History: 2026-07-28 - Created from the signed Design Concept.

### OI-003: Define configuration paths and schemas

- State: Resolved
- Priority: Medium
- Owner: Developer and release owner
- Release gate: Configuration contract
- Source: Design Concept open question 3
- Resolution: `ADR-0006` and `CR-001` through `CR-008` define version 1 paths,
  schemas, and ownership state.
- Closure evidence: Accepted
  [configuration specification](specifications/configuration.md).
- History: 2026-07-28 - Resolved before implementation.

### OI-004: Define event source and event IDs

- State: Resolved
- Priority: Medium
- Owner: Developer and release owner
- Release gate: Observability contract
- Source: Design Concept open question 4
- Resolution: `ADR-0006` and `CR-010` reserve the `LaunchTree` log,
  source, ranges, and initial event IDs.
- Closure evidence: Accepted
  [configuration specification](specifications/configuration.md#cr-010-event-ranges).
- History: 2026-07-28 - Resolved before implementation.

### OI-005: Define cache size and eviction

- State: Resolved
- Priority: Medium
- Owner: Developer and release owner
- Release gate: Performance and rollback
- Source: Design Concept open question 5
- Resolution: `ADR-0006` and `CR-009` select a versioned 64 MB
  least-recently-used cache with 30-day maximum age.
- Closure evidence: Accepted
  [configuration specification](specifications/configuration.md#cr-009-cache-policy).
- History: 2026-07-28 - Resolved before implementation.

### OI-006: Capture visual baselines at three DPI settings

- State: Open
- Priority: High
- Owner: Developer and release owner
- Release gate: Visual acceptance
- Source: `QR-008`, `QR-009`
- Next action: Implement the Launcher and capture reference screenshots at
  100%, 150%, and 200% scaling in light, dark, and high-contrast modes.
- Closure evidence: Reviewed screenshots with no clipping, overlap, blank
  content, off-screen placement, or low-resolution icons.
- History: 2026-07-28 - Created as a release gate.
- History: 2026-07-28 - Added a validated dark-theme capture at the current
  display scale; 100%, 150%, 200%, light, and high-contrast matrix remains open.

### OI-007: Validate clean GPO and file-copy deployment

- State: Resolved
- Priority: High
- Owner: Developer and release owner
- Release gate: Offline deployment
- Source: `QR-019`
- Resolution: `tools/Test-OfflineLifecycle.ps1` copies only the built module to
  a disposable module path and runs Reconciliation, health, WPF capture, and
  removal without PSGallery or runtime dependencies.
- Closure evidence: Version `0.2.0`; one Start Entry added; health `Healthy`;
  32,985-byte Launcher capture; removal succeeded; runtime dependencies `0`.
- History: 2026-07-28 - Created as a release gate.
- History: 2026-07-28 - Resolved with the isolated file-copy lifecycle tool.

### OI-008: Exercise FullLanguage application-control guidance

- State: Open
- Priority: High
- Owner: Developer and release owner
- Release gate: Enterprise policy compatibility
- Source: `QR-003`
- Next action: Test the documented AppLocker or WDAC allowlisting path and prove
  that health reports Constrained Language Mode clearly.
- Closure evidence: Policy configuration, passing allowed run, and actionable
  blocked-run Health Finding.
- History: 2026-07-28 - Created as a release gate.

### OI-009: Validate standard-user event-log access

- State: In progress
- Priority: High
- Owner: Developer and release owner
- Release gate: Operational diagnostics
- Source: `QR-021`, `ADR-0009`
- Next action: Register the dedicated log through elevated Reconciliation, then
  execute the write/read probe as a non-elevated interactive user on each
  supported Windows family and PowerShell edition.
- Closure evidence: Recorded `CustomSD`, source ownership, probe event ID, and
  successful standard-user read/write transcript for every matrix row.
- History: 2026-07-28 - Created from independent reader finding B1.
- History: 2026-07-28 - Implemented Interactive Users SDDL validation and a
  linked standard-user token nonce write/read probe; external elevated matrix
  execution remains required for closure.
- History: 2026-07-28 - Reproduced the probe on a UAC-split interactive elevated
  admin (Windows client): it fails. `CreateProcessWithTokenW` is fed the
  `TokenLinkedToken`, which returns as an `Identification`-level impersonation
  token and is rejected with `ERROR_ACCESS_DENIED` (5), surfacing through
  `Initialize-QuickStart.ps1` as `StartEntryAction=Failed`. `DuplicateTokenEx`
  to a primary token also fails (`ERROR_BAD_IMPERSONATION_LEVEL`, 1346) because
  the level cannot be raised without `SeTcbPrivilege` (SYSTEM only). The linked-
  token de-elevation technique is therefore unusable from an interactive admin;
  redesign the probe (unelevated shell or Task Scheduler) and make it a Health
  Finding rather than a fatal Reconciliation error.
- History: 2026-07-28 - Implemented the best-effort fix:
  `Invoke-LaunchTreeStandardUserEventProbe` returns a structured result via a
  mockable `Invoke-LaunchTreeUnelevatedProcess` seam, `Register-LaunchTreeEventLog`
  warns and emits event `1603` without aborting, and `Test-LaunchTree` raises the
  `StandardUserEventAccessUnverified` finding. QuickStart now reconciles the Start
  Entry and reports `Degraded`. A real de-elevated standard-user write/read path
  and the external elevated matrix remain required for closure.

### OI-010: Implement Generated State migration before schema version 2

- State: Open
- Priority: Medium
- Owner: Developer and release owner
- Release gate: Upgrade and downgrade compatibility
- Source: `FR-025`, `QR-017`, independent final review nit
- Next action: Before introducing Generated State schema version 2, add a
  version-1 migration path, supported downgrade evidence, and visible Launcher
  handling for an unsupported Generated State schema.
- Closure evidence: Red-green migration and downgrade tests plus an isolated
  file-copy upgrade transcript that preserves source content and owned Start
  Entries.
- History: 2026-07-28 - Created before the initial schema has a predecessor to
  migrate.
