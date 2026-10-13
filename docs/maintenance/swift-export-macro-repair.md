# Swift export macro termination repair assessment

The recurring `Internal Error: DecodingError.dataCorrupted ... Corrupted JSON ...
unexpected end of file` has a small reproduction independent of Kotlin, app
resources, Swift language profiles and Xcode scheduling. Each of the three
retained host macro executables emits that exact diagnostic and exits 1 when
given eight zero bytes: the protocol header for a zero-length message. Ordinary
end-of-input exits 0 without a diagnostic.

The pinned SwiftSyntax 601.0.1 message handler attempts JSON decoding for that
empty payload. Swift's [termination protocol change](https://github.com/swiftlang/swift/pull/84829)
sends an empty message when shutting down an executable macro. The corresponding
[SwiftSyntax fix](https://github.com/swiftlang/swift-syntax/pull/3164) returns from
the message loop instead of decoding it. The same diagnostic is recorded in
[upstream issue 86833](https://github.com/swiftlang/swift/issues/86833).

These observations identify a concrete macro protocol incompatibility in the
measured tuple. They do not establish that every corrupted-JSON diagnostic has
this cause, or capture which plugin emitted each line of the earlier concurrent
Xcode builds. Three direct Swift frontend checks of a small CasePaths macro
fixture passed without the diagnostic; absence in one build is not a protocol
compatibility guarantee.

## Reproduce the old protocol failure

Use a complete retained delivery produced by the [candidate guide](swift-export-candidate.md).
Its manifest binds the host executable bytes; preserve that binding with the
results. `DELIVERY` denotes that delivery directory. This command runs the host
macros directly and does not qualify app execution:

```bash
python3 - "$DELIVERY/NativeProducts/macros" <<'PY'
import pathlib, subprocess, sys
root = pathlib.Path(sys.argv[1])
for name in ("CasePathsMacros", "ComposableArchitectureMacros", "PerceptionMacros"):
    for control, payload in (("eof", b""), ("termination", bytes(8))):
        result = subprocess.run([str(root / name)], input=payload,
                                capture_output=True, timeout=10)
        print(name, control, result.returncode, result.stderr.decode())
PY
```

## Candidate repair and qualification boundary

A minimal macro executable built from released SwiftSyntax 603.0.2 sources
accepts both inputs cleanly and still expands and executes a real macro
expression. That release contains the upstream fix. Updating SwiftSyntax alone
cannot satisfy the existing native graph: Perception 1.6.0 requires SwiftSyntax
below 602.0.0. The isolated repair therefore changes exactly two pins:

| Dependency | Existing pin | Rehearsed candidate |
| --- | --- | --- |
| SwiftSyntax | 601.0.1 / `f99ae8aa18f0cf0d53481901f88a0991dc3bd4a2` | 603.0.2 / `79e4b74a295b6eb74a8b585e3a39d29e70c1dbd1` |
| Perception | 1.6.0 / `d924c62a70fca5f43872f286dbd7cef0957f1c01` | 2.0.10 / `25ac73741c3436605d61eceb5207e896973918e7` |

The other thirteen pins and the MapLibre publisher checksum remain identical.
The two-pin repair was first an Executor snapshot edit. Following explicit
user approval, the shared repository lock now contains the repaired pins; the
full revised cold matrix and guarded post-cleanup replay have passed. The
isolated diagnostic repair rebuilds native dependencies and macros from their locked sources,
then compiles all generated modules and the strict Swift 6 app against retained,
hash-verified Kotlin sources/archive. It exercises original and relocated app
builds with the original package unavailable during relocation. It does not
rebuild Kotlin or repeat the complete profile/policy matrix.

The baseline in this diagnostic run consists of expected old-macro protocol
failures and clean EOF controls. It is not a new passing baseline app build.
The reused native helper's historical report suffix claims fresh Kotlin; that
suffix does not apply to this diagnostic context. The wrapper's effective scope
is fresh native production with retained Kotlin. The maintained helper now
reports only its native production scope; Kotlin provenance remains separate.

The repaired native graph resolved to the exact fifteen candidate pins. All
three rebuilt macro executables exited cleanly for EOF and zero-length
termination. Both strict Swift 6 app builds passed diagnostic and packaging
checks. The relocated simulator app passed thirteen transport controls,
twenty-two Compose job controls, nineteen route/UI groups and three
same-process background/foreground cycles. MapLibre/SwiftUI runtime findings
still require review. No compiler diagnostic was suppressed.

## Applied tuple and revised qualification

The two-pin change is approved and applied. The default Xcode project also
requires exact Perception 2.0.10; leaving its old 1.6.0 requirement forced Xcode
to restore both old pins during the initial default smoke check. That debug
build passed on the old tuple and does not qualify the repair. The aligned
default project passed the existing `ios-build-debug` and `ios-test` jobs with
all fifteen pins unchanged and no compiler internal error. Its preserved
PullRequest result contains twelve passed tests, zero failures and zero skips
on iOS Simulator 26.5. The private assessment wrapper was refused after its
metadata changed during execution and its summary parser encountered an
encoding error; independent raw-log hashes, job exits, lock bytes and the test
bundle establish this bounded compatibility evidence. The wrapper refusal is
preserved and is not presented as a passing Executor run. Perception's major-version
compatibility and current dependency advisories remain distinct review inputs.
Local compatibility evidence is not blanket dependency-risk acceptance.

The fresh repaired matrix passed all four profile/policy combinations, each
with original and actually reordered enum sources. Kotlin sources, exporter,
facades and joint archive were built fresh, followed by exact locked native
sources/macros and checksum-verified MapLibre inputs. All four guarded
post-cleanup replays compiled and ran fresh Swift/app consumers from retained
sources/archive and explicitly warm native products, with the original owned
workspaces unavailable. Independent exact-inventory/hash, source, provenance,
module-mode, packaging, runtime and cleanup verification passed for all eight
runs. No internal compiler error was present in retained emitter logs. The
current simulator evidence is iOS 26.5; minimum-runtime, device, hosted, Android
and signed-release gates remain unqualified.

The first revised matrix was interrupted by disk exhaustion and a RunStore
startup race. Its source, outputs and logs remain retained; interrupted runs
were recovered as inconclusive and positively cleaned. Disk headroom became
available and a fresh sequential coordinator completed the matrix. The old
all-generated/Main replay remains inconclusive on its original pins. Its
failure and the isolated retained-Kotlin repair remain separate historical
evidence; the complete revised qualification closes the current implementation
tasks without rewriting them.

Jorge Castro is the explicitly assigned accountable maintainer. Production
profile/policy/runtime choices and finding dispositions remain pending in the
[adoption plan](swift-export-adoption-plan.md).
