package studio.mekate.b3.shared

import studio.mekate.b3.core.buildGreeting as coreBuildGreeting
import studio.mekate.b3.core.defaultGreeting as coreDefaultGreeting
import studio.mekate.b3.core.platformName as corePlatformName

fun buildGreeting(name: String): String = coreBuildGreeting(name)

fun defaultGreeting(): String = coreDefaultGreeting()

fun platformName(): String = corePlatformName()
