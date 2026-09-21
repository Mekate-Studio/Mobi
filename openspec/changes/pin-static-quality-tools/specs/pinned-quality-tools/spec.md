## Purpose

Give Mobi's static gate reviewed tool and runtime identities that can be installed
explicitly and checked offline before source analysis begins.

## ADDED Requirements

### Requirement: Reviewed tool and rule identity

The quality gate SHALL require the reviewed exact versions of its five analyzers
and core runtime and SHALL validate installed content and rule-file hashes against
repository-owned metadata. It SHALL reject missing binaries, wrong versions,
corrupt installations and mismatched configuration before analysis. Global PATH
tools SHALL NOT silently replace managed tools.

#### Scenario: Wrong version or modified bytes
- **WHEN** a managed tool reports another version or its contents differ from the installation receipt
- **THEN** validation fails before any source analyzer executes and provides recovery guidance

#### Scenario: Rule profile drift
- **WHEN** a locked rule file changes without a corresponding reviewed lock update
- **THEN** the gate reports a configuration identity failure

### Requirement: Explicit verified installation

Installation SHALL occur only through an explicit bootstrap command. It SHALL use
versioned primary artifact URLs and locked SHA-256 checksums, verify downloads
before execution, preserve global tools, and publish success only after runtime
and analyzer validation. The hook SHALL NOT install, download or repair tools.

#### Scenario: Empty installation directory
- **WHEN** setup runs on a supported macOS host with declared prerequisites
- **THEN** it installs the locked tools into repository-owned ignored storage and the gate can run

#### Scenario: Failed or interrupted setup
- **WHEN** a download, checksum, extraction, build or version verification fails
- **THEN** setup fails without publishing a complete installation and explains cleanup or retry

#### Scenario: Concurrent setup
- **WHEN** another installer owns the installation lock
- **THEN** a second installer fails explicitly without modifying the first install

### Requirement: Shared offline checks

Local and CI quality entry points SHALL use the same lock and verification path.
Successful reuse SHALL require no network access. Verification SHALL report the
lock identity, runtime/tool versions and relevant host constraints. Native build
and release runtime defaults SHALL remain independent.

#### Scenario: Verified offline reuse
- **WHEN** a complete unchanged installation already exists
- **THEN** static validation succeeds without invoking an installer or accessing the network
