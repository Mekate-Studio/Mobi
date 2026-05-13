package studio.mekate.mobi.core

import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class NearbyFleetRepositoryTest {
    @Test
    fun `should model stable vehicle identity and vehicle locations in a fleet snapshot`() {
        // given
        val riderLocation = RiderLocation(latitude = 55.6761, longitude = 12.5683)
        val vehicleId = VehicleId("mobi-001")
        val vehicleLocation = VehicleLocation(latitude = 55.6763, longitude = 12.5681)

        // when
        val snapshot =
            FleetSnapshot(
                sequence = 1,
                riderLocation = riderLocation,
                vehicles = listOf(NearbyVehicle(id = vehicleId, location = vehicleLocation)),
                loadedAtMillis = 1_000,
            )

        // then
        assertEquals(vehicleId, snapshot.vehicles.single().id)
        assertEquals(vehicleLocation, snapshot.vehicles.single().location)
        assertEquals(riderLocation, snapshot.riderLocation)
        assertEquals(false, snapshot.isEmpty)
    }

    @Test
    fun `should reject blank vehicle identity`() {
        // given
        val blankVehicleIdentity = " "

        // when
        val error =
            assertFailsWith<IllegalArgumentException> {
                VehicleId(blankVehicleIdentity)
            }

        // then
        assertEquals("Vehicle identity must not be blank.", error.message)
    }

    @Test
    fun `should treat an empty fleet snapshot as a successful result`() {
        // given
        val riderLocation = RiderLocation(latitude = 55.6761, longitude = 12.5683)

        // when
        val snapshot =
            FleetSnapshot(
                sequence = 2,
                riderLocation = riderLocation,
                vehicles = emptyList(),
                loadedAtMillis = 2_000,
            )

        // then
        assertTrue(snapshot.isEmpty)
        assertEquals(emptyList(), snapshot.vehicles)
    }

    @Test
    fun `should project vehicle location into rider centered map offset`() {
        // given
        val riderLocation = RiderLocation(latitude = 55.6761, longitude = 12.5683)
        val vehicleLocation = VehicleLocation(latitude = 55.6764, longitude = 12.5687)

        // when
        val offset =
            NearbyVehicleMapProjection.offset(
                vehicleLocation = vehicleLocation,
                riderLocation = riderLocation,
            )

        // then
        assertEquals(0.72, offset.x, absoluteTolerance = 0.0001)
        assertEquals(0.3, offset.y, absoluteTolerance = 0.0001)
    }

    @Test
    fun `should produce changing successive snapshots with stable identities`() =
        runTest {
            // given
            val repository = createRepository(shouldFail = false)
            val riderLocation = RiderLocation(latitude = 55.6761, longitude = 12.5683)

            // when
            val firstSnapshot =
                repository.fetchNearbyFleetSnapshot(
                    NearbyFleetRequest(riderLocation = riderLocation, requestedAtMillis = 1_000),
                )
            val secondSnapshot =
                repository.fetchNearbyFleetSnapshot(
                    NearbyFleetRequest(riderLocation = riderLocation, requestedAtMillis = 2_000),
                )

            // then
            assertEquals(VehicleId("mobi-001"), firstSnapshot.vehicles.first().id)
            assertEquals(VehicleId("mobi-001"), secondSnapshot.vehicles.first().id)
            assertNotEquals(firstSnapshot.vehicles, secondSnapshot.vehicles)
            assertEquals(SimulatedNearbyFleetRepository.API_DELAY_MILLIS * 2, currentTime)
        }

    @Test
    fun `should surface transient repository failure without producing a snapshot`() =
        runTest {
            // given
            val repository = createRepository(shouldFail = true)
            val riderLocation = RiderLocation(latitude = 55.6761, longitude = 12.5683)

            // when
            val error =
                assertFailsWith<NearbyFleetRepositoryException> {
                    repository.fetchNearbyFleetSnapshot(
                        NearbyFleetRequest(riderLocation = riderLocation, requestedAtMillis = 1_000),
                    )
                }

            // then
            assertEquals(NearbyFleetRepositoryException.DEFAULT_MESSAGE, error.message)
            assertEquals(SimulatedNearbyFleetRepository.API_DELAY_MILLIS, currentTime)
        }

    private fun createRepository(shouldFail: Boolean): SimulatedNearbyFleetRepository =
        SimulatedNearbyFleetRepository(
            failurePolicy =
                NearbyFleetFailurePolicy {
                    shouldFail
                },
        )
}
