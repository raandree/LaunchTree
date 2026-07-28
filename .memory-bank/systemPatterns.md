---
status: current
last-verified: 2026-07-28
owner: active-agent
source: repository evidence
---

# System patterns

## Architecture

Draft candidate: machine-wide native Start shortcuts open one per-user WPF
launcher process. A managed directory tree supplies entry roots; a roaming
per-user tree augments matching roots. The launcher reads snapshots, delegates
item invocation to Windows Shell, and manages only generated state and caches.
This candidate is not accepted until the Design Concept is signed off.

## Decisions

### Decision 1: Use the canonical Memory Bank base

- Choice: Keep durable project context in .memory-bank.
- Rationale: Preserve evidence-backed context across sessions.

### Decision 2: Require design sign-off before implementation

- Choice: Treat `docs/design-concept.md` as a draft gate for module work.
- Rationale: The native/WPF boundary and deployment constraints required an
  explicit requirements interview before code could be evaluated correctly.
