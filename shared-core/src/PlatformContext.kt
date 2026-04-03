package studio.mekate.b3.core

data class PlatformContext(
    val name: String,
)

class PlatformContextProvider(
    private val platformNameProvider: () -> String = ::platformName,
) {
    fun current(): PlatformContext = PlatformContext(name = platformNameProvider())
}

expect fun platformName(): String
