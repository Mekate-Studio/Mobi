import com.android.build.api.dsl.LibraryExtension
import groovy.json.JsonOutput
import groovy.json.JsonSlurper
import java.io.OutputStream
import java.security.DigestInputStream
import java.security.MessageDigest
import javax.xml.parsers.DocumentBuilderFactory

// AND-03: public AGP APIs supply resource-enabled host tests. The app graph and
// binaries come from Toolchain; remove this target when its normal runner replaces it.
buildscript {
    val inputs =
        groovy.json.JsonSlurper().parse(rootDir.resolve("../../build/android-ui-tests/inputs.json")) as Map<*, *>
    repositories {
        google()
        maven(
            System.getenv("KOTLIN_DEFAULT_MAVEN_CENTRAL_URL")
                ?: "https://maven-central.storage-download.googleapis.com/maven2",
        )
    }
    dependencies {
        classpath("com.android.tools.build:gradle:${inputs["agp"]}")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:${inputs["kotlin"]}")
        classpath("org.jetbrains.kotlin:compose-compiler-gradle-plugin:${inputs["kotlin"]}")
    }
}

apply(plugin = "com.android.library")
apply(plugin = "org.jetbrains.kotlin.plugin.compose")

repositories {
    google()
    maven(
        System.getenv("KOTLIN_DEFAULT_MAVEN_CENTRAL_URL")
            ?: "https://maven-central.storage-download.googleapis.com/maven2",
    )
}

val repo = rootDir.resolve("../..").canonicalFile
val inputsFile = repo.resolve("build/android-ui-tests/inputs.json")
val inputs = JsonSlurper().parse(inputsFile) as Map<*, *>
require(inputs["schema"] == 1 && inputs["toolchain"] == "0.13.0") { "Requalify Android UI input metadata" }

fun sha256(file: File): String {
    val digest = MessageDigest.getInstance("SHA-256")
    DigestInputStream(file.inputStream(), digest).use { it.transferTo(OutputStream.nullOutputStream()) }
    return digest.digest().joinToString("") { "%02x".format(it) }
}

fun inputFiles(key: String): List<File> =
    (inputs[key] as List<*>).map { value ->
        val item = value as Map<*, *>
        file(item["path"] as String).also { path ->
            require(
                path.isFile && sha256(path) == item["sha256"],
            ) { "Changed Android UI input: $path; rerun android-ui-test" }
        }
    }

val libraries = inputFiles("libraries")
val testGraph = inputFiles("dependencies")
val testSources = inputs["test_sources"] as Map<*, *>
val actualSources =
    repo
        .resolve("shared-ui-home/test@android")
        .walkTopDown()
        .filter {
            it.isFile && it.extension == "kt"
        }.toList()
require(
    actualSources
        .map {
            it.canonicalPath
        }.toSet() == testSources.keys.toSet(),
) { "Changed Android UI test set; rerun android-ui-test" }
require(
    actualSources.all {
        sha256(it) == testSources[it.canonicalPath]
    },
) { "Changed Android UI test source; rerun android-ui-test" }

layout.buildDirectory.set(repo.resolve("build/android-ui-tests/gradle"))
configure<LibraryExtension> {
    namespace = "studio.mekate.mobi.uitests"
    val sdk = inputs["android"] as Map<*, *>
    compileSdk = (sdk["compileSdk"] as Number).toInt()
    buildToolsVersion = sdk["buildToolsVersion"] as String
    defaultConfig { minSdk = (sdk["minSdk"] as Number).toInt() }
    buildFeatures { compose = true }
    sourceSets.named("main") { manifest.srcFile("AndroidManifest.xml") }
    sourceSets.named("test") { kotlin.directories += repo.resolve("shared-ui-home/test@android").path }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    testOptions {
        unitTests.isIncludeAndroidResources = true
        unitTests.all { test ->
            test.jvmArgs(inputs["jvm_args"] as List<*>)
            test.systemProperty(
                "robolectric.dependency.repo.url",
                System.getenv("KOTLIN_DEFAULT_MAVEN_CENTRAL_URL")
                    ?: "https://maven-central.storage-download.googleapis.com/maven2",
            )
        }
    }
}

dependencies {
    // Local AAR inputs retain Android resources; no second app dependency resolution.
    add("implementation", files(libraries + testGraph))
}

tasks.withType<Test>().configureEach {
    val output = repo.resolve("build/logs/android-ui-tests")
    testLogging { events("passed", "failed", "skipped") }
    doLast {
        val factory = DocumentBuilderFactory.newInstance()
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
        val results =
            reports.junitXml.outputLocation
                .get()
                .asFile
                .listFiles { file ->
                    file.name.startsWith("TEST-") &&
                        file.extension == "xml"
                }.orEmpty()
        require(results.isNotEmpty()) { "Android UI tests produced no result" }
        val suites = results.map { factory.newDocumentBuilder().parse(it).documentElement }
        val count = suites.sumOf { it.getAttribute("tests").toInt() }
        require(
            count > 0 &&
                suites.all { suite ->
                    listOf("failures", "errors", "skipped").all { suite.getAttribute(it).toInt() == 0 }
                },
        ) { "Android UI tests must pass without skipped cases" }
        output.resolve("report.json").writeText(
            JsonOutput.prettyPrint(
                JsonOutput.toJson(
                    mapOf(
                        "tests" to count,
                        "gradle" to gradle.gradleVersion,
                        "inputs_sha256" to sha256(inputsFile),
                    ),
                ),
            ),
        )
    }
}
