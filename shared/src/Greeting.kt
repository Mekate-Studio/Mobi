package com.example.myfirstapp.shared

fun buildGreeting(name: String): String = "Hello, $name!"

fun defaultGreeting(): String = buildGreeting(platformName())

expect fun platformName(): String
