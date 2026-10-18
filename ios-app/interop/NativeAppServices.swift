import Foundation
@_implementationOnly import MobiAppComposition
import MobiIOSDependencies
@_implementationOnly import MobiNativeServices
import SwiftUI
import UIKit

private typealias Composition = ExportedKotlinPackages.studio.mekate.mobi.export.composition

/// Provisional native integration. Settings are explicit evaluation inputs.
/// Shared UI will use this same composition before final adoption.
@MainActor public final class NativeAppServices {
    private let composition: Composition.AppComposition
    private let admission: AdmissionPool
    private let supervisor = CompletionDrainSupervisor()
    private let jobsPerOwner: Int32
    private let observersPerRequest: Int32
    private var routes: [WeakHomeRoute] = []
    private var nearbyRoutes: [WeakNearbyRoute] = []

    public init(parentReservations: Int, jobsPerOwner: Int32, observersPerRequest: Int32) {
        precondition(parentReservations > 0 && jobsPerOwner > 0 && observersPerRequest > 0)
        admission = AdmissionPool(capacity: parentReservations)
        self.jobsPerOwner = jobsPerOwner
        self.observersPerRequest = observersPerRequest
        // Main confinement is provisional. These native slices do not qualify
        // the complete Nearby/Compose repository cohort or production settings.
        composition = Composition.AppComposition(policy: 0, nativeJobsPerOwner: jobsPerOwner)
    }

    public func makeHomeRoute() -> NativeHomeRoute {
        let facade = HomeTransport.HomeRequestOwner(
            service: composition.homeService,
            maxJobs: jobsPerOwner,
            maxObserversPerRequest: observersPerRequest,
        )
        let route = NativeHomeRoute(access: NativeHomeAccess(
            facade: facade,
            supervisor: supervisor,
            admission: admission,
        ))
        routes.removeAll { $0.value == nil }
        routes.append(WeakHomeRoute(route))
        return route
    }

    public func makeNearbyRoute() -> NativeNearbyRoute {
        let facade = NearbyTransport.NearbyRequestOwner(
            service: composition.nearbyHub.service,
            maxJobs: jobsPerOwner,
            maxObserversPerRequest: observersPerRequest,
        )
        let route = NativeNearbyRoute(access: NativeNearbyAccess(
            facade: facade, supervisor: supervisor, admission: admission,
        ))
        nearbyRoutes.removeAll { $0.value == nil }
        nearbyRoutes.append(WeakNearbyRoute(route))
        return route
    }

    public func retire() {
        admission.close()
        routes.forEach { $0.value?.retire() }
        routes.removeAll()
        nearbyRoutes.forEach { $0.value?.retire() }
        nearbyRoutes.removeAll()
    }
}
