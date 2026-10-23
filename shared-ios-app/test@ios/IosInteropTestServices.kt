package studio.mekate.mobi.ios.test

import studio.mekate.mobi.core.CounterRepository
import studio.mekate.mobi.core.CounterRepositoryException
import studio.mekate.mobi.core.CounterRequestFailurePolicy
import studio.mekate.mobi.core.FakeCounterRepository
import studio.mekate.mobi.core.FleetSnapshot
import studio.mekate.mobi.core.NearbyFleetRepository
import studio.mekate.mobi.core.NearbyFleetRepositoryException
import studio.mekate.mobi.core.NearbyFleetRequest
import studio.mekate.mobi.core.NearbyVehicle
import studio.mekate.mobi.core.VehicleId
import studio.mekate.mobi.core.VehicleLocation
import studio.mekate.mobi.feature.home.CounterLoadFailureReason
import studio.mekate.mobi.feature.home.HomeFeatureService
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureService
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFreshnessPolicy
import kotlin.coroutines.cancellation.CancellationException

// IOS-14: Kotlin-owned domain-failure fixtures preserve their identity at the client seam.
// The selected generated reverse async bridge wraps Swift errors in SwiftException.
// Recheck native repository stubs when that round-trip is faithful.
// Kotlin-origin cancellation/uncaught-error controls also qualify the forward bridge;
// retain those controls when IOS-14 is retired. Release excludes all these test fixtures.
object IosInteropTestServices {
    fun successfulHomeService(): HomeFeatureService = homeService(null)

    fun delayedHomeService(): HomeFeatureService =
        HomeFeatureService(
            FakeCounterRepository(
                object : CounterRequestFailurePolicy {
                    override fun shouldFail(currentCounterValue: Int): Boolean = false
                },
            ),
        )

    fun repositoryUnavailableHomeService(): HomeFeatureService =
        homeService(CounterLoadFailureReason.RepositoryUnavailable)

    fun unexpectedFailureHomeService(): HomeFeatureService = homeService(CounterLoadFailureReason.Unexpected)

    private fun homeService(failure: CounterLoadFailureReason?): HomeFeatureService =
        HomeFeatureService(
            object : CounterRepository {
                override suspend fun fetchNextCounterValue(currentCounterValue: Int): Int =
                    when (failure) {
                        null -> 21

                        CounterLoadFailureReason.RepositoryUnavailable -> throw CounterRepositoryException(
                            "Test failure",
                        )

                        CounterLoadFailureReason.Unexpected -> error("Unexpected test failure")
                    }
            },
        )

    fun cancellingHomeService(): HomeFeatureService = HomeFeatureService(CancelOnceCounterRepository())

    fun uncaughtFailureHomeService(): HomeFeatureService =
        HomeFeatureService(
            object : CounterRepository {
                override suspend fun fetchNextCounterValue(currentCounterValue: Int): Int =
                    throw AssertionError("Uncaught Kotlin test failure")
            },
        )

    fun cancellingNearbyService(): NearbyVehicleMapFeatureService =
        recoveringNearbyService(CancellationException("Cancelled test request"))

    fun uncaughtFailureNearbyService(): NearbyVehicleMapFeatureService =
        recoveringNearbyService(AssertionError("Uncaught Kotlin test failure"))

    fun repositoryUnavailableNearbyService(): NearbyVehicleMapFeatureService =
        recoveringNearbyService(NearbyFleetRepositoryException("Test failure"))
}

private fun recoveringNearbyService(firstFailure: Throwable): NearbyVehicleMapFeatureService =
    NearbyVehicleMapFeatureService(
        nearbyFleetRepository = RecoveringNearbyFleetRepository(firstFailure),
        freshnessPolicy = NearbyVehicleMapFreshnessPolicy(),
    )

private class RecoveringNearbyFleetRepository(
    private val firstFailure: Throwable,
) : NearbyFleetRepository {
    private var shouldFail = true

    override suspend fun fetchNearbyFleetSnapshot(request: NearbyFleetRequest): FleetSnapshot {
        if (shouldFail) {
            shouldFail = false
            throw firstFailure
        }
        return FleetSnapshot(
            sequence = 1,
            riderLocation = request.riderLocation,
            vehicles =
                listOf(
                    NearbyVehicle(
                        id = VehicleId("mobi-ios-001"),
                        location = VehicleLocation(latitude = 55.6764, longitude = 12.5687),
                    ),
                ),
            loadedAtMillis = 1000,
        )
    }
}

private class CancelOnceCounterRepository : CounterRepository {
    private var shouldCancel = true

    override suspend fun fetchNextCounterValue(currentCounterValue: Int): Int {
        if (shouldCancel) {
            shouldCancel = false
            throw CancellationException("Cancelled Home test request")
        }
        return 21
    }
}
