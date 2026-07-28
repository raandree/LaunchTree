---
status: current
last-verified: 2026-07-28
owner: active-agent
source: repository evidence
---

# System patterns

## Architecture

Accepted: machine-wide native Start shortcuts open one session-local WPF
launcher process. A managed directory tree supplies entry roots; a roaming
per-user tree augments matching roots. The launcher reads snapshots, delegates
item invocation to Windows Shell, and manages only generated state and caches.
Opaque Entry IDs cross the Start Entry process boundary. Reconciliation is
transactional, and a dedicated event log is explicitly writable by standard
interactive users.

## Decisions

### Decision 1: Use the canonical Memory Bank base

- Choice: Keep durable project context in .memory-bank.
- Rationale: Preserve evidence-backed context across sessions.

### Decision 2: Require design sign-off before implementation

- Choice: Treat `docs/design-concept.md` as a draft gate for module work.
- Rationale: The native/WPF boundary and deployment constraints required an
  explicit requirements interview before code could be evaluated correctly.

## Decision record index

- `ADR-0001`: Native Start Entries open the WPF Launcher.
- `ADR-0002`: Managed and Personal Content Sources merge by relative path.
- `ADR-0003`: Windows Shell invokes Launch Items.
- `ADR-0004`: Sampler PowerShell module with a WPF runtime.
- `ADR-0005`: Transactional Reconciliation and ownership records.
- `ADR-0006`: Versioned configuration, events, and cache contracts.
- `ADR-0007`: Seven-command read-mostly public surface.
- `ADR-0008`: Opaque Entry ID activation through a validated Launcher Host.
- `ADR-0009`: Standard-user access to the dedicated diagnostic event log.
- `ADR-0010`: Explicit long-path degradation on Windows PowerShell 5.1.
