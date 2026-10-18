# Proposal-time rollback checkpoint

Local checkpoint: `.maintenance/swift-export-app-pilot-proposal/20261011T121839Z`.

Contains tracked and nonignored untracked pre-pilot content, file modes, symlink targets, HEAD/dirty status, a hash inventory and references/hashes for the three final evidence reports. The archive inventory was verified against both its manifest and current files. Existing evidence remains in place. New pilot proposal files and Git metadata are excluded.

This captures the repaired direct source content, including SwiftSyntax 603.0.2, Perception 2.0.10 and the matching Xcode constraint. Required ignored-input auditing and restore/build/test validation remain implementation tasks 1.2 and 5.6. It is not a qualified rollback receipt or a published Git revision; refresh it before implementation if content changes.
