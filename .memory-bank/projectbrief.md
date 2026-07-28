---
status: current
last-verified: 2026-07-28
owner: shared
source: repository evidence
---

# Project brief

## Purpose

Provide recursively navigable Start menu content through native Windows Start
shortcuts that open a PowerShell/WPF launcher.

## Scope

- In scope: A Windows-only Sampler module, managed and personal shortcut trees,
  WPF navigation, shortcut reconciliation, health checks, and diagnostics.
- Out of scope: Native Windows 11 Category injection, content editing, online
  services, self-update, and platform-specific installer packages.

## Stakeholders

- Developer and release owner.
- Deployment and content automation owners.
- Managed employees and personal users.

## Acceptance criteria

1. Two native Start entries open independent WPF roots.
2. One acceptance root navigates one level and another navigates at least two.
3. Valid `.lnk` and HTTP(S) `.url` items launch through Windows Shell.
4. Required descriptions, DPI-aware icons, navigation, search, theme, input,
   failure, performance, and rollback behavior passes the signed-off design.
