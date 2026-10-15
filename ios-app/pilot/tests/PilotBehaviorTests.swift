import Foundation
@testable import SwiftExportConsumer
import XCTest

@MainActor final class PilotBehaviorTests: XCTestCase {
    func testRealHomeRefreshAndRetirement() async throws {
        let services = AppServices()
        let owner = services.makeHomeOwner()
        XCTAssertEqual(try owner.access.initialValue(), .initial)
        let result = try await owner.access.refresh(0)
        switch result {
        case let .loaded(value): XCTAssertEqual(value, 1)
        case .error: break // The real app's random repository failure policy remains active.
        default: XCTFail("Refresh must complete in a shared success or failure state")
        }
        owner.retire()
        XCTAssertThrowsError(try owner.access.initialValue())
        XCTAssertEqual(services.admission.metrics().active, 0)
    }

    func testRealNearbyOwnersOverlapWithoutSharingHandles() async throws {
        let services = AppServices()
        let first = services.makeNearbyOwner(), second = services.makeNearbyOwner()
        let initial1 = try first.access.initial(), initial2 = try second.access.initial()
        let coordinate = NativeCoordinate(latitude: 55.6761, longitude: 12.5683)
        let state1 = try first.access.available(initial1, coordinate)
        let state2 = try second.access.available(initial2, coordinate)
        first.access.releaseOwned(initial1); second.access.releaseOwned(initial2)
        XCTAssertThrowsError(try second.access.loading(state1))
        let start = DispatchTime.now().uptimeNanoseconds
        async let result1 = first.access.refresh(state1, now: 1000)
        async let result2 = second.access.refresh(state2, now: 1001)
        let results = try await (result1, result2)
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        XCTAssertNotEqual(results.0.snapshot, results.1.snapshot)
        let observed = services.repositoryObservation()
        XCTAssertEqual(observed.entered, 2)
        XCTAssertEqual(observed.active, 0)
        XCTAssertEqual(observed.maximum, PilotRuntimeSettings.current.repositoryPolicy == "main-confined" ? 2 : 1)
        print("MOBI_PILOT_REPOSITORY_OVERLAP=\(observed.maximum)")
        first.access.discardUnclaimed(results.0); second.access.discardUnclaimed(results.1)
        first.access.releaseOwned(state1); second.access.releaseOwned(state2)
        first.retire(); second.retire()
        XCTAssertEqual(first.access.metrics().states, 0)
        XCTAssertEqual(second.access.metrics().states, 0)
        XCTAssertEqual(first.access.metrics().requests, 0)
        XCTAssertEqual(second.access.metrics().requests, 0)
        print("MOBI_PILOT_RETAINED_NEARBY_REGISTRIES=0")
        XCTAssertEqual(services.admission.metrics().active, 0)
        print("MOBI_PILOT_OVERLAP_ELAPSED_NANOSECONDS=\(elapsed)")
        let polling = try JSONSerialization.data(withJSONObject: SystemPollDriver.observations(), options: .sortedKeys)
        let encoded = try XCTUnwrap(String(data: polling, encoding: .utf8))
        print("MOBI_PILOT_POLLING_OBSERVATIONS=\(encoded)")
    }

    func testCancellationRetainsOwnedDrainUntilCompletion() async throws {
        let services = AppServices(), owner = services.makeHomeOwner()
        let operation = Task { try await owner.access.refresh(0) }
        await Task.yield()
        operation.cancel()
        _ = try? await operation.value
        owner.retire()
        let clock = ContinuousClock(), deadline = clock.now.advanced(by: .seconds(5))
        while services.admission.metrics().active != 0, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(services.admission.metrics().active, 0)
        XCTAssertEqual(services.supervisor.metrics().active, 0)
    }

    func testStoreCancellationRetryAndSustainedClientMeasurements() async throws {
        let services = AppServices(), owner = services.makeHomeOwner()
        owner.store.send(.task)
        owner.store.send(.refreshTapped)
        let clock = ContinuousClock(), deadline = clock.now.advanced(by: .seconds(5))
        while owner.access.metrics().active == 0, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertGreaterThan(owner.access.metrics().active, 0)
        let cancelledRequest = try XCTUnwrap(owner.store.state.activeRequest)
        let cancelledAt = DispatchTime.now().uptimeNanoseconds
        owner.store.send(.cancelRefresh)
        XCTAssertNil(owner.store.state.activeRequest)
        XCTAssertEqual(owner.store.state.counterLoadable, .initial)
        let restored = DispatchTime.now().uptimeNanoseconds - cancelledAt
        let retryAt = DispatchTime.now().uptimeNanoseconds
        let retryEffect = owner.store.send(.refreshTapped)
        let retryRequest = try XCTUnwrap(owner.store.state.activeRequest)
        let pendingValue = owner.store.state.counterLoadable
        owner.store.send(.response(cancelledRequest, .loaded(value: 999)))
        owner.store.send(.cancelled(cancelledRequest))
        XCTAssertEqual(owner.store.state.activeRequest, retryRequest)
        XCTAssertEqual(owner.store.state.counterLoadable, pendingValue)
        await retryEffect.finish()
        XCTAssertNil(owner.store.state.activeRequest)
        let retry = DispatchTime.now().uptimeNanoseconds - retryAt
        var latencies: [UInt64] = []
        for value in 0 ..< 5 {
            let start = DispatchTime.now().uptimeNanoseconds
            _ = try await owner.access.refresh(Int32(value))
            latencies.append(DispatchTime.now().uptimeNanoseconds - start)
            XCTAssertEqual(owner.access.metrics().retained, 0)
        }
        owner.retire()
        print("MOBI_PILOT_STORE_CANCELLATION_NANOSECONDS=\(restored)")
        print("MOBI_PILOT_STALE_ACTIONS_REFUSED=2")
        print("MOBI_PILOT_MANUAL_RETRY_NANOSECONDS=\(retry)")
        print("MOBI_PILOT_FIVE_REFRESH_LATENCIES=\(latencies)")
    }

    func testActualOwnerCapacityRefusesBeforeRegistrationThenRetries() async throws {
        let services = AppServices(), owner = services.makeHomeOwner()
        guard PilotRuntimeSettings.current.nativeJobsPerOwner == 2,
              PilotRuntimeSettings.current.parentReservations > 2
        else {
            throw XCTSkip("Capacity experiment requires the explicit two-job owner cohort")
        }
        let first = Task { try await owner.access.refresh(0) }
        let second = Task { try await owner.access.refresh(0) }
        let clock = ContinuousClock(), deadline = clock.now.advanced(by: .seconds(5))
        while owner.access.metrics().active < 2, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertEqual(owner.access.metrics().active, 2)
        let accepted = owner.access.metrics().accepted
        do {
            _ = try await owner.access.refresh(0)
            XCTFail("Full owner must refuse before Kotlin registration")
        } catch let error as AdmissionError {
            XCTAssertEqual(error, .full)
        }
        XCTAssertEqual(owner.access.metrics().accepted, accepted)
        _ = try await (first.value, second.value)
        XCTAssertEqual(services.admission.metrics().active, 0)
        _ = try await owner.access.refresh(0)
        XCTAssertEqual(owner.access.metrics().retained, 0)
        owner.retire()
    }

    func testCompositionIdentityAndClosedWireAdmission() throws {
        let services = AppServices(), native = services.makeHomeOwner()
        XCTAssertTrue(services.ownsHomeService(native))
        XCTAssertThrowsError(try NativeNearbyAccess.validateSchema(99))
        XCTAssertThrowsError(try NativeNearbyAccess.decodeBlockedTag(99))
        XCTAssertThrowsError(try NativeNearbyAccess.decodeFailureTag(99))
        #if MOBI_PILOT_COMPOSE
            let shared = try services.makeSharedHomeOwner()
            XCTAssertTrue(services.ownsSharedHomeService(shared))
            _ = shared.retire()
        #endif
        services.retire()
        XCTAssertFalse(services.admission.metrics().open)
    }

    func testNoncooperativeDrainAndCancelledShutdownWaiter() async throws {
        let services = AppServices()
        let reservation = try services.admission.reserve(.homeRequest)
        let gate = CompletionGate()
        let key = DrainKey(owner: UUID(), request: 1)
        let receipt = services.supervisor.adopt(
            key,
            isCompleted: { gate.complete },
            forget: { reservation.release(); return true },
        )
        XCTAssertEqual(receipt.state, .stillDraining)
        services.closeAdmission()
        let soft = try await services.shutdown.awaitDrain(softDeadline: .zero)
        XCTAssertEqual(soft.state, .stillDraining)
        let waiter = Task { try await services.shutdown.awaitDrain(softDeadline: .seconds(5)) }
        waiter.cancel()
        _ = try? await waiter.value
        XCTAssertEqual(services.admission.metrics().active, 1)
        gate.complete = true
        let final = try await services.shutdown.awaitDrain(softDeadline: .seconds(5))
        XCTAssertEqual(final.state, .completed)
    }

    func testAdmissionRefusesBeforeRegistrationAndCanRetry() throws {
        let pool = AdmissionPool(capacity: 1)
        let reservation = try pool.reserve(.homeRequest)
        XCTAssertThrowsError(try pool.reserve(.nearbyRequest))
        reservation.release()
        let retry = try pool.reserve(.nearbyRequest)
        pool.close()
        XCTAssertThrowsError(try pool.reserve(.homeRequest))
        retry.release()
        XCTAssertEqual(pool.metrics().active, 0)
    }
}

@MainActor private final class CompletionGate { var complete = false }
