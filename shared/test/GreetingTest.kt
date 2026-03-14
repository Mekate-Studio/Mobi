package com.example.myfirstapp.shared

import kotlin.test.Test
import kotlin.test.assertEquals

class GreetingTest {
    @Test
    fun buildsExpectedGreeting() {
        assertEquals("Hello, Kotlin Multiplatform!", buildGreeting("Kotlin Multiplatform"))
    }
}
