package studio.mekate.mobi.export.home

import kotlinx.coroutines.DisposableHandle
import kotlinx.coroutines.Job
import platform.Foundation.NSThread

// Request-independent listener ownership. The constructor/job lookup stay inside
// this Kotlin module; native callers receive only registration/disposal operations.
class HomeRequestCompletion internal constructor(
    private val maxObservers: Int,
    private val job: (Long) -> Job?,
) {
    private var nextToken = 1L
    private val entries = mutableMapOf<Long, MutableMap<Long, DisposableHandle>>()

    val observerCount: Int
        get() {
            check(NSThread.isMainThread)
            return entries.values.sumOf { it.size }
        }

    fun observe(
        id: Long,
        observer: () -> Unit,
    ): Long {
        check(NSThread.isMainThread)
        val request = job(id)
        if (request == null || (entries[id]?.size ?: 0) >= maxObservers) return 0
        val token = nextToken++
        // Completion has no executor guarantee. The native signal must remain
        // fast, nonthrowing and thread-safe; no Kotlin result is passed to it.
        val handle = request.invokeOnCompletion { observer() }
        entries.getOrPut(id) { mutableMapOf() }[token] = handle
        return token
    }

    fun stop(
        id: Long,
        token: Long,
    ) {
        check(NSThread.isMainThread)
        entries[id]?.remove(token)?.dispose()
        if (entries[id]?.isEmpty() == true) entries.remove(id)
    }

    internal fun forget(id: Long) {
        check(NSThread.isMainThread)
        entries.remove(id)?.values?.forEach { it.dispose() }
    }
}
