import org.jetbrains.kotlin.konan.target.Distribution
import org.jetbrains.kotlin.konan.target.KonanTarget
import org.jetbrains.kotlin.swiftexport.standalone.ErrorTypeStrategy
import org.jetbrains.kotlin.swiftexport.standalone.InputModule
import org.jetbrains.kotlin.swiftexport.standalone.SwiftExportModule
import org.jetbrains.kotlin.swiftexport.standalone.UnsupportedDeclarationReporterKind
import org.jetbrains.kotlin.swiftexport.standalone.config.SwiftExportConfig
import org.jetbrains.kotlin.swiftexport.standalone.config.SwiftModuleConfig
import org.jetbrains.kotlin.swiftexport.standalone.runSwiftExport
import java.nio.file.Path
import kotlin.system.exitProcess

// IOS-10: replace this standalone exporter entry point when Toolchain owns
// Swift-export integration. Keep generated source unmodified.
// https://github.com/JetBrains/kotlin/tree/v2.4.20/docs/swift-export
fun main(args: Array<String>) {
    require(args.size >= 4) { "Expected output, Native distribution, target and module declarations" }
    val target =
        when (args[2]) {
            "iosArm64" -> KonanTarget.IOS_ARM64
            "iosSimulatorArm64" -> KonanTarget.IOS_SIMULATOR_ARM64
            else -> error("Unsupported app target: ${args[2]}")
        }
    val modules = args.drop(3).map(::inputModule).toSet()
    val result =
        runSwiftExport(
            modules,
            SwiftExportConfig(
                outputPath = Path.of(args[0]),
                distribution = Distribution(args[1]),
                konanTarget = target,
                enableCoroutinesSupport = true,
                stableDeclarationsOrder = true,
                errorTypeStrategy = ErrorTypeStrategy.Fail,
                unsupportedTypeStrategy = ErrorTypeStrategy.Fail,
            ),
        ).getOrThrow()
    for (module in result.sortedBy { it.name }) {
        val fields =
            when (module) {
                is SwiftExportModule.SwiftOnly -> {
                    listOf(module.name, "swift", module.swiftApi, "", "", "", "")
                }

                is SwiftExportModule.BridgesToKotlin -> {
                    listOf(
                        module.name,
                        "bridge",
                        module.files.swiftApi,
                        module.files.kotlinBridges,
                        module.files.cHeaderBridges,
                        module.bridgeName,
                        module.dependencies.joinToString(",") { it.name },
                    )
                }
            }
        println("MODULE\t" + fields.joinToString("\t"))
    }
    // Standalone analysis creates application-lifetime workers. Exit only after
    // generation succeeds and the complete module graph has been printed.
    exitProcess(0)
}

private fun inputModule(declaration: String): InputModule {
    val parts = declaration.split("=", limit = 3)
    require(parts.size == 3 && parts[1] in setOf("public", "private")) {
        "Expected module=public|private=klib: $declaration"
    }
    return InputModule(
        parts[0],
        Path.of(parts[2]),
        SwiftModuleConfig(
            bridgeModuleName = "${parts[0]}Bridge",
            shouldBeFullyExported = parts[1] == "public",
            rootPackage = packageRoot(parts[0]),
            unsupportedDeclarationReporterKind = UnsupportedDeclarationReporterKind.Inline,
        ),
    )
}

private fun packageRoot(module: String): String? =
    when (module) {
        "MobiHome" -> "studio.mekate.mobi.feature.home"
        "MobiNearby" -> "studio.mekate.mobi.feature.nearbyvehiclemap"
        "MobiCore" -> "studio.mekate.mobi.core"
        "MobiIOS" -> "studio.mekate.mobi.ios"
        "MobiTestSupport" -> "studio.mekate.mobi.ios.test"
        else -> null
    }
