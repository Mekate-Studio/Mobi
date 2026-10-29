@testable import app
import MobiIOSTestDependencies
import Testing

extension NativeFeatureTests.NearbyVehicleMapFeatureTests {
    @Test(
        "should consume only the first meaningful location outcome",
        .timeLimit(.minutes(1)),
        arguments: [
            LocationResult.precise(latitude: 55, longitude: 12),
            .temporarilyUnavailable,
            .blocked(.accessDenied),
            .blocked(.accessRestricted),
            .blocked(.servicesDisabled),
            .blocked(.approximateOnly),
        ],
    )
    func shouldConsumeFirstMeaningfulLocationOutcome(expected: NearbyVehicleMapFeature.LocationResolutionResult) async {
        let updates = AsyncStream<LocationResult?> { continuation in
            continuation.yield(nil)
            continuation.yield(nil)
            continuation.yield(expected)
            continuation.yield(.precise(latitude: 1, longitude: 2))
            continuation.finish()
        }
        #expect(await NearbyVehicleMapLocationClient.firstResult(in: updates) == expected)
    }

    @Test("should not read location when already cancelled", .timeLimit(.minutes(1)))
    func shouldNotReadLocationWhenAlreadyCancelled() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            let updates = AsyncStream<LocationResult?> { $0.finish() }
            return await NearbyVehicleMapLocationClient.firstResult(in: updates)
        }
        #expect(await task.value == nil)
    }

    @Test("should stop consuming location on cancellation", .timeLimit(.minutes(1)))
    func shouldStopConsumingLocationOnCancellation() async {
        let started = AsyncStream<Void>.makeStream()
        let ended = AsyncStream<Void>.makeStream()
        var starts = started.stream.makeAsyncIterator()
        var endings = ended.stream.makeAsyncIterator()
        let updates = AsyncStream<LocationResult?> { continuation in
            continuation.onTermination = { _ in ended.continuation.yield(()) }
            continuation.yield(nil)
        }.map { result in
            started.continuation.yield(())
            return result
        }
        let task = Task { await NearbyVehicleMapLocationClient.firstResult(in: updates) }
        _ = await starts.next()
        task.cancel()
        #expect(await task.value == nil)
        _ = await endings.next()
        started.continuation.finish()
        ended.continuation.finish()
    }

    @Test("should use existing temporary failure when location sequence fails or ends", arguments: [false, true])
    func shouldHandleLocationSequenceFailure(fails: Bool) async {
        let updates = AsyncThrowingStream<LocationResult?, Error> { continuation in
            continuation.finish(throwing: fails ? LocationReaderFailure() : nil)
        }
        #expect(await NearbyVehicleMapLocationClient.firstResult(in: updates) == .temporarilyUnavailable)
    }
}

private typealias LocationResult = NearbyVehicleMapFeature.LocationResolutionResult
private struct LocationReaderFailure: Error {}
