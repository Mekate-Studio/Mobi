# Swift export diagnostic fixtures

These are explicit source templates for the optional maintenance candidate.
They are materialized byte-for-byte as `.kt` and `.swift` files in an owned
build workspace; they do not declare additional production Toolchain modules.
The descriptor, template and materialized-source hashes bind every run.

Kotlin owns shared business state. The native fixture ports exercise transport,
parent/route lifetime, cancellation drains and actual UI behavior over that
state. The legacy Home facade and enum-ordinal helpers are intentional negative
controls. The `executor/` access surfaces are typed Foundation stubs; their
results do not stand in for actual Kotlin/TCA/UIKit runtime qualification.

Generated-source packages and native compiler-specific dependencies are retained
for explicit replay. See the [candidate guide](../../../../docs/maintenance/swift-export-candidate.md).
