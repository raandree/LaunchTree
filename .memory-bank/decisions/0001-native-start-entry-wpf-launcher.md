---
id: ADR-0001
status: accepted
date: 2026-07-28
last-verified: 2026-07-28
owner: developer-and-release-owner
source: signed Design Concept
---

# ADR-0001: Use native Start Entries to open a WPF Launcher

## Context

Windows does not expose a supported PowerShell/WPF extension point for custom
content inside the Windows 11 Category view. The required depth exceeds native
Start organization.

## Decision

Create ordinary machine-wide Start Entries with high-resolution folder icons.
Each Start Entry opens a separate WPF Launcher at one Entry Root. Right-click
suppression applies only inside the Launcher because Windows owns native Start
interaction.

## Consequences

- The solution uses supported Start shortcut behavior.
- The Launcher can provide arbitrary bounded depth and custom interaction.
- The native Start Entry cannot behave exactly like an expandable Windows
  folder row.
- Visual acceptance compares the Launcher with Windows references without
  claiming in-process native integration.

## Requirements

- `FR-003`
- `FR-010` through `FR-017`
- `QR-008` through `QR-010`

## Alternatives considered

- Native Category injection: rejected because there is no supported contract.
- Native Programs subdirectories only: rejected because recursive presentation
  is insufficient.
- One Start Entry for all content: rejected because each Entry Root must be an
  independent Start target.
