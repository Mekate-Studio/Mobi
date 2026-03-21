package studio.mekate.b3.shared

fun buildGreeting(name: String): String = "Hello, $name!"

fun defaultGreeting(): String = buildGreeting(platformName())

expect fun platformName(): String
