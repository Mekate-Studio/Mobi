# Swift-export producer

This JVM build tool invokes the Kotlin 2.4.20 standalone exporter. It generates
Swift sources, Kotlin/C bridges and a module graph from compiled KLibs. It does
not compile the generated bridges, link a second Kotlin runtime or copy the app.
The maintained Xcode app calls `scripts/ios/build_swift_export.rb`, which compiles
the generated bridges and Swift modules into the actual app delivery. The app
and hosted tests share one Kotlin runtime archive.

Run the generation step with Toolchain-resolved inputs:

```sh
ruby scripts/ios/generate_swift_export.rb iosSimulatorArm64 OUTPUT NATIVE_DISTRIBUTION \
  MobiHome=public=HOME_KLIB MobiCore=private=CORE_KLIB
```

Supply every resolved library required by the selected public API. `public`
exports the whole input module; `private` allows reachable declarations to be
exported without exporting unrelated API. Output includes `modules.json` and
`generate.log`. Generation refuses mismatched exporter/Native versions and
background class-loading failures, even when the process exits successfully.

**IOS-10:** replace this tool and its orchestration when supported Toolchain
integration passes the registry's app and delivery checks. The explicitly
selected IntelliJ coroutines runtime and repository can be removed separately
when upstream dependency metadata provides a working runtime: generation must
succeed without analysis-worker exceptions. No generated source is patched.

**IOS-12:** the launcher gives its JVMs private temporary storage. This preserves
the existing control; it does not resolve upstream dependency vulnerabilities.

Review the [official implementation documentation](https://github.com/JetBrains/kotlin/tree/v2.4.20/docs/swift-export)
and [current Swift-export guide](https://kotlinlang.org/docs/native-swift-export.html)
on updates. Alpha API changes require recompiling this tool and qualifying the
actual app before changing delivery or retiring any workaround.

The normal `ios-test` job also runs `scripts/ios/check_swift_export.rb` against
those modules. Six complete generated switches must compile, and six omitted
case controls must fail with exhaustive-switch diagnostics. The same command
reports public nested-constructor availability and strict generated-support
compilation as retirement candidates or blockers; it never removes workarounds.
Its report and diagnostics live under `build/logs/swift-export-checks/` for the
existing CI artifact upload.

`build_swift_export.rb --strict-support` requests a strict support build with no
fallback. To exercise the optional fully asserted app, pass the Xcode build
setting `MOBI_SWIFT_EXPORT_RUNTIME_ASSERTIONS=YES`; the current Compose graph
aborts in accessibility initialization. Standard delivery retains the baseline
runtime mode. See ADR 0009 for that bound and the retained isolation warnings.
