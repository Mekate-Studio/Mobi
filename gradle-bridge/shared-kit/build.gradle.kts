plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.compose.multiplatform)
    alias(libs.plugins.kotlin.compose)
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
            }
            kotlin.srcDirs(
                "../../shared-core/src",
                "../../shared-feature-home/src",
                "../../shared-ui-home/src",
            )
        }

        val commonTest by getting {
            dependencies {
                implementation(kotlin("test"))
            }
            kotlin.srcDirs(
                "../../shared-core/test",
                "../../shared-feature-home/test",
            )
        }

        val iosX64Main by getting {
            kotlin.srcDirs(
                "../../shared-core/src@ios",
            )
        }

        val iosArm64Main by getting {
            kotlin.srcDirs(
                "../../shared-core/src@ios",
            )
        }

        val iosSimulatorArm64Main by getting {
            kotlin.srcDirs(
                "../../shared-core/src@ios",
            )
        }
    }
}
