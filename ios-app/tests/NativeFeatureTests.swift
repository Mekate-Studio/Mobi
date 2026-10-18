import Testing

// IOS-13: TestStore in the pinned TCA owns a process-wide executor hook.
// Keep store lifetimes from different features from overlapping that setting.
// Recheck parallel execution when TCA provides per-test executor isolation.
@Suite(.serialized)
struct NativeFeatureTests {
    @Suite("HomeFeature")
    struct HomeFeatureTests {}

    @Suite("NearbyVehicleMapFeature")
    struct NearbyVehicleMapFeatureTests {}
}
