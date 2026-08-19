# Contributing to LaunchTree

Thank you for considering a contribution. This guide covers the local
development loop, the records a change must update, and what a reviewer looks
for. It is written for anyone opening a pull request against this repository.

## Code of conduct

Be respectful and assume good faith. Discuss the change, not the person.
Behavior that makes others unwelcome is not acceptable.

## Prerequisites

- Windows, because the module creates native Start shortcuts and hosts a WPF
  Launcher
- Windows PowerShell 5.1 and PowerShell 7, because both editions are supported
  and both are exercised by the test suite
- Git

Build dependencies are restored by the build script and are not installed
system-wide.

## Development loop

Restore dependencies and build the module and the single-file script:

```powershell
pwsh -NoProfile -File .\build.ps1 -ResolveDependency -Tasks build
```

Run the full test suite afterwards:

```powershell
pwsh -NoProfile -File .\build.ps1 -Tasks test
```

Both editions must pass. A change that only passes under PowerShell 7 is not
complete.

Validate the project records with the `Validate documentation` task in Visual
Studio Code, or run the script directly:

```powershell
pwsh -NoProfile -File .\tools\Test-Documentation.ps1
```

The task checks specification identifiers, cross-references, local links, and
the Design Concept sign-off state. It also runs a Memory Bank health check that
depends on a helper script outside the repository. If that script is not
present on your machine, the check fails locally and the maintainer runs it
before merging.

## Repository layout

| Path | Holds |
| --- | --- |
| `source/Public` | Exported commands, one file per command |
| `source/Private` | Internal helpers, one file per function |
| `source/Scripts` | Launcher bootstrap scripts copied into the built module |
| `tests/Unit` | Pester 6 unit tests mirroring the `source` layout |
| `tests/QA` | Manifest, changelog, and analyzer quality tests |
| `tools` | Repository scripts that are not shipped with the module |
| `docs` | Design Concept, specifications, guides, and the issue register |

## Canonical language

Use the terms defined in the [glossary](.memory-bank/glossary.md) in code,
tests, documentation, event messages, and commit messages. Terms such as
Managed Root, Entry Root, Start Entry, Launch Item, Reconciliation, Generated
State, and Support Bundle carry a precise meaning, and the listed synonyms are
not interchangeable with them.

## Behavior changes need a record

Public behavior is governed by numbered contracts in
[the specifications](docs/specifications/README.md): functional requirements
(`FR-###`), quality requirements (`QR-###`), configuration rules (`CR-###`),
acceptance scenarios (`AS-###`), and decision records (`ADR-####`).

- Changing observable behavior means updating the contract that describes it,
  in the same pull request as the code.
- A durable architectural choice is recorded as a new decision record rather
  than explained only in a commit message.
- An unresolved question or a blocked validation belongs in
  [the open issues register](docs/open-issues.md) as an `OI-###` record.

Every identifier that a document references must also be defined somewhere, and
the documentation task fails when it is not.

## Coding standards

- Follow the approved PowerShell verb list and the existing
  `Verb-LaunchTreeNoun` naming.
- Give every function `[CmdletBinding()]`, comment-based help, and validated
  parameters. Validate at the boundary rather than deep inside a helper.
- Use `-ErrorAction Stop` with `try`/`catch` where a failure must not continue,
  and keep error messages free of secrets, Launch Item arguments, and URL query
  strings.
- Never write a plain-text credential and never call `Invoke-Expression` on
  input that the module did not construct itself.
- PSScriptAnalyzer runs as part of the build. Resolve findings rather than
  suppressing them, and justify a suppression in the code when it is genuinely
  unavoidable.

## Tests

- Add or update a Pester 6 test for every behavior change, in the file that
  mirrors the changed source file. Keep every test file self-contained, because
  Pester 6 discovers and runs one file at a time.
- The suite uses the classic `Should -Be` assertions. The Pester 6 `Should-*`
  assertions are allowed in new tests, but do not rewrite a passing file only to
  change its assertion style.
- A bug fix keeps a regression test that fails before the fix.
- Do not weaken an assertion to obtain a passing run.

## Commits and changelog

- Write conventional commit subjects, for example `feat(launcher): ...`,
  `fix(config): ...`, or `docs: ...`.
- Add a user-visible change to the `[Unreleased]` section of
  [the changelog](CHANGELOG.md) under `Added`, `Changed`, `Deprecated`,
  `Removed`, `Fixed`, or `Security`.
- Version numbers are produced by GitVersion from the commit history. Do not
  edit a version by hand.

## Pull requests

Open the pull request against `main` and describe what changed, why, and how it
was verified. Confirm in the description that the build passed under both
supported editions, that the documentation task passed, and that the changelog
was updated. Keep a pull request focused on one concern so it stays reviewable.

## Reporting problems

Open an issue for a defect or a feature request. For a suspected security
vulnerability, follow [the security policy](SECURITY.md) instead and do not
open a public issue.

## Licensing of contributions

Contributions are accepted under the [MIT License](LICENSE) that covers this
repository. By opening a pull request you confirm that you may submit the work
under that license.

## See also

- [Getting started guide](docs/getting-started.md)
- [Signed Design Concept](docs/design-concept.md)
- [Deployment guide](docs/deployment.md)
