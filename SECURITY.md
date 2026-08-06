# Security policy

This policy explains how to report a security vulnerability in LaunchTree and
which behavior is treated as a security boundary. It is written for operators
who deploy the module and for researchers who examine it.

## Supported versions

LaunchTree is under active development and has not reached a stable release.
Security fixes are applied to the default branch only.

| Version | Supported |
| --- | --- |
| `main` (latest commit) | Yes |
| Any earlier commit or tag | No |

## Reporting a vulnerability

Report privately. Do not open a public issue, pull request, or discussion for a
suspected vulnerability.

1. Preferred: open a private report through the repository **Security** tab
   using **Report a vulnerability**.
2. Alternative: send an email to `r.andree@live.com` with `LaunchTree security`
   in the subject line.

Include the affected commit, the deployment shape (module or single-file
script), reproduction steps, the privilege level required, and the observed
impact. A proof of concept is welcome but never required.

Expect an acknowledgment within 7 days and an assessment within 30 days. If a
report is accepted, the fix and its advisory are published together.

## Security model

These properties are intended guarantees. A defect in any of them is a
vulnerability worth reporting.

- The Launcher runs as the signed-in standard user and never elevates itself.
- Managed Root content and machine configuration trust the access control lists
  established by deployment; the module does not relax them.
- Reconciliation only creates, updates, or removes Generated State that the
  module itself owns, identified by an opaque Entry ID.
- `.url` Launch Items are restricted to HTTP and HTTPS.
- Event Log entries and Support Bundles omit Launch Item arguments, URL query
  strings, and secrets.
- The module performs no outbound telemetry and no network lookup of its own.

## Out of scope

The following are documented design decisions rather than defects.

- `.lnk` Launch Items may target local, UNC, mapped-drive, or remote resources.
  Invocation is delegated to normal Windows Shell security behavior, so a
  Launch Item runs with exactly the rights the signed-in user already has.
- Personal Root content is user-controlled and is not subject to an allowlist.
  A user who can write there can already run the same target directly.
- The Launcher requires FullLanguage mode. Constrained Language Mode is not
  supported, and WDAC or AppLocker deployments must permit the Launcher Host
  explicitly.
- Generated launch commands use `-ExecutionPolicy Bypass`. Execution policy is
  not a security boundary, and this flag does not bypass WDAC, AppLocker, or
  Constrained Language Mode.
- Right-click suppression in the Launcher is an interaction rule, not a
  security boundary.
- Any finding that requires administrator rights on the machine to set up.

## Disclosure

Coordinated disclosure is expected. Please allow a fix to ship before
publishing details. Reporters are credited in the advisory unless they ask to
remain anonymous.

## See also

- [Signed Design Concept](docs/design-concept.md)
- [Quality requirements](docs/specifications/quality-requirements.md)
- [Troubleshooting guide](docs/troubleshooting.md)
