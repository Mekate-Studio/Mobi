package studio.mekate.mobi.export.composition

import platform.Foundation.NSThread
import studio.mekate.mobi.di.SharedDependencies
import studio.mekate.mobi.export.home.HomeFacade
import studio.mekate.mobi.export.nearby.NearbyHub

// Keep the graph private: no second graph or unguarded Nearby repository escapes.
class AppComposition(
    policy: Int,
    private val nativeJobsPerOwner: Int,
) {
    private val graph = SharedDependencies.createDefaultGraph()
    val homeService = graph.homeFeatureService
    val nearbyHub = NearbyHub(graph.nearbyFleetRepository, policy, nativeJobsPerOwner)

    init {
        check(NSThread.isMainThread)
        require(nativeJobsPerOwner > 0)
    }

    fun makeHomeFacade(): HomeFacade {
        check(NSThread.isMainThread)
        return HomeFacade(homeService, nativeJobsPerOwner)
    }
}
