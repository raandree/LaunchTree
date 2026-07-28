# Quality requirements

> Status: Accepted
> Version: 1
> Source: [Signed Design Concept](../design-concept.md)

This specification defines nonfunctional release gates. A requirement remains
Blocked, not waived, when the required environment is unavailable.

## Compatibility

### QR-001 Windows editions

The runtime must support current Windows 10 x64, Windows 11 x64 and ARM64, and
the Windows Server variants selected by `OI-001`. Unsupported platforms must
fail with an actionable platform error before modifying state.

### QR-002 PowerShell editions

Public commands must support Windows PowerShell 5.1, PowerShell 7 x64, and
PowerShell 7 ARM64. The module manifest must declare PowerShell 5.1 as its
minimum version and must not depend on PowerShell 7-only syntax or APIs.
PowerShell 7 supports long paths when Windows long-path policy is enabled.
Windows PowerShell 5.1 remains subject to its .NET Framework host limit and must
report inaccessible long-path content as a Health Finding.

### QR-003 Application control

The Launcher requires FullLanguage. Documentation and health checks must state
that `-ExecutionPolicy Bypass` does not bypass Constrained Language Mode,
AppLocker, or WDAC. Acceptance under representative policy remains tracked by
`OI-008`.

## Performance and scale

### QR-004 Supported scale

The supported maximum is 1,000 visible objects across no more than 50 Entry
Roots, with a default maximum depth of five.

### QR-005 Startup budget

Cold activation must display a usable first view in less than 500 ms on the
documented reference device. Icon loading and global search indexing may
continue afterward without blocking navigation.

### QR-006 Interaction budget

Opening an already-discovered Menu Folder and filtering a ready search index
must each complete in less than 100 ms at supported scale.

### QR-007 Memory budget

One Launcher process must remain below a 200 MB peak working set during the
1,000-object acceptance fixture.

## Visual and interaction quality

### QR-008 DPI and layout

The Launcher must pass screenshot review at 100%, 150%, and 200% scaling. Fixed
format controls must retain stable dimensions, text must not overlap or clip,
icons must remain crisp, and the window must remain in the active work area.

### QR-009 Theme and contrast

Light, dark, and Windows high-contrast modes must preserve readable text,
visible focus, distinguishable selection, and meaningful icon fallback.

### QR-010 Input behavior

All primary workflows must be possible by keyboard and touch. Right-click and
touch press-and-hold must have no effect inside the Launcher. Automated
interaction tests and a manual touch review must cover these behaviors.

## Security and privacy

### QR-011 Least privilege

The Launcher must run as a standard user. Reconciliation and event-source
registration may require an administrator and must support `ShouldProcess`.
Source content must never be modified by a public command.

### QR-012 Redaction

Logs, Health Findings, and Support Bundles may contain source paths and error
codes. They must omit Launch Item arguments, URL query strings, secrets, and
successful user activity.

### QR-013 Offline operation

The module must perform no network request for metadata, icons, updates, or
telemetry. Network access may occur only after Windows Shell invokes a user-
selected Launch Item.

### QR-014 Input boundaries

Configuration values, paths, JSON, directory traversal, `.url` schemes, cache
records, and ownership records must be validated before use. Directory reparse
points must not cross the Managed Root or Personal Root boundary.

## Reliability and rollback

### QR-015 Transactional Reconciliation

Fault-injection tests must prove rollback after failure at every state-changing
step. No test may weaken an assertion or suppress an error to obtain a green
result.

### QR-016 Idempotence

Running Reconciliation twice against unchanged content must produce no second
state change. Health and removal commands must also be repeatable.

### QR-017 Compatibility window

Generated State supports one previous major schema. Cache namespaces are
version-isolated. Upgrade and supported-downgrade tests must preserve source
content and restore compatible Generated State.

## Build and deployment

### QR-018 Sampler build

The repository must use the canonical Sampler structure, explicit function
exports, GitVersion, Pester 5, PSScriptAnalyzer, and a detached build process.
The full build must pass on Windows PowerShell 5.1 and PowerShell 7 x64.

### QR-019 Offline artifact

The built module must run after a plain file copy to a clean target with no
PSGallery access and no unresolved runtime module dependency. A GPO-style
deployment test must exercise install, Reconciliation, health, and removal.

### QR-020 Documentation

The module must include command help, configuration examples, GPO/file-copy
deployment guidance, and troubleshooting for missing Start Entries, failed
invocation, icon/cache issues, policy blocks, and Support Bundle collection.

## Operational diagnostics

### QR-021 Standard-user event access

On every supported Windows test platform, elevated Reconciliation must register
the dedicated event log and a standard interactive user must write and read a
probe event using the same cross-edition APIs as the Launcher and health
commands. Source-name collisions and invalid access descriptors must fail
before Start Entry mutation.

### QR-022 Long-path compatibility

PowerShell 7 acceptance must cover content beyond legacy `MAX_PATH` with the
Windows policy enabled. Windows PowerShell 5.1 acceptance must prove that the
same content is excluded with an actionable Health Finding and does not hide
healthy siblings.

## Release evidence

| Gate | Evidence | Issue |
| --- | --- | --- |
| Functional | Pester tests mapped to every `FR-###` and `AS-###` | None |
| Configuration | Schema/default/invalid-input tests mapped to every `CR-###` | None |
| Static quality | PSScriptAnalyzer and module QA tests pass | None |
| Windows Server | Selected server matrix passes | `OI-001` |
| ARM64 | Windows 11 and PowerShell 7 ARM64 acceptance passes | `OI-002` |
| Visual | Screenshots at three DPI settings pass review | `OI-006` |
| Offline deployment | Clean GPO/file-copy fixture passes | `OI-007` |
| Application control | FullLanguage allowlisting guidance is exercised | `OI-008` |
| Standard-user event access | Dedicated-log write/read probe passes on the supported matrix | `OI-009` |
| Build | Detached Sampler build and package workflow pass | None |

A production-ready release must have no Open or Blocked High-priority issue in
the [open-issues register](../open-issues.md).
