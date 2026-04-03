package studio.mekate.b3.core

import dev.zacsweers.metro.Inject

data class PlatformContext(
    val name: String,
)

fun interface PlatformNameProvider {
    operator fun invoke(): String
}

@Inject
class PlatformContextProvider(
    private val platformNameProvider: PlatformNameProvider,
) {
    fun current(): PlatformContext = PlatformContext(name = platformNameProvider())
}

expect fun platformName(): String
