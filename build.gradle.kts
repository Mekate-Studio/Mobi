plugins {
    id("com.android.application") version "8.13.2" apply false
    kotlin("android") version "1.8.21" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}