# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Add a getting-started guide for installation, first content, Reconciliation,
  health verification, Launcher use, and cleanup
- Add structured health, redacted Event Log diagnostics, Support Bundle export,
  and ownership-only Generated State removal
- Add operational Event Log emission for configuration, content, launch,
  Reconciliation, cache, performance, and Support Bundle failures
- Add the session-local WPF Launcher with recursive navigation, global search,
  localized sorting, keyboard/touch controls, high-resolution Shell icons,
  bounded icon caching, persisted presentation preferences, system themes,
  hover descriptions, and right-click suppression
- Add transactional Start Entry Reconciliation with opaque Entry IDs,
  ownership records, collision protection, rollback, and event-log provisioning
- Add Shell-native `.lnk` and `.url` invocation with typed failure results
- Add recursive Content Snapshot discovery with Managed and Personal Content
  Sources, depth boundaries, descriptions, and validated `.lnk`/`.url` items
- Add read-only effective configuration with validated machine settings, user
  preferences, defaults, and structured Health Findings
- Add the initial Sampler module structure, signed specifications, accepted
  decisions, canonical glossary, and managed issue register

### Changed

- Scope dedicated-test and help QA gates to exported commands while retaining
  PSScriptAnalyzer coverage for private helpers
- Document PSGallery, GPO, and file-copy deployment plus operational
  troubleshooting and example machine configuration

### Fixed

- Fix Windows command-line escaping for trailing backslashes and plus signs
- Return structured `Unhealthy` status and a visible Launcher error for future
  configuration schemas while refusing Reconciliation mutation
- Merge matching Managed and Personal Menu Folders into one navigable folder
- Bound Menu Folder description metadata to 64 KB before allocation

### Security

- Validate the Interactive Users Event Log ACL and run a nonce write/read probe
  through the elevated account's linked standard-user token before commit
- Add tests for reparse exclusion, Generated State containment, URL scheme
  revalidation, redaction, and opaque Entry ID command-line boundaries
