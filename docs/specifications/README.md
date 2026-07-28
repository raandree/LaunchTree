# LaunchTree specifications

This directory translates the signed Design Concept into stable, testable
contracts for implementation and release review.

## Authority

When artifacts disagree, use this order:

1. The latest explicit user instruction.
2. The signed [Design Concept](../design-concept.md).
3. Accepted records under [`.memory-bank/decisions`](../../.memory-bank/decisions/).
4. The specifications in this directory.
5. Executable tests.
6. Production source code.

An implementation mismatch does not silently change a specification. Change
the controlling document and its affected requirement IDs first.

## Documents

| Document | Contract |
| --- | --- |
| [Functional requirements](functional-requirements.md) | Observable behavior and public command surface |
| [Configuration](configuration.md) | Paths, JSON fields, defaults, state, and event contract |
| [Quality requirements](quality-requirements.md) | Compatibility, performance, security, usability, and release gates |
| [Open issues](../open-issues.md) | Unresolved, blocked, deferred, and resolved work |

## Requirement states

| State | Meaning |
| --- | --- |
| Accepted | Required by the signed Design Concept or an accepted decision |
| Proposed | Awaiting approval before implementation |
| Blocked | Accepted, but external evidence or access is unavailable |
| Deferred | Explicitly excluded from the current release |
| Verified | Accepted and backed by named executable or visual evidence |

## Traceability rules

- Functional requirements use `FR-###`.
- Quality requirements use `QR-###`.
- Configuration requirements use `CR-###`.
- Acceptance scenarios use `AS-###`.
- Decisions use `ADR-####`.
- Open issues use `OI-###`.
- Every production behavior must cite at least one requirement ID in its test
  description or test metadata.
- Every accepted decision must cite the requirements it constrains.
- Every unresolved release dependency must have one issue owner and one closure
  criterion in the [open-issues register](../open-issues.md).
