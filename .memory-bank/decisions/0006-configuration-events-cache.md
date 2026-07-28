---
id: ADR-0006
status: accepted
date: 2026-07-28
last-verified: 2026-07-28
owner: developer-and-release-owner
source: signed Design Concept and implementation defaults
---

# ADR-0006: Version configuration, events, and cache independently

## Context

The signed Design Concept left exact paths, schema names, event ranges, and
cache limits as implementation-detail questions. Stable values are required
before public commands and tests can be written.

## Decision

Adopt the version 1 contracts in the
[configuration specification](../../docs/specifications/configuration.md):

- default `VendorName` is `StartMenuFolders`
- machine configuration and user preferences use schema version 1
- Generated State uses an independently versioned ownership record
- the dedicated log and source are named `StartMenuFolders`
- event IDs use category ranges `1000-1699`
- event registration and runtime access follow `ADR-0009`
- the cache uses a `v1` namespace, 64 MB least-recently-used cap, and 30-day
  maximum age

## Consequences

- `OI-003`, `OI-004`, and `OI-005` are resolved.
- Future incompatible formats require a new schema or cache namespace.
- Event IDs are monitoring contracts and cannot be casually reassigned.
- The 30-day event retention is a target bounded by the 25 MB log size.

## Requirements

- `CR-001` through `CR-012`
- `FR-020`, `FR-021`, `FR-026` through `FR-029`
- `QR-005` through `QR-007`, `QR-012`, `QR-017`

## Alternatives considered

- Store everything beneath the Managed Root: rejected because that directory
  contains Entry Roots only.
- Use unversioned cache files: rejected because downgrade safety is required.
- Use the Application event log: rejected because a dedicated stable contract
  is easier to collect and diagnose.
