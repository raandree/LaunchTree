---
status: current
last-verified: 2026-07-28
owner: shared
source: repository evidence
---

# Product context

## Problem

The native Start menu does not provide the required recursive organization for
centrally deployed shortcut trees.

## Users

- Managed employees on centrally administered Windows devices.
- Personal users who may augment managed entries with a roaming overlay.
- Administrators and automation that deploy and diagnose the module.

## Core workflows

1. Automation copies or installs the module and reconciles first-level Start
   shortcuts from a managed directory tree.
2. A standard user opens a folder-icon Start shortcut and navigates nested WPF
   folders.
3. The user searches, selects an item, and Windows Shell invokes the shortcut.
4. An operator validates health or exports a redacted support bundle.

## Experience goals

- Feel visually consistent with Windows 11 while remaining a separate WPF UI.
- Respond quickly, retain stable layout during icon loading, and work with
  keyboard, touch, light/dark themes, high contrast, and mixed DPI.
- Keep errors local and actionable without making healthy content unusable.
