import co.touchlab.skie.configuration.FlowInterop

plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.compose.multiplatform)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.metro)
    alias(libs.plugins.skie)
}

skie {
    features {
        coroutinesInterop.set(false)
        group {
            FlowInterop.Enabled(false)
        }
    }
}

kotlin {
    iosX64()
    iosArm64()
    iosSimulatorArm64()

    targets.withType<org.jetbrains.kotlin.gradle.plugin.mpp.KotlinNativeTarget>().configureEach {
        binaries.framework {
            baseName = "KotlinModules"
            isStatic = false
        }
    }

    sourceSets {
        val commonMain by getting {
            dependencies {
                implementation(compose.runtime)
                implementation(compose.ui)
                implementation(compose.foundation)
                implementation(compose.material3)
                implementation(libs.metro.runtime)
                implementation(libs.kotlinx.coroutines.core)
            }
            kotlin.srcDirs(
                "../../shared-core/src",
                "../../shared-feature-home/src",
                "../../shared-feature-nearby-vehicle-map/src",
                "../../shared-di/src",
                "../../shared-ui-home/src",
            )
        }

        val commonTest by getting {
            dependencies {
                implementation(kotlin("test"))
                implementation(libs.kotlinx.coroutines.test)
            }
            kotlin.srcDirs(
                "../../shared-core/test",
                "../../shared-feature-home/test",
                "../../shared-feature-nearby-vehicle-map/test",
                "../../shared-di/test",
            )
        }

        val iosX64Main by getting {
            kotlin.srcDirs(
                "../../shared-core/src@ios",
                "../../shared-ui-home/src@ios",
            )
        }

        val iosArm64Main by getting {
            kotlin.srcDirs(
                "../../shared-core/src@ios",
                "../../shared-ui-home/src@ios",
            )
        }

        val iosSimulatorArm64Main by getting {
            kotlin.srcDirs(
                "../../shared-core/src@ios",
                "../../shared-ui-home/src@ios",
            )
        }
    }
}
