plugins {
    base
}

tasks.register("bridgeDoctor") {
    group = "verification"
    description = "Print the temporary Gradle bridge purpose and expected next steps."

    doLast {
        println("Gradle bridge is present for the iOS Kotlin framework path.")
        println("Next bootstrap step: wire Xcode to the bridge and verify embedAndSignAppleFrameworkForXcode.")
    }
}
